create or replace function private.guard_academy_hierarchy_publish()
returns trigger
language plpgsql
security invoker
set search_path=''
as $function$
begin
 if new.published and (tg_op='INSERT' or old.published is distinct from new.published) then
  if tg_table_name='academy_chapters' then
   if not exists(select 1 from public.academy_courses c where c.id=new.course_id and c.published) then
    raise exception 'Publish the parent course before publishing this chapter';
   end if;
  elsif tg_table_name='academy_units' then
   if not exists(
    select 1 from public.academy_chapters ch join public.academy_courses c on c.id=ch.course_id
    where ch.id=new.chapter_id and ch.published and c.published
   ) then raise exception 'Publish the parent course and chapter before publishing this unit'; end if;
  end if;
 end if;
 return new;
end;
$function$;
drop trigger if exists academy_chapter_publish_guard on public.academy_chapters;
create trigger academy_chapter_publish_guard before insert or update on public.academy_chapters for each row execute function private.guard_academy_hierarchy_publish();
drop trigger if exists academy_unit_publish_guard on public.academy_units;
create trigger academy_unit_publish_guard before insert or update on public.academy_units for each row execute function private.guard_academy_hierarchy_publish();
comment on function private.guard_academy_hierarchy_publish() is 'Prevents publishing a chapter or unit before its parent is published.';