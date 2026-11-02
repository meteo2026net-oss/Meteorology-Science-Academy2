-- Admin-only, read-only structural quality report for academy lessons.
create or replace function public.get_academy_content_quality_report()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, private, pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not private.is_academy_admin() then
    raise insufficient_privilege using message = 'Admin access required';
  end if;

  with lesson_base as (
    select l.id, l.course_id, c.title as course_title, l.title, l.slug,
           l.summary, l.content, l.published, l.estimated_minutes,
           l.learning_objectives, l.chapter_id, l.unit_id
    from public.academy_lessons l
    left join public.academy_courses c on c.id = l.course_id
  ),
  duplicate_slugs as (
    select course_id, slug from lesson_base
    group by course_id, slug having count(*) > 1
  ),
  issues as (
    select id, course_id, course_title, title, 'empty_title'::text code, 'عنوان الدرس فارغ'::text detail
      from lesson_base where nullif(btrim(title), '') is null
    union all
    select id, course_id, course_title, title, 'empty_slug', 'معرّف الدرس slug فارغ'
      from lesson_base where nullif(btrim(slug), '') is null
    union all
    select id, course_id, course_title, title, 'empty_summary', 'ملخص الدرس غير مكتمل'
      from lesson_base where nullif(btrim(summary), '') is null
    union all
    select id, course_id, course_title, title, 'empty_content', 'محتوى الدرس فارغ أو ليس كائن JSON'
      from lesson_base where content is null or content = '{}'::jsonb or content = '[]'::jsonb
    union all
    select id, course_id, course_title, title, 'missing_objectives', 'لا توجد أهداف تعلم معرفة للدرس'
      from lesson_base where learning_objectives is null or learning_objectives = '[]'::jsonb
         or jsonb_typeof(learning_objectives) <> 'array'
    union all
    select id, course_id, course_title, title, 'invalid_duration', 'المدة التقديرية خارج النطاق 1–240 دقيقة'
      from lesson_base where estimated_minutes < 1 or estimated_minutes > 240
    union all
    select id, course_id, course_title, title, 'missing_hierarchy', 'الدرس غير مربوط بفصل أو وحدة'
      from lesson_base where chapter_id is null or unit_id is null
    union all
    select b.id, b.course_id, b.course_title, b.title, 'duplicate_slug', 'يوجد أكثر من درس بالمعرّف نفسه داخل المقرر'
      from lesson_base b join duplicate_slugs d on d.course_id = b.course_id and d.slug = b.slug
  ),
  counts as (
    select count(*) total_lessons,
           count(*) filter (where published) published_lessons,
           count(*) filter (where not published) draft_lessons
    from lesson_base
  )
  select jsonb_build_object(
    'generated_at', now(),
    'summary', jsonb_build_object(
      'total_lessons', c.total_lessons,
      'published_lessons', c.published_lessons,
      'draft_lessons', c.draft_lessons,
      'issues_total', (select count(*) from issues),
      'lessons_with_issues', (select count(distinct id) from issues)
    ),
    'issues', coalesce((
      select jsonb_agg(jsonb_build_object(
        'lesson_id', q.id, 'course_id', q.course_id,
        'course_title', q.course_title, 'lesson_title', q.title,
        'code', q.code, 'detail', q.detail
      ) order by q.course_title, q.lesson_title, q.code)
      from (select * from issues order by course_title, title, code limit 300) q
    ), '[]'::jsonb)
  ) into v_result from counts c;
  return v_result;
end;
$$;

revoke all on function public.get_academy_content_quality_report() from public, anon;
grant execute on function public.get_academy_content_quality_report() to authenticated;
