-- Objective-level learning analytics from server-graded exam reviews.
-- No psychometric difficulty/discrimination metrics are inferred from small samples.
create or replace function private.get_academy_objective_mastery(p_user_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_target uuid;
  v_is_admin boolean := coalesce((select private.is_academy_admin()), false);
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_user_id is null then
    v_target := v_uid;
  elsif v_is_admin or p_user_id = v_uid then
    v_target := p_user_id;
  else
    raise exception 'Not authorized to view another learner';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'objective', x.objective,
    'responses', x.responses,
    'attempts', x.attempts,
    'correct', x.correct,
    'accuracy', round(100.0 * x.correct / nullif(x.responses, 0), 1),
    'last_activity', x.last_activity,
    'sample_status', case when x.responses >= 5 and x.attempts >= 2 then 'usable' else 'limited' end,
    'level', case
      when x.responses < 5 or x.attempts < 2 then 'insufficient_data'
      when 100.0 * x.correct / nullif(x.responses, 0) >= 80 then 'strong'
      when 100.0 * x.correct / nullif(x.responses, 0) >= 50 then 'developing'
      else 'needs_support' end
  ) order by x.responses desc, x.objective), '[]'::jsonb)
  into v_result
  from (
    select coalesce(nullif(btrim(item.value->>'learning_objective'), ''),
      nullif(btrim(item.value->>'topic'), ''), 'غير مصنف') as objective,
      count(*)::integer as responses,
      count(distinct a.id)::integer as attempts,
      count(*) filter (where coalesce((item.value->>'is_correct')::boolean, false))::integer as correct,
      max(a.created_at) as last_activity
    from public.academy_exam_attempts a
    cross join lateral jsonb_array_elements(
      case when jsonb_typeof(a.answers) = 'array' then a.answers else '[]'::jsonb end
    ) as item(value)
    where a.user_id = v_target
    group by 1
  ) x;
  return v_result;
end;
$$;

create or replace function public.get_academy_objective_mastery(p_user_id uuid default null)
returns jsonb language sql security invoker set search_path=''
as $$ select private.get_academy_objective_mastery($1); $$;

revoke all on function private.get_academy_objective_mastery(uuid) from public, anon;
grant execute on function private.get_academy_objective_mastery(uuid) to authenticated;
revoke all on function public.get_academy_objective_mastery(uuid) from public, anon;
grant execute on function public.get_academy_objective_mastery(uuid) to authenticated;
comment on function public.get_academy_objective_mastery(uuid) is
'Returns per-objective accuracy from server-graded answer reviews. Requires at least five responses across two attempts before assigning a provisional skill band.';
