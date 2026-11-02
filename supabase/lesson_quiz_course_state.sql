create or replace function private.admin_lesson_quiz_data()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_lessons jsonb;v_questions jsonb;v_assignments jsonb;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'title',l.title,'slug',l.slug,'course_id',l.course_id,
  'course_title',c.title,'course_published',c.published,'level',l.level,'published',l.published,'chapter_title',l.chapter_title)
  order by c.sort_order,l.sort_order,l.title),'[]'::jsonb)
 into v_lessons from public.academy_lessons l join public.academy_courses c on c.id=l.course_id;
 select coalesce(jsonb_agg(jsonb_build_object('question_code',q.question_code,'track',q.track,'level',q.level,
  'topic',q.topic,'prompt',q.prompt,'choices',q.choices,'correct_index',q.correct_index,'active',q.active,
  'question_type',q.question_type,'learning_objective',q.learning_objective)
  order by q.track,q.level,q.question_code),'[]'::jsonb)
 into v_questions from private.academy_exam_questions q where q.active;
 select coalesce(jsonb_agg(jsonb_build_object('lesson_id',a.lesson_id,'question_codes',a.question_codes,
  'duration_minutes',a.duration_minutes,'pass_score',a.pass_score,'published',a.published,'updated_at',a.updated_at)
  order by a.updated_at desc),'[]'::jsonb)
 into v_assignments from private.academy_lesson_quiz_assignments a;
 return jsonb_build_object('lessons',v_lessons,'questions',v_questions,'assignments',v_assignments);
end;
$$;
revoke all on function private.admin_lesson_quiz_data() from public,anon;
grant execute on function private.admin_lesson_quiz_data() to authenticated;
