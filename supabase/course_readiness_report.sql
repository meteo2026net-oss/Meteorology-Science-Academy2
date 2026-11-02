-- Admin-only course readiness report. Read-only; no publishing or content mutation.
create or replace function public.get_academy_course_readiness_report()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, private, pg_temp
as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not private.is_academy_admin() then
    raise insufficient_privilege using message = 'Admin access required';
  end if;
  with lesson_facts as (
    select l.id,l.course_id,l.published,l.chapter_id,l.unit_id,
      coalesce(r.status,'pending') review_status,
      exists(select 1 from private.academy_lesson_objectives o where o.lesson_id=l.id) has_objective_mapping,
      exists(select 1 from private.academy_lesson_quiz_assignments q where q.lesson_id=l.id and q.published) has_published_quiz
    from public.academy_lessons l
    left join private.academy_lesson_reviews r on r.lesson_id=l.id
  ),
  course_facts as (
    select c.id,c.title,c.published,
      (select count(*) from public.academy_chapters ch where ch.course_id=c.id) chapter_count,
      (select count(*) from public.academy_units u join public.academy_chapters ch on ch.id=u.chapter_id where ch.course_id=c.id) unit_count,
      count(lf.id) lesson_count,
      count(lf.id) filter(where lf.published) published_lessons,
      count(lf.id) filter(where lf.review_status='approved') approved_lessons,
      count(lf.id) filter(where lf.review_status='pending') pending_review_lessons,
      count(lf.id) filter(where lf.review_status='changes_requested') changes_requested_lessons,
      count(lf.id) filter(where lf.review_status='rejected') rejected_lessons,
      count(lf.id) filter(where not lf.has_objective_mapping) lessons_without_objective_mapping,
      count(lf.id) filter(where not lf.has_published_quiz) lessons_without_published_quiz,
      count(lf.id) filter(where lf.chapter_id is null or lf.unit_id is null) lessons_without_hierarchy
    from public.academy_courses c left join lesson_facts lf on lf.course_id=c.id
    group by c.id,c.title,c.published
  ),
  summarized as (
    select cf.*,
      (cf.lesson_count=0) or (cf.approved_lessons < cf.lesson_count)
      or cf.lessons_without_objective_mapping>0 or cf.lessons_without_hierarchy>0
      or cf.lessons_without_published_quiz>0 or cf.chapter_count=0 or cf.unit_count=0
      as has_readiness_blockers
    from course_facts cf
  )
  select jsonb_build_object(
    'generated_at',now(),
    'summary',jsonb_build_object(
      'courses_total',count(*),'courses_published',count(*) filter(where published),
      'courses_ready',count(*) filter(where not has_readiness_blockers),
      'courses_blocked',count(*) filter(where has_readiness_blockers),
      'lessons_total',coalesce(sum(lesson_count),0),
      'lessons_approved',coalesce(sum(approved_lessons),0),
      'lessons_pending_review',coalesce(sum(pending_review_lessons),0),
      'lessons_without_objectives',coalesce(sum(lessons_without_objective_mapping),0),
      'lessons_without_quiz',coalesce(sum(lessons_without_published_quiz),0)
    ),
    'courses',coalesce(jsonb_agg(jsonb_build_object(
      'id',id,'title',title,'published',published,'chapter_count',chapter_count,
      'unit_count',unit_count,'lesson_count',lesson_count,'published_lessons',published_lessons,
      'approved_lessons',approved_lessons,'pending_review_lessons',pending_review_lessons,
      'changes_requested_lessons',changes_requested_lessons,'rejected_lessons',rejected_lessons,
      'lessons_without_objective_mapping',lessons_without_objective_mapping,
      'lessons_without_published_quiz',lessons_without_published_quiz,
      'lessons_without_hierarchy',lessons_without_hierarchy,
      'has_readiness_blockers',has_readiness_blockers
    ) order by title),'[]'::jsonb)
  ) into v_result from summarized;
  return v_result;
end;
$$;
revoke all on function public.get_academy_course_readiness_report() from public,anon;
grant execute on function public.get_academy_course_readiness_report() to authenticated;
