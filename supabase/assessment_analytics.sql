create or replace function public.get_academy_assessment_analytics()
returns jsonb language plpgsql stable security definer
set search_path = public, private, pg_temp
as $fn$
begin
  if auth.uid() is null or not private.is_academy_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', now(),
    'question_bank', jsonb_build_object(
      'total', (select count(*) from private.academy_exam_questions),
      'active', (select count(*) from private.academy_exam_questions where active),
      'inactive', (select count(*) from private.academy_exam_questions where not active),
      'missing_learning_objective', (select count(*) from private.academy_exam_questions where active and nullif(btrim(coalesce(learning_objective,'')),'') is null),
      'missing_explanation', (select count(*) from private.academy_exam_questions where active and nullif(btrim(coalesce(explanation,'')),'') is null),
      'missing_topic', (select count(*) from private.academy_exam_questions where active and nullif(btrim(coalesce(topic,'')),'') is null),
      'blank_prompt', (select count(*) from private.academy_exam_questions where active and nullif(btrim(coalesce(prompt,'')),'') is null),
      'invalid_choices', (select count(*) from private.academy_exam_questions where active and jsonb_typeof(choices) is distinct from 'array'),
      'too_few_choices', (select count(*) from private.academy_exam_questions where active and jsonb_typeof(choices) = 'array' and jsonb_array_length(choices) < 2),
      'invalid_answer_index', (select count(*) from private.academy_exam_questions where active and (correct_index is null or correct_index < 0 or (jsonb_typeof(choices) = 'array' and correct_index >= jsonb_array_length(choices)))),
      'by_type', coalesce((select jsonb_agg(jsonb_build_object('type',coalesce(question_type,'unclassified'),'count',n)) from (select question_type,count(*) n from private.academy_exam_questions where active group by question_type) x),'[]'::jsonb),
      'by_track_level', coalesce((select jsonb_agg(jsonb_build_object('track',track,'level',level,'count',n)) from (select track,level,count(*) n from private.academy_exam_questions where active group by track,level) x),'[]'::jsonb)
    ),
    'assessment_activity', jsonb_build_object(
      'exam_attempts', (select count(*) from public.academy_exam_attempts),
      'unique_students', (select count(distinct user_id) from public.academy_exam_attempts),
      'average_score', (select round(avg(score)::numeric,1) from public.academy_exam_attempts),
      'pass_rate', (select round(100.0 * count(*) filter (where passed) / nullif(count(*),0),1) from public.academy_exam_attempts),
      'published_exams', (select count(*) from private.academy_exam_definitions where published),
      'published_lesson_quizzes', (select count(*) from private.academy_lesson_quiz_assignments where published),
      'open_exam_sessions', (select count(*) from private.academy_exam_sessions where submitted_at is null and expires_at > now()),
      'open_lesson_quiz_sessions', (select count(*) from private.academy_lesson_quiz_sessions where submitted_at is null and expires_at > now()),
      'psychometrics_min_responses', 30,
      'psychometrics_status', case when (select count(*) from public.academy_exam_attempts) = 0 then 'no_student_attempts' else 'sample_not_yet_evaluated' end
    ),
    'learning_content', jsonb_build_object(
      'courses', (select count(*) from public.academy_courses),
      'chapters', (select count(*) from public.academy_chapters),
      'units', (select count(*) from public.academy_units),
      'lessons', (select count(*) from public.academy_lessons),
      'approved_lessons', (select count(*) from private.academy_lesson_reviews where status = 'approved'),
      'pending_lessons', (select count(*) from public.academy_lessons l left join private.academy_lesson_reviews r on r.lesson_id = l.id where coalesce(r.status,'pending') = 'pending'),
      'lessons_without_objectives', (select count(*) from public.academy_lessons l where not exists (select 1 from private.academy_lesson_objectives lo where lo.lesson_id = l.id)),
      'lessons_without_quiz', (select count(*) from public.academy_lessons l where not exists (select 1 from private.academy_lesson_quiz_assignments qa where qa.lesson_id = l.id and qa.published)),
      'lessons_missing_hierarchy', (select count(*) from public.academy_lessons where chapter_id is null or unit_id is null),
      'student_profiles', (select count(*) from public.academy_profiles where role = 'student'),
      'progress_records', (select count(*) from public.academy_lesson_progress),
      'lab_attempts', (select count(*) from public.academy_lab_attempts),
      'students_with_lab_activity', (select count(distinct user_id) from public.academy_lab_attempts),
      'certificates', (select count(*) from public.academy_certificates)
    )
  );
end;
$fn$;
revoke all on function public.get_academy_assessment_analytics() from public, anon;
grant execute on function public.get_academy_assessment_analytics() to authenticated;