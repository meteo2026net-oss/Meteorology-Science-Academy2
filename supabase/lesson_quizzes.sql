-- Lesson-linked quizzes: secure assignment, delivery, server-side grading and progress integration.
alter table public.academy_exam_attempts
 add column if not exists lesson_id uuid references public.academy_lessons(id) on delete set null;
create index if not exists academy_exam_attempts_lesson_idx
 on public.academy_exam_attempts(lesson_id,created_at desc) where lesson_id is not null;

create table if not exists private.academy_lesson_quiz_assignments(
 lesson_id uuid primary key references public.academy_lessons(id) on delete cascade,
 question_codes text[] not null,
 duration_minutes integer not null default 10 check(duration_minutes between 5 and 90),
 pass_score numeric(5,2) not null default 70 check(pass_score between 1 and 100),
 published boolean not null default false,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
alter table private.academy_lesson_quiz_assignments enable row level security;
revoke all on private.academy_lesson_quiz_assignments from public,anon,authenticated;
drop policy if exists lesson_quiz_assignments_deny_all on private.academy_lesson_quiz_assignments;
create policy lesson_quiz_assignments_deny_all on private.academy_lesson_quiz_assignments for all to public using(false) with check(false);

create table if not exists private.academy_lesson_quiz_sessions(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 lesson_id uuid not null references public.academy_lessons(id) on delete cascade,
 question_codes text[] not null,
 started_at timestamptz not null default now(),
 expires_at timestamptz not null,
 submitted_at timestamptz,
 attempt_id uuid references public.academy_exam_attempts(id) on delete set null,
 created_at timestamptz not null default now()
);
alter table private.academy_lesson_quiz_sessions enable row level security;
revoke all on private.academy_lesson_quiz_sessions from public,anon,authenticated;
drop policy if exists lesson_quiz_sessions_deny_all on private.academy_lesson_quiz_sessions;
create policy lesson_quiz_sessions_deny_all on private.academy_lesson_quiz_sessions for all to public using(false) with check(false);
create index if not exists academy_lesson_quiz_sessions_user_idx on private.academy_lesson_quiz_sessions(user_id,created_at desc);

create or replace function private.admin_lesson_quiz_data()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_lessons jsonb;v_questions jsonb;v_assignments jsonb;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'title',l.title,'slug',l.slug,'course_id',l.course_id,
  'course_title',c.title,'level',l.level,'published',l.published,'chapter_title',l.chapter_title)
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

create or replace function private.get_lesson_quiz(p_lesson_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select jsonb_build_object('lesson_id',l.id,'title',l.title,'duration_minutes',a.duration_minutes,
 'pass_score',a.pass_score,'question_count',cardinality(a.question_codes))
 into v_result
 from public.academy_lessons l join public.academy_courses c on c.id=l.course_id
 join private.academy_lesson_quiz_assignments a on a.lesson_id=l.id
 where l.id=p_lesson_id and l.published and c.published and a.published;
 return coalesce(v_result,'null'::jsonb);
end;
$$;

create or replace function private.begin_lesson_quiz(p_lesson_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_lesson public.academy_lessons%rowtype;
 v_codes text[];v_questions jsonb;v_session uuid;v_duration integer;v_now timestamptz:=now();
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select l.* into v_lesson from public.academy_lessons l join public.academy_courses c on c.id=l.course_id
 join private.academy_lesson_quiz_assignments a on a.lesson_id=l.id
 where l.id=p_lesson_id and l.published and c.published and a.published;
 if not found then raise exception 'Lesson quiz is unavailable'; end if;
 select question_codes,duration_minutes into v_codes,v_duration
 from private.academy_lesson_quiz_assignments where lesson_id=p_lesson_id;
 if exists(select 1 from private.academy_lesson_quiz_sessions s where s.user_id=v_uid and s.lesson_id=p_lesson_id and s.submitted_at is null and s.expires_at>v_now) then
  raise exception 'You already have an active quiz for this lesson';
 end if;
 if (select count(*) from private.academy_exam_questions q where q.question_code=any(v_codes) and q.active)<>cardinality(v_codes) then
  raise exception 'Some quiz questions are no longer available';
 end if;
 insert into private.academy_lesson_quiz_sessions(user_id,lesson_id,question_codes,started_at,expires_at)
 values(v_uid,p_lesson_id,v_codes,v_now,v_now+make_interval(mins=>v_duration)) returning id into v_session;
 select jsonb_agg(jsonb_build_object('question_code',q.question_code,'topic',q.topic,'prompt',q.prompt,
 'choices',q.choices,'question_type',q.question_type,'learning_objective',q.learning_objective,
 'formula',q.formula,'media_url',q.media_url) order by array_position(v_codes,q.question_code))
 into v_questions from private.academy_exam_questions q where q.question_code=any(v_codes);
 return jsonb_build_object('session_id',v_session,'lesson_id',p_lesson_id,'title',v_lesson.title,
 'started_at',v_now,'expires_at',v_now+make_interval(mins=>v_duration),'questions',coalesce(v_questions,'[]'::jsonb));
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
 if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>cardinality(v_session.question_codes) then raise exception 'Submit an answer record for every question'; end if;
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

create or replace function private.cancel_lesson_quiz(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_count integer;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 update private.academy_lesson_quiz_sessions set submitted_at=now()
 where id=p_session_id and user_id=v_uid and submitted_at is null;
 get diagnostics v_count=row_count;
 if v_count=0 then raise exception 'Quiz session not found or already closed'; end if;
 return jsonb_build_object('cancelled',true);
end;
$$;

-- Public invoker wrappers: all privileged work remains in the non-exposed private schema.
create or replace function public.admin_lesson_quiz_data()
returns jsonb language sql security invoker set search_path=''
as $$ select private.admin_lesson_quiz_data(); $$;
create or replace function public.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean)
returns jsonb language sql security invoker set search_path=''
as $$ select private.admin_save_lesson_quiz($1,$2,$3,$4,$5); $$;
create or replace function public.get_lesson_quiz(uuid)
returns jsonb language sql security invoker set search_path=''
as $$ select private.get_lesson_quiz($1); $$;
create or replace function public.begin_lesson_quiz(uuid)
returns jsonb language sql security invoker set search_path=''
as $$ select private.begin_lesson_quiz($1); $$;
create or replace function public.submit_lesson_quiz(uuid,jsonb)
returns jsonb language sql security invoker set search_path=''
as $$ select private.submit_lesson_quiz($1,$2); $$;
create or replace function public.cancel_lesson_quiz(uuid)
returns jsonb language sql security invoker set search_path=''
as $$ select private.cancel_lesson_quiz($1); $$;

revoke all on function private.admin_lesson_quiz_data() from public,anon;
revoke all on function private.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean) from public,anon;
revoke all on function private.get_lesson_quiz(uuid) from public,anon;
revoke all on function private.begin_lesson_quiz(uuid) from public,anon;
revoke all on function private.submit_lesson_quiz(uuid,jsonb) from public,anon;
revoke all on function private.cancel_lesson_quiz(uuid) from public,anon;
grant execute on function private.admin_lesson_quiz_data() to authenticated;
grant execute on function private.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean) to authenticated;
grant execute on function private.get_lesson_quiz(uuid) to authenticated;
grant execute on function private.begin_lesson_quiz(uuid) to authenticated;
grant execute on function private.submit_lesson_quiz(uuid,jsonb) to authenticated;
grant execute on function private.cancel_lesson_quiz(uuid) to authenticated;
revoke all on function public.admin_lesson_quiz_data() from public,anon;
revoke all on function public.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean) from public,anon;
revoke all on function public.get_lesson_quiz(uuid) from public,anon;
revoke all on function public.begin_lesson_quiz(uuid) from public,anon;
revoke all on function public.submit_lesson_quiz(uuid,jsonb) from public,anon;
revoke all on function public.cancel_lesson_quiz(uuid) from public,anon;
grant execute on function public.admin_lesson_quiz_data() to authenticated;
grant execute on function public.admin_save_lesson_quiz(uuid,text[],integer,numeric,boolean) to authenticated;
grant execute on function public.get_lesson_quiz(uuid) to authenticated;
grant execute on function public.begin_lesson_quiz(uuid) to authenticated;
grant execute on function public.submit_lesson_quiz(uuid,jsonb) to authenticated;
grant execute on function public.cancel_lesson_quiz(uuid) to authenticated;
