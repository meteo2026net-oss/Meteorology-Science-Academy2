create or replace function public.get_academy_lesson_objective_mastery(p_user_id uuid default null)
returns table(objective_code text,objective_title text,domain text,mapped_lessons bigint,attempted_lessons bigint,completed_lessons bigint,average_score numeric,mastery_status text)
language plpgsql
stable
security invoker
set search_path=''
as $function$
declare v_uid uuid := (select auth.uid()); v_target uuid;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if p_user_id is null or p_user_id=v_uid then v_target:=v_uid;
 elsif coalesce((select private.is_academy_admin()),false) then v_target:=p_user_id;
 else raise exception 'Not authorized to view another learner'; end if;
 return query
 select o.objective_code,o.title,o.domain,
        count(distinct m.lesson_id)::bigint,
        count(distinct p.lesson_id) filter(where p.score is not null)::bigint,
        count(distinct p.lesson_id) filter(where p.completed)::bigint,
        round(avg(p.score) filter(where p.score is not null),2),
        case
         when count(distinct p.lesson_id) filter(where p.score is not null)<3 then 'insufficient_evidence'
         when avg(p.score) filter(where p.score is not null)>=80 then 'mastered'
         when avg(p.score) filter(where p.score is not null)>=60 then 'developing'
         else 'needs_practice'
        end
 from private.academy_learning_objectives o
 join private.academy_lesson_objectives m on m.objective_code=o.objective_code
 left join public.academy_lesson_progress p on p.lesson_id=m.lesson_id and p.user_id=v_target
 group by o.objective_code,o.title,o.domain
 order by o.domain,o.objective_code;
end;
$function$;
revoke all on function public.get_academy_lesson_objective_mastery(uuid) from public,anon;
grant execute on function public.get_academy_lesson_objective_mastery(uuid) to authenticated;
comment on function public.get_academy_lesson_objective_mastery(uuid) is 'Per-student objective mastery from scored lesson progress; admins may inspect a selected student, learners only themselves. Requires three scored lesson records before mastery labels.';