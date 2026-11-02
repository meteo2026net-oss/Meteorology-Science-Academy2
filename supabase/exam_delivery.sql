-- Published exam catalogue and server-timed exam sessions.
create table if not exists private.academy_exam_sessions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 exam_id uuid not null references private.academy_exam_definitions(id) on delete restrict,
 question_codes text[] not null,
 started_at timestamptz not null default now(),
 expires_at timestamptz not null,
 submitted_at timestamptz,
 attempt_id uuid,
 created_at timestamptz not null default now()
);
alter table private.academy_exam_sessions enable row level security;
revoke all on private.academy_exam_sessions from public,anon,authenticated;
drop policy if exists deny_client_access_exam_sessions on private.academy_exam_sessions;
create policy deny_client_access_exam_sessions on private.academy_exam_sessions for all to public using(false) with check(false);
create index if not exists academy_exam_sessions_user_created_idx on private.academy_exam_sessions(user_id,created_at desc);

create or replace function private.get_published_academy_exams()
returns jsonb language sql security definer set search_path=''
as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',e.id,'title',e.title,'description',e.description,'track',e.track,'level',e.level,
  'duration_minutes',e.duration_minutes,'question_count',e.question_count,'pass_score',e.pass_score,
  'course_id',e.course_id
 ) order by e.created_at desc),'[]'::jsonb)
 from private.academy_exam_definitions e where e.published=true;
$$;

create or replace function private.begin_academy_exam(p_exam_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid()); v_exam private.academy_exam_definitions%rowtype;
 v_codes text[]; v_questions jsonb; v_session uuid; v_now timestamptz:=now();
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select * into v_exam from private.academy_exam_definitions where id=p_exam_id and published=true;
 if not found then raise exception 'Exam is unavailable'; end if;
 if exists(select 1 from private.academy_exam_sessions s where s.user_id=v_uid and s.exam_id=p_exam_id and s.submitted_at is null and s.expires_at>v_now) then
  raise exception 'You already have an active attempt for this exam';
 end if;
 select array_agg(x.question_code) into v_codes from (
  select q.question_code from private.academy_exam_questions q
  where q.active and q.track=v_exam.track and q.level=v_exam.level
  order by random() limit v_exam.question_count
 ) x;
 if coalesce(array_length(v_codes,1),0)<>v_exam.question_count then raise exception 'Not enough active questions to start this exam'; end if;
 insert into private.academy_exam_sessions(user_id,exam_id,question_codes,started_at,expires_at)
 values(v_uid,p_exam_id,v_codes,v_now,v_now+make_interval(mins=>v_exam.duration_minutes))
 returning id into v_session;
 select jsonb_agg(jsonb_build_object('question_code',q.question_code,'track',q.track,'level',q.level,
 'topic',q.topic,'prompt',q.prompt,'choices',q.choices) order by array_position(v_codes,q.question_code))
 into v_questions from private.academy_exam_questions q where q.question_code=any(v_codes);
 return jsonb_build_object('session_id',v_session,'exam_id',v_exam.id,'title',v_exam.title,
 'track',v_exam.track,'level',v_exam.level,'duration_minutes',v_exam.duration_minutes,
 'pass_score',v_exam.pass_score,'started_at',v_now,'expires_at',v_now+make_interval(mins=>v_exam.duration_minutes),
 'questions',coalesce(v_questions,'[]'::jsonb));
end;
$$;

create or replace function private.submit_defined_academy_exam(p_session_id uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid()); v_session private.academy_exam_sessions%rowtype;
 v_exam private.academy_exam_definitions%rowtype; v_item jsonb; v_q private.academy_exam_questions%rowtype;
 v_selected integer; v_total integer:=0; v_correct integer:=0; v_score numeric(5,2); v_passed boolean;
 v_review jsonb:='[]'::jsonb; v_attempt uuid; v_cert public.academy_certificates%rowtype; v_name text;
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
  v_total:=v_total+1;
  if v_selected=v_q.correct_index then v_correct:=v_correct+1; end if;
  v_review:=v_review||jsonb_build_array(jsonb_build_object('question_code',v_q.question_code,'topic',v_q.topic,'prompt',v_q.prompt,
   'choices',v_q.choices,'selected_index',case when v_selected=-1 then null else v_selected end,
   'correct_index',v_q.correct_index,'explanation',v_q.explanation,'is_correct',v_selected=v_q.correct_index));
 end loop;
 v_score:=round(v_correct::numeric/v_total::numeric*100,2);v_passed:=v_score>=v_exam.pass_score;
 insert into public.academy_exam_attempts(user_id,track,level,score,correct_count,total_count,passed,answers)
 values(v_uid,v_exam.track,v_exam.level,v_score,v_correct,v_total,v_passed,v_review) returning id into v_attempt;
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

create or replace function public.get_published_academy_exams()
returns jsonb language sql security invoker set search_path='' as $$ select private.get_published_academy_exams(); $$;
create or replace function public.begin_academy_exam(p_exam_id uuid)
returns jsonb language sql security invoker set search_path='' as $$ select private.begin_academy_exam(p_exam_id); $$;
create or replace function public.submit_defined_academy_exam(p_session_id uuid,p_answers jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select private.submit_defined_academy_exam(p_session_id,p_answers); $$;
revoke all on function private.get_published_academy_exams() from public,anon;
revoke all on function private.begin_academy_exam(uuid) from public,anon;
revoke all on function private.submit_defined_academy_exam(uuid,jsonb) from public,anon;
grant execute on function private.get_published_academy_exams() to authenticated;
grant execute on function private.begin_academy_exam(uuid) to authenticated;
grant execute on function private.submit_defined_academy_exam(uuid,jsonb) to authenticated;
revoke all on function public.get_published_academy_exams() from public,anon;
revoke all on function public.begin_academy_exam(uuid) from public,anon;
revoke all on function public.submit_defined_academy_exam(uuid,jsonb) from public,anon;
grant execute on function public.get_published_academy_exams() to authenticated;
grant execute on function public.begin_academy_exam(uuid) to authenticated;
grant execute on function public.submit_defined_academy_exam(uuid,jsonb) to authenticated;
