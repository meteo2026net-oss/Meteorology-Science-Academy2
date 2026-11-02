create table if not exists private.academy_lesson_reviews (
 lesson_id uuid primary key references public.academy_lessons(id) on delete cascade,
 status text not null default 'pending' check (status in ('pending','approved','changes_requested','rejected')),
 review_notes text not null default '',
 reviewer_id uuid references auth.users(id) on delete set null,
 reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint academy_lesson_reviews_status_metadata check (
   (status='pending' and reviewer_id is null and reviewed_at is null)
   or (status<>'pending' and reviewer_id is not null and reviewed_at is not null)
 )
);
create index if not exists academy_lesson_reviews_status_idx on private.academy_lesson_reviews(status,updated_at desc);
alter table private.academy_lesson_reviews enable row level security;
drop policy if exists academy_lesson_reviews_admin_select on private.academy_lesson_reviews;
create policy academy_lesson_reviews_admin_select on private.academy_lesson_reviews for select to authenticated using ((select private.is_academy_admin()));
drop policy if exists academy_lesson_reviews_admin_insert on private.academy_lesson_reviews;
create policy academy_lesson_reviews_admin_insert on private.academy_lesson_reviews for insert to authenticated with check ((select private.is_academy_admin()) and reviewer_id=(select auth.uid()));
drop policy if exists academy_lesson_reviews_admin_update on private.academy_lesson_reviews;
create policy academy_lesson_reviews_admin_update on private.academy_lesson_reviews for update to authenticated using ((select private.is_academy_admin())) with check ((select private.is_academy_admin()) and reviewer_id=(select auth.uid()));
grant usage on schema private to authenticated;
grant select,insert,update on private.academy_lesson_reviews to authenticated;

create or replace function public.set_academy_lesson_review(p_lesson_id uuid,p_status text,p_notes text)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $function$
declare v_uid uuid := (select auth.uid()); v_result jsonb;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Admin access required'; end if;
 if p_status not in ('approved','changes_requested','rejected') then raise exception 'Invalid review status'; end if;
 if p_notes is null or char_length(btrim(p_notes))<20 or char_length(p_notes)>2000 then raise exception 'Review notes must contain 20 to 2000 characters'; end if;
 if not exists(select 1 from public.academy_lessons l where l.id=p_lesson_id) then raise exception 'Lesson not found'; end if;
 insert into private.academy_lesson_reviews(lesson_id,status,review_notes,reviewer_id,reviewed_at,updated_at)
 values(p_lesson_id,p_status,btrim(p_notes),v_uid,now(),now())
 on conflict(lesson_id) do update set status=excluded.status,review_notes=excluded.review_notes,reviewer_id=excluded.reviewer_id,reviewed_at=excluded.reviewed_at,updated_at=now();
 select jsonb_build_object('lesson_id',lesson_id,'status',status,'reviewed_at',reviewed_at) into v_result from private.academy_lesson_reviews where lesson_id=p_lesson_id;
 return v_result;
end;
$function$;
revoke all on function public.set_academy_lesson_review(uuid,text,text) from public,anon;
grant execute on function public.set_academy_lesson_review(uuid,text,text) to authenticated;

create or replace function public.get_academy_lesson_review_status(p_lesson_ids uuid[])
returns table(lesson_id uuid,status text,review_notes text,reviewer_id uuid,reviewed_at timestamptz)
language sql
stable
security invoker
set search_path=''
as $function$
 select l.id,coalesce(r.status,'pending'),coalesce(r.review_notes,''),r.reviewer_id,r.reviewed_at
 from public.academy_lessons l
 left join private.academy_lesson_reviews r on r.lesson_id=l.id
 where l.id=any(coalesce(p_lesson_ids,'{}'::uuid[]))
   and (select private.is_academy_admin())
 order by l.sort_order,l.title;
$function$;
revoke all on function public.get_academy_lesson_review_status(uuid[]) from public,anon;
grant execute on function public.get_academy_lesson_review_status(uuid[]) to authenticated;

create or replace function private.guard_lesson_review_and_publish()
returns trigger
language plpgsql
security invoker
set search_path=''
as $function$
declare v_review private.academy_lesson_reviews%rowtype; v_changed boolean:=false;
begin
 if tg_op='UPDATE' then
  v_changed := old.title is distinct from new.title
   or old.summary is distinct from new.summary
   or old.content is distinct from new.content
   or old.learning_objectives is distinct from new.learning_objectives
   or old.chapter_id is distinct from new.chapter_id
   or old.unit_id is distinct from new.unit_id;
  if old.published and v_changed then
   raise exception 'Unpublish the lesson before editing reviewed content';
  end if;
  if v_changed then
   update private.academy_lesson_reviews
   set status='pending',review_notes='أعيد الدرس للمراجعة بعد تعديل المحتوى.',reviewer_id=null,reviewed_at=null,updated_at=now()
   where lesson_id=old.id and status='approved';
  end if;
 end if;
 if new.published then
  select * into v_review from private.academy_lesson_reviews where lesson_id=new.id;
  if not found or v_review.status<>'approved' or v_review.reviewer_id is null or v_review.reviewed_at is null then
   raise exception 'Lesson publication requires an approved editorial and scientific review';
  end if;
  if not exists(select 1 from public.academy_courses c where c.id=new.course_id and c.published) then
   raise exception 'Publish the parent course before publishing its lessons';
  end if;
  if new.chapter_id is not null and not exists(select 1 from public.academy_chapters ch where ch.id=new.chapter_id and ch.course_id=new.course_id and ch.published) then
   raise exception 'Publish the parent chapter before publishing this lesson';
  end if;
  if new.unit_id is not null and not exists(
   select 1 from public.academy_units u join public.academy_chapters ch on ch.id=u.chapter_id
   where u.id=new.unit_id and u.chapter_id=new.chapter_id and ch.course_id=new.course_id and u.published and ch.published
  ) then raise exception 'Publish the matching parent unit and chapter before publishing this lesson'; end if;
 end if;
 return new;
end;
$function$;
drop trigger if exists academy_lesson_review_publish_guard on public.academy_lessons;
create trigger academy_lesson_review_publish_guard before insert or update on public.academy_lessons for each row execute function private.guard_lesson_review_and_publish();

create or replace function private.guard_published_lesson_review()
returns trigger
language plpgsql
security invoker
set search_path=''
as $function$
begin
 if new.status<>'approved' and exists(select 1 from public.academy_lessons l where l.id=new.lesson_id and l.published) then
  raise exception 'Unpublish the lesson before changing its approved review status';
 end if;
 return new;
end;
$function$;
drop trigger if exists academy_published_lesson_review_guard on private.academy_lesson_reviews;
create trigger academy_published_lesson_review_guard before update on private.academy_lesson_reviews for each row execute function private.guard_published_lesson_review();

comment on table private.academy_lesson_reviews is 'Private editorial and scientific review decisions required before lesson publication.';
comment on function public.set_academy_lesson_review(uuid,text,text) is 'Admin-only review workflow; requires an authenticated admin and substantive notes.';
comment on function public.get_academy_lesson_review_status(uuid[]) is 'Admin-only review status for a selected set of lesson IDs.';
