-- Link exam attempts to the published blueprint and retain rich review metadata.
alter table public.academy_exam_attempts
 add column if not exists exam_definition_id uuid references private.academy_exam_definitions(id) on delete set null,
 add column if not exists exam_title text not null default '',
 add column if not exists course_id text;

create index if not exists academy_exam_attempts_definition_idx
 on public.academy_exam_attempts(exam_definition_id,created_at desc);

create or replace function private.submit_defined_academy_exam(p_session_id uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_uid uuid:=(select auth.uid());v_session private.academy_exam_sessions%rowtype;
 v_exam private.academy_exam_definitions%rowtype;v_item jsonb;v_q private.academy_exam_questions%rowtype;
 v_selected integer;v_total integer:=0;v_correct integer:=0;v_score numeric(5,2);v_passed boolean;
 v_review jsonb:='[]'::jsonb;v_attempt uuid;v_cert public.academy_certificates%rowtype;v_name text;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select * into v_session from private.academy_exam_sessions where id=p_session_id and user_id=v_uid for update;
 if not found then raise exception 'Exam session not found'; end if;
 if v_session.submitted_at is not null then raise exception 'This exam session has already been submitted'; end if;
 if now()>v_session.expires_at+interval '30 seconds' then raise exception 'Exam time has expired'; end if;
 select * into v_exam from private.academy_exam_definitions where id=v_session.exam_id;
 if not found then raise exception 'Exam definition unavailable'; end if;
 if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>array_length(v_session.question_codes,1) then
  raise exception 'Submit an answer record for every exam question';
 end if;
 if (select count(distinct value->>'question_code') from jsonb_array_elements(p_answers))<>jsonb_array_length(p_answers) then raise exception 'Duplicate question'; end if;
 for v_item in select value from jsonb_array_elements(p_answers) loop
  if not ((v_item->>'question_code')=any(v_session.question_codes)) then raise exception 'Question does not belong to this session'; end if;
  select * into v_q from private.academy_exam_questions where question_code=v_item->>'question_code';
  if not found then raise exception 'Question unavailable'; end if;
  v_selected:=case when coalesce(v_item->>'selected_index','') ~ '^[0-9]+$' then (v_item->>'selected_index')::integer else -1 end;
  if v_selected < -1 or v_selected>=jsonb_array_length(v_q.choices) then raise exception 'Invalid answer choice'; end if;
  v_total:=v_total+1;if v_selected=v_q.correct_index then v_correct:=v_correct+1;end if;
  v_review:=v_review||jsonb_build_array(jsonb_build_object(
   'question_code',v_q.question_code,'topic',v_q.topic,'prompt',v_q.prompt,'choices',v_q.choices,
   'selected_index',case when v_selected=-1 then null else v_selected end,'correct_index',v_q.correct_index,
   'explanation',v_q.explanation,'is_correct',v_selected=v_q.correct_index,
   'question_type',v_q.question_type,'learning_objective',v_q.learning_objective,
   'formula',v_q.formula,'media_url',v_q.media_url,'tags',v_q.tags
  ));
 end loop;
 v_score:=round(v_correct::numeric/v_total::numeric*100,2);v_passed:=v_score>=v_exam.pass_score;
 insert into public.academy_exam_attempts(user_id,track,level,score,correct_count,total_count,passed,answers,
  exam_definition_id,exam_title,course_id)
 values(v_uid,v_exam.track,v_exam.level,v_score,v_correct,v_total,v_passed,v_review,
  v_exam.id,v_exam.title,v_exam.course_id) returning id into v_attempt;
 update private.academy_exam_sessions set submitted_at=now(),attempt_id=v_attempt where id=v_session.id;
 if v_passed and v_exam.track in ('math','physics') then
  select coalesce(display_name,'طالب الأكاديمية') into v_name from public.academy_profiles where id=v_uid;
  insert into public.academy_certificates(user_id,exam_attempt_id,student_name,track,score)
  values(v_uid,v_attempt,coalesce(nullif(v_name,''),'طالب الأكاديمية'),v_exam.track,v_score)
  returning * into v_cert;
 end if;
 return jsonb_build_object('attempt_id',v_attempt,'score',v_score,'correct_count',v_correct,'total_count',v_total,
  'passed',v_passed,'pass_score',v_exam.pass_score,'review',v_review,
  'certificate',case when v_cert.id is null then null else jsonb_build_object('certificate_code',v_cert.certificate_code,
   'student_name',v_cert.student_name,'track',v_cert.track,'score',v_cert.score,'issued_at',v_cert.issued_at) end);
end;
$$;
revoke all on function private.submit_defined_academy_exam(uuid,jsonb) from public,anon;
grant execute on function private.submit_defined_academy_exam(uuid,jsonb) to authenticated;
