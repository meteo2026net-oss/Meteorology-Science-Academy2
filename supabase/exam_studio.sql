-- Exam authoring studio: admin-only question bank maintenance and exam blueprints.
create table if not exists private.academy_exam_definitions (
 id uuid primary key default gen_random_uuid(),
 title text not null,
 description text not null default '',
 track text not null check(track in ('math','physics')),
 level text not null check(level in ('basic','intermediate','advanced')),
 course_id text references public.academy_courses(id) on delete set null,
 duration_minutes integer not null default 20 check(duration_minutes between 1 and 180),
 question_count integer not null default 10 check(question_count between 1 and 50),
 pass_score numeric(5,2) not null default 70 check(pass_score between 50 and 100),
 published boolean not null default false,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table private.academy_exam_definitions enable row level security;
revoke all on private.academy_exam_definitions from public,anon,authenticated;
create index if not exists academy_exam_definitions_track_idx on private.academy_exam_definitions(track,level,published);

create or replace function private.admin_exam_studio_data()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_questions jsonb; v_exams jsonb;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'question_code',q.question_code,'track',q.track,'level',q.level,'topic',q.topic,
 'prompt',q.prompt,'choices',q.choices,'correct_index',q.correct_index,
 'explanation',q.explanation,'active',q.active
 ) order by q.created_at desc),'[]'::jsonb) into v_questions
 from private.academy_exam_questions q;
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',e.id,'title',e.title,'description',e.description,'track',e.track,'level',e.level,
 'course_id',e.course_id,'duration_minutes',e.duration_minutes,'question_count',e.question_count,
 'pass_score',e.pass_score,'published',e.published,'created_at',e.created_at
 ) order by e.created_at desc),'[]'::jsonb) into v_exams
 from private.academy_exam_definitions e;
 return jsonb_build_object('questions',v_questions,'exams',v_exams);
end;
$$;

create or replace function private.admin_save_exam_question(p_data jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_code text; v_track text; v_level text; v_choices jsonb; v_correct integer;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 v_code:=upper(trim(coalesce(p_data->>'question_code','')));
 v_track:=p_data->>'track'; v_level:=p_data->>'level'; v_choices:=p_data->'choices';
 if v_code !~ '^[A-Z0-9_-]{3,32}$' then raise exception 'Question code must contain 3-32 letters, digits, dash or underscore'; end if;
 if v_track not in ('math','physics') or v_level not in ('basic','intermediate','advanced') then raise exception 'Invalid track or level'; end if;
 if jsonb_typeof(v_choices)<>'array' or jsonb_array_length(v_choices)<2 or jsonb_array_length(v_choices)>6 then raise exception 'Provide 2 to 6 answer choices'; end if;
 if exists(select 1 from jsonb_array_elements_text(v_choices) x where length(trim(x))=0) then raise exception 'Answer choices cannot be empty'; end if;
 if coalesce(p_data->>'correct_index','') !~ '^[0-5]$' then raise exception 'Invalid correct answer index'; end if;
 v_correct:=(p_data->>'correct_index')::integer;
 if v_correct>=jsonb_array_length(v_choices) then raise exception 'Correct answer index is outside choices'; end if;
 if length(trim(coalesce(p_data->>'prompt','')))<5 or length(trim(coalesce(p_data->>'topic','')))<2 then raise exception 'Question and topic are required'; end if;
 insert into private.academy_exam_questions(question_code,track,level,topic,prompt,choices,correct_index,explanation,active)
 values(v_code,v_track,v_level,trim(p_data->>'topic'),trim(p_data->>'prompt'),v_choices,v_correct,coalesce(p_data->>'explanation',''),coalesce((p_data->>'active')::boolean,true))
 on conflict(question_code) do update set track=excluded.track,level=excluded.level,topic=excluded.topic,
 prompt=excluded.prompt,choices=excluded.choices,correct_index=excluded.correct_index,
 explanation=excluded.explanation,active=excluded.active;
 return jsonb_build_object('saved',true,'question_code',v_code);
end;
$$;

create or replace function private.admin_save_exam_definition(p_data jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_track text; v_level text; v_count integer; v_active integer; v_title text;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 v_title:=trim(coalesce(p_data->>'title',''));v_track:=p_data->>'track';v_level:=p_data->>'level';
 if length(v_title)<3 then raise exception 'Exam title is required'; end if;
 if v_track not in ('math','physics') or v_level not in ('basic','intermediate','advanced') then raise exception 'Invalid exam track or level'; end if;
 if coalesce(p_data->>'duration_minutes','') !~ '^([1-9]|[1-9][0-9]|1[0-7][0-9]|180)$' then raise exception 'Duration must be 1-180 minutes'; end if;
 if coalesce(p_data->>'question_count','') !~ '^([1-9]|[1-4][0-9]|50)$' then raise exception 'Question count must be 1-50'; end if;
 if coalesce(p_data->>'pass_score','') !~ '^(5[0-9]|[6-9][0-9]|100)(\.[0-9]{1,2})?$' then raise exception 'Pass score must be between 50 and 100'; end if;
 v_count:=(p_data->>'question_count')::integer;
 select count(*) into v_active from private.academy_exam_questions q where q.active and q.track=v_track and q.level=v_level;
 if v_active<v_count then raise exception 'Not enough active questions for this exam. Available: %',v_active; end if;
 v_id:=nullif(p_data->>'id','')::uuid;
 if v_id is null then
  insert into private.academy_exam_definitions(title,description,track,level,course_id,duration_minutes,question_count,pass_score,published,created_by)
  values(v_title,coalesce(p_data->>'description',''),v_track,v_level,nullif(p_data->>'course_id',''),(p_data->>'duration_minutes')::integer,v_count,(p_data->>'pass_score')::numeric,coalesce((p_data->>'published')::boolean,false),(select auth.uid())) returning id into v_id;
 else
  update private.academy_exam_definitions set title=v_title,description=coalesce(p_data->>'description',''),track=v_track,level=v_level,
   course_id=nullif(p_data->>'course_id',''),duration_minutes=(p_data->>'duration_minutes')::integer,
   question_count=v_count,pass_score=(p_data->>'pass_score')::numeric,
   published=coalesce((p_data->>'published')::boolean,false),updated_at=now()
  where id=v_id;
  if not found then raise exception 'Exam definition not found'; end if;
 end if;
 return jsonb_build_object('saved',true,'id',v_id);
end;
$$;

create or replace function private.admin_toggle_exam_question(p_code text,p_active boolean)
returns jsonb language plpgsql security definer set search_path=''
as $$
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 update private.academy_exam_questions set active=p_active where question_code=upper(trim(p_code));
 if not found then raise exception 'Question not found'; end if;
 return jsonb_build_object('saved',true,'question_code',upper(trim(p_code)),'active',p_active);
end;
$$;

create or replace function public.admin_exam_studio_data()
returns jsonb language sql security invoker set search_path='' as $$ select private.admin_exam_studio_data(); $$;
create or replace function public.admin_save_exam_question(p_data jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select private.admin_save_exam_question(p_data); $$;
create or replace function public.admin_save_exam_definition(p_data jsonb)
returns jsonb language sql security invoker set search_path='' as $$ select private.admin_save_exam_definition(p_data); $$;
create or replace function public.admin_toggle_exam_question(p_code text,p_active boolean)
returns jsonb language sql security invoker set search_path='' as $$ select private.admin_toggle_exam_question(p_code,p_active); $$;

revoke all on function private.admin_exam_studio_data() from public,anon;
revoke all on function private.admin_save_exam_question(jsonb) from public,anon;
revoke all on function private.admin_save_exam_definition(jsonb) from public,anon;
revoke all on function private.admin_toggle_exam_question(text,boolean) from public,anon;
grant execute on function private.admin_exam_studio_data() to authenticated;
grant execute on function private.admin_save_exam_question(jsonb) to authenticated;
grant execute on function private.admin_save_exam_definition(jsonb) to authenticated;
grant execute on function private.admin_toggle_exam_question(text,boolean) to authenticated;

revoke all on function public.admin_exam_studio_data() from public,anon;
revoke all on function public.admin_save_exam_question(jsonb) from public,anon;
revoke all on function public.admin_save_exam_definition(jsonb) from public,anon;
revoke all on function public.admin_toggle_exam_question(text,boolean) from public,anon;
grant execute on function public.admin_exam_studio_data() to authenticated;
grant execute on function public.admin_save_exam_question(jsonb) to authenticated;
grant execute on function public.admin_save_exam_definition(jsonb) to authenticated;
grant execute on function public.admin_toggle_exam_question(text,boolean) to authenticated;
