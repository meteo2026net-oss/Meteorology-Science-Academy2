create table if not exists private.academy_lesson_review_events(
 id uuid primary key default gen_random_uuid(),
 lesson_id uuid not null,
 lesson_slug text not null,
 lesson_title text not null,
 previous_status text,
 new_status text not null,
 review_notes text not null,
 actor_id uuid,
 created_at timestamptz not null default now()
);
create index if not exists academy_lesson_review_events_lesson_idx on private.academy_lesson_review_events(lesson_id,created_at desc);
alter table private.academy_lesson_review_events enable row level security;
drop policy if exists academy_lesson_review_events_admin_select on private.academy_lesson_review_events;
create policy academy_lesson_review_events_admin_select on private.academy_lesson_review_events for select to authenticated using ((select private.is_academy_admin()));
drop policy if exists academy_lesson_review_events_admin_insert on private.academy_lesson_review_events;
create policy academy_lesson_review_events_admin_insert on private.academy_lesson_review_events for insert to authenticated with check ((select private.is_academy_admin()));
grant select,insert on private.academy_lesson_review_events to authenticated;
revoke update,delete on private.academy_lesson_review_events from authenticated;

create or replace function private.log_academy_lesson_review_event()
returns trigger language plpgsql security invoker set search_path=''
as $function$
declare v_lesson public.academy_lessons%rowtype;
begin
 select * into v_lesson from public.academy_lessons where id=new.lesson_id;
 if not found then
  insert into private.academy_lesson_review_events(lesson_id,lesson_slug,lesson_title,previous_status,new_status,review_notes,actor_id)
  values(new.lesson_id,'[deleted]','[deleted]',case when tg_op='INSERT' then null else old.status end,new.status,new.review_notes,(select auth.uid()));
 else
  insert into private.academy_lesson_review_events(lesson_id,lesson_slug,lesson_title,previous_status,new_status,review_notes,actor_id)
  values(new.lesson_id,v_lesson.slug,v_lesson.title,case when tg_op='INSERT' then null else old.status end,new.status,new.review_notes,(select auth.uid()));
 end if;
 return new;
end;
$function$;
drop trigger if exists academy_lesson_review_audit on private.academy_lesson_reviews;
create trigger academy_lesson_review_audit after insert or update on private.academy_lesson_reviews for each row execute function private.log_academy_lesson_review_event();

create or replace function public.get_academy_lesson_review_summary(p_course_id text)
returns table(total_lessons bigint,pending bigint,approved bigint,changes_requested bigint,rejected bigint,published bigint)
language sql stable security invoker set search_path=''
as $function$
 select count(*)::bigint,
        count(*) filter(where coalesce(r.status,'pending')='pending')::bigint,
        count(*) filter(where r.status='approved')::bigint,
        count(*) filter(where r.status='changes_requested')::bigint,
        count(*) filter(where r.status='rejected')::bigint,
        count(*) filter(where l.published)::bigint
 from public.academy_lessons l
 left join private.academy_lesson_reviews r on r.lesson_id=l.id
 where l.course_id=p_course_id and (select private.is_academy_admin());
$function$;
revoke all on function public.get_academy_lesson_review_summary(text) from public,anon;
grant execute on function public.get_academy_lesson_review_summary(text) to authenticated;

create or replace function public.get_academy_lesson_review_history(p_lesson_id uuid)
returns table(previous_status text,new_status text,review_notes text,reviewer_name text,created_at timestamptz)
language sql stable security invoker set search_path=''
as $function$
 select e.previous_status,e.new_status,e.review_notes,coalesce(p.display_name,'مراجع الأكاديمية'),e.created_at
 from private.academy_lesson_review_events e
 left join public.academy_profiles p on p.id=e.actor_id
 where e.lesson_id=p_lesson_id and (select private.is_academy_admin())
 order by e.created_at desc limit 30;
$function$;
revoke all on function public.get_academy_lesson_review_history(uuid) from public,anon;
grant execute on function public.get_academy_lesson_review_history(uuid) to authenticated;
comment on table private.academy_lesson_review_events is 'Append-only audit history for lesson editorial/scientific review decisions.';
