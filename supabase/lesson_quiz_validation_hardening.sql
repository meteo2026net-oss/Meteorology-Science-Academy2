create or replace function private.admin_save_lesson_quiz(
 p_lesson_id uuid,p_question_codes text[],p_duration_minutes integer default 10,
 p_pass_score numeric default 70,p_published boolean default false
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_count integer;v_lesson public.academy_lessons%rowtype;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 select * into v_lesson from public.academy_lessons where id=p_lesson_id;
 if not found then raise exception 'Lesson not found'; end if;
 if p_published and (not v_lesson.published or not exists(select 1 from public.academy_courses c where c.id=v_lesson.course_id and c.published)) then
  raise exception 'Publish the lesson and its course before publishing its quiz';
 end if;
 if p_question_codes is null or cardinality(p_question_codes)<3 or cardinality(p_question_codes)>20 then raise exception 'Choose between 3 and 20 questions'; end if;
 if (select count(distinct x) from unnest(p_question_codes) x)<>cardinality(p_question_codes) then raise exception 'Duplicate question codes are not allowed'; end if;
 if p_duration_minutes not between 5 and 90 then raise exception 'Duration must be between 5 and 90 minutes'; end if;
 if p_pass_score not between 1 and 100 then raise exception 'Pass score must be between 1 and 100'; end if;
 select count(*) into v_count from private.academy_exam_questions q where q.question_code=any(p_question_codes) and q.active;
 if v_count<>cardinality(p_question_codes) then raise exception 'Some selected questions are missing or inactive'; end if;
 insert into private.academy_lesson_quiz_assignments(lesson_id,question_codes,duration_minutes,pass_score,published,updated_at,updated_by)
 values(p_lesson_id,p_question_codes,p_duration_minutes,p_pass_score,p_published,now(),(select auth.uid()))
 on conflict(lesson_id) do update set question_codes=excluded.question_codes,duration_minutes=excluded.duration_minutes,
 pass_score=excluded.pass_score,published=excluded.published,updated_at=now(),updated_by=(select auth.uid());
 return jsonb_build_object('saved',true,'lesson_id',p_lesson_id,'question_count',cardinality(p_question_codes),'published',p_published);
end;
$$;

create or replace function private.submit_lesson_quiz(p_session_id uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_session private.academy_lesson_quiz_sessions%rowtype;
 v_lesson public.academy_lessons%rowtype;v_pass_score numeric;v_item jsonb;v_q private.academy_exam_questions%rowtype;
 v_selected integer;v_total integer:=0;v_correct integer:=0;v_score numeric(5,2);v_passed boolean;
 v_review jsonb:='[]'::jsonb;v_attempt uuid;v_level text;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select * into v_session from private.academy_lesson_quiz_sessions where id=p_session_id and user_id=v_uid for update;
 if not found then raise exception 'Quiz session not found'; end if;
 if v_session.submitted_at is not null then raise exception 'Quiz already submitted'; end if;
 if now()>v_session.expires_at+interval '30 seconds' then raise exception 'Quiz time has expired'; end if;
 select * into v_lesson from public.academy_lessons where id=v_session.lesson_id;
 select pass_score into v_pass_score from private.academy_lesson_quiz_assignments where lesson_id=v_session.lesson_id;
 if p_answers is null or jsonb_typeof(p_answers) is distinct from 'array' or jsonb_array_length(p_answers)<>cardinality(v_session.question_codes) then
  raise exception 'Submit an answer record for every question';
 end if;
 if (select count(distinct value->>'question_code') from jsonb_array_elements(p_answers))<>jsonb_array_length(p_answers) then raise exception 'Duplicate question'; end if;
 for v_item in select value from jsonb_array_elements(p_answers) loop
  if not ((v_item->>'question_code')=any(v_session.question_codes)) then raise exception 'Question does not belong to this session'; end if;
  select * into v_q from private.academy_exam_questions where question_code=v_item->>'question_code';
  if not found then raise exception 'Question unavailable'; end if;
  v_selected:=case when coalesce(v_item->>'selected_index','') ~ '^[0-9]+$' then (v_item->>'selected_index')::integer else -1 end;
  if v_selected < -1 or v_selected>=jsonb_array_length(v_q.choices) then raise exception 'Invalid answer choice'; end if;
  v_total:=v_total+1;if v_selected=v_q.correct_index then v_correct:=v_correct+1;end if;
  v_review:=v_review||jsonb_build_array(jsonb_build_object('question_code',v_q.question_code,'topic',v_q.topic,
   'prompt',v_q.prompt,'choices',v_q.choices,'selected_index',case when v_selected=-1 then null else v_selected end,
   'correct_index',v_q.correct_index,'explanation',v_q.explanation,'is_correct',v_selected=v_q.correct_index,
   'question_type',v_q.question_type,'learning_objective',v_q.learning_objective,'formula',v_q.formula,
   'media_url',v_q.media_url,'tags',v_q.tags));
 end loop;
 v_score:=round(v_correct::numeric/v_total::numeric*100,2);v_passed:=v_score>=v_pass_score;
 v_level:=case when v_lesson.level in ('beginner','basic') then 'basic' when v_lesson.level='intermediate' then 'intermediate' when v_lesson.level='advanced' then 'advanced' else 'all' end;
 insert into public.academy_exam_attempts(user_id,track,level,score,correct_count,total_count,passed,answers,exam_title,course_id,lesson_id)
 values(v_uid,'all',v_level,v_score,v_correct,v_total,v_passed,v_review,'اختبار الدرس: '||v_lesson.title,v_lesson.course_id,v_lesson.id)
 returning id into v_attempt;
 update private.academy_lesson_quiz_sessions set submitted_at=now(),attempt_id=v_attempt where id=v_session.id;
 insert into public.academy_lesson_progress(user_id,lesson_id,completed,score,updated_at)
 values(v_uid,v_lesson.id,v_passed,v_score,now())
 on conflict(user_id,lesson_id) do update set completed=public.academy_lesson_progress.completed or excluded.completed,
 score=excluded.score,updated_at=now();
 return jsonb_build_object('attempt_id',v_attempt,'lesson_id',v_lesson.id,'score',v_score,
 'correct_count',v_correct,'total_count',v_total,'passed',v_passed,'pass_score',v_pass_score,'review',v_review);
end;
$$;
revoke all on function private.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean) from public,anon;
revoke all on function private.submit_lesson_quiz(uuid,jsonb) from public,anon;
grant execute on function private.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean) to authenticated;
grant execute on function private.submit_lesson_quiz(uuid,jsonb) to authenticated;
