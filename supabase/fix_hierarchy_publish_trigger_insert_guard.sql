create or replace function private.guard_academy_hierarchy_publish()
returns trigger language plpgsql security invoker set search_path=''
as $function$
declare v_transition boolean:=false;
begin
 if new.published then
  if tg_op='INSERT' then
   v_transition:=true;
  else
   v_transition:=not old.published;
  end if;
  if v_transition then
   if tg_table_name='academy_chapters' then
    if not exists(select 1 from public.academy_courses c where c.id=new.course_id and c.published) then
     raise exception 'Publish the parent course before publishing this chapter';
    end if;
   elsif tg_table_name='academy_units' then
    if not exists(select 1 from public.academy_chapters ch join public.academy_courses c on c.id=ch.course_id where ch.id=new.chapter_id and ch.published and c.published) then
     raise exception 'Publish the parent course and chapter before publishing this unit';
    end if;
   end if;
  end if;
 end if;
 return new;
end;
$function$;