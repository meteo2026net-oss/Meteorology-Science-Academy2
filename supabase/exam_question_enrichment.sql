-- Enrich question bank for meteorology-focused assessment. Additive and safe to re-run.
alter table private.academy_exam_questions
 add column if not exists question_type text not null default 'concept',
 add column if not exists learning_objective text not null default '',
 add column if not exists formula text not null default '',
 add column if not exists media_url text not null default '',
 add column if not exists tags text[] not null default '{}';

do $$ begin
 if not exists(select 1 from pg_constraint where conname='academy_exam_questions_type_check') then
  alter table private.academy_exam_questions add constraint academy_exam_questions_type_check
  check(question_type in ('concept','calculation','data_interpretation','map_analysis'));
 end if;
 if not exists(select 1 from pg_constraint where conname='academy_exam_questions_media_url_check') then
  alter table private.academy_exam_questions add constraint academy_exam_questions_media_url_check
  check(media_url='' or media_url ~ '^https://');
 end if;
end $$;

create index if not exists academy_exam_questions_type_idx on private.academy_exam_questions(track,level,question_type,active);

create or replace function private.admin_exam_studio_data()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_questions jsonb; v_exams jsonb;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'question_code',q.question_code,'track',q.track,'level',q.level,'topic',q.topic,
 'prompt',q.prompt,'choices',q.choices,'correct_index',q.correct_index,
 'explanation',q.explanation,'active',q.active,'question_type',q.question_type,
 'learning_objective',q.learning_objective,'formula',q.formula,'media_url',q.media_url,'tags',q.tags
 ) order by q.created_at desc),'[]'::jsonb) into v_questions from private.academy_exam_questions q;
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',e.id,'title',e.title,'description',e.description,'track',e.track,'level',e.level,
 'course_id',e.course_id,'duration_minutes',e.duration_minutes,'question_count',e.question_count,
 'pass_score',e.pass_score,'published',e.published,'created_at',e.created_at
 ) order by e.created_at desc),'[]'::jsonb) into v_exams from private.academy_exam_definitions e;
 return jsonb_build_object('questions',v_questions,'exams',v_exams);
end;
$$;

create or replace function private.admin_save_exam_question(p_data jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_code text; v_track text; v_level text; v_choices jsonb; v_correct integer;
 v_type text; v_media text;
begin
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Administrator access required'; end if;
 v_code:=upper(trim(coalesce(p_data->>'question_code','')));
 v_track:=p_data->>'track';v_level:=p_data->>'level';v_choices:=p_data->'choices';
 v_type:=coalesce(nullif(p_data->>'question_type',''),'concept');v_media:=trim(coalesce(p_data->>'media_url',''));
 if v_code !~ '^[A-Z0-9_-]{3,32}$' then raise exception 'Invalid question code'; end if;
 if v_track not in ('math','physics') or v_level not in ('basic','intermediate','advanced') then raise exception 'Invalid track or level'; end if;
 if v_type not in ('concept','calculation','data_interpretation','map_analysis') then raise exception 'Invalid question type'; end if;
 if v_media<>'' and v_media !~ '^https://' then raise exception 'Media URL must use HTTPS'; end if;
 if jsonb_typeof(v_choices)<>'array' or jsonb_array_length(v_choices)<2 or jsonb_array_length(v_choices)>6 then raise exception 'Provide 2 to 6 answer choices'; end if;
 if exists(select 1 from jsonb_array_elements_text(v_choices) x where length(trim(x))=0) then raise exception 'Answer choices cannot be empty'; end if;
 if coalesce(p_data->>'correct_index','') !~ '^[0-5]$' then raise exception 'Invalid correct answer index'; end if;
 v_correct:=(p_data->>'correct_index')::integer;
 if v_correct>=jsonb_array_length(v_choices) then raise exception 'Correct answer index is outside choices'; end if;
 if length(trim(coalesce(p_data->>'prompt','')))<5 or length(trim(coalesce(p_data->>'topic','')))<2 then raise exception 'Question and topic are required'; end if;
 insert into private.academy_exam_questions(question_code,track,level,topic,prompt,choices,correct_index,explanation,active,
 question_type,learning_objective,formula,media_url,tags)
 values(v_code,v_track,v_level,trim(p_data->>'topic'),trim(p_data->>'prompt'),v_choices,v_correct,
 coalesce(p_data->>'explanation',''),coalesce((p_data->>'active')::boolean,true),v_type,
 coalesce(p_data->>'learning_objective',''),coalesce(p_data->>'formula',''),v_media,
 coalesce(array(select jsonb_array_elements_text(coalesce(p_data->'tags','[]'::jsonb))),'{}'))
 on conflict(question_code) do update set track=excluded.track,level=excluded.level,topic=excluded.topic,
 prompt=excluded.prompt,choices=excluded.choices,correct_index=excluded.correct_index,explanation=excluded.explanation,
 active=excluded.active,question_type=excluded.question_type,learning_objective=excluded.learning_objective,
 formula=excluded.formula,media_url=excluded.media_url,tags=excluded.tags;
 return jsonb_build_object('saved',true,'question_code',v_code);
end;
$$;

create or replace function private.get_academy_exam_questions(p_track text default 'all',p_level text default 'all',p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 if p_track not in ('all','math','physics') or p_level not in ('all','basic','intermediate','advanced') then raise exception 'Invalid exam filter'; end if;
 if p_limit<1 or p_limit>100 then raise exception 'Invalid question limit'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'question_code',q.question_code,'track',q.track,'level',q.level,'topic',q.topic,'prompt',q.prompt,'choices',q.choices,
 'question_type',q.question_type,'learning_objective',q.learning_objective,'formula',q.formula,'media_url',q.media_url,'tags',q.tags
 ) order by random()),'[]'::jsonb) into v_result
 from (select * from private.academy_exam_questions where active and
 (p_track='all' or track=p_track) and (p_level='all' or level=p_level) order by random() limit p_limit) q;
 return v_result;
end;
$$;

create or replace function private.begin_academy_exam(p_exam_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_exam private.academy_exam_definitions%rowtype;
 v_codes text[];v_questions jsonb;v_session uuid;v_now timestamptz:=now();
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 select * into v_exam from private.academy_exam_definitions where id=p_exam_id and published=true;
 if not found then raise exception 'Exam is unavailable'; end if;
 if exists(select 1 from private.academy_exam_sessions s where s.user_id=v_uid and s.exam_id=p_exam_id and s.submitted_at is null and s.expires_at>v_now) then raise exception 'You already have an active attempt for this exam'; end if;
 select array_agg(x.question_code) into v_codes from (select q.question_code from private.academy_exam_questions q
 where q.active and q.track=v_exam.track and q.level=v_exam.level order by random() limit v_exam.question_count) x;
 if coalesce(array_length(v_codes,1),0)<>v_exam.question_count then raise exception 'Not enough active questions to start this exam'; end if;
 insert into private.academy_exam_sessions(user_id,exam_id,question_codes,started_at,expires_at)
 values(v_uid,p_exam_id,v_codes,v_now,v_now+make_interval(mins=>v_exam.duration_minutes)) returning id into v_session;
 select jsonb_agg(jsonb_build_object('question_code',q.question_code,'track',q.track,'level',q.level,'topic',q.topic,
 'prompt',q.prompt,'choices',q.choices,'question_type',q.question_type,'learning_objective',q.learning_objective,
 'formula',q.formula,'media_url',q.media_url,'tags',q.tags) order by array_position(v_codes,q.question_code))
 into v_questions from private.academy_exam_questions q where q.question_code=any(v_codes);
 return jsonb_build_object('session_id',v_session,'exam_id',v_exam.id,'title',v_exam.title,'track',v_exam.track,
 'level',v_exam.level,'duration_minutes',v_exam.duration_minutes,'pass_score',v_exam.pass_score,
 'started_at',v_now,'expires_at',v_now+make_interval(mins=>v_exam.duration_minutes),'questions',coalesce(v_questions,'[]'::jsonb));
end;
$$;

-- Expand the existing seeded bank with a small, reviewed meteorology-oriented starter set.
insert into private.academy_exam_questions
(question_code,track,level,topic,prompt,choices,correct_index,explanation,active,question_type,learning_objective,formula,tags)
values
('MET-M-B-101','math','basic','وحدات الضغط الجوي','ما الوحدة المكافئة تقريباً للهكتوباسكال (hPa) في قياس الضغط الجوي؟',
'["المليبار (mb)","الباسكال (Pa)","الكيلوباسكال (kPa)","البار (bar)"]'::jsonb,0,
'الهكتوباسكال يساوي المليبار عددياً؛ فكلاهما يساوي 100 باسكال.','true','concept','التعرف إلى وحدات الضغط الجوي','1 hPa = 1 mb = 100 Pa',array['ضغط جوي','وحدات']),
('MET-M-B-102','math','basic','تحويل درجات الحرارة','درجة الحرارة 20 درجة مئوية. ما قيمتها بالكلفن تقريباً؟',
'["253.15 K","273.15 K","293.15 K","313.15 K"]'::jsonb,2,
'للتحويل من سلسيوس إلى كلفن نضيف 273.15 إلى القيمة المئوية.','true','calculation','التحويل بين سلسيوس وكلفن','K = °C + 273.15',array['حرارة','تحويل وحدات']),
('MET-M-I-101','math','intermediate','معدل التناقص الحراري','إذا كان معدل التناقص الحراري 6.5 °C لكل كيلومتر، فما مقدار انخفاض الحرارة تقريباً عند الصعود 2 كم مع ثبات هذا المعدل؟',
'["3.25 °C","6.5 °C","13 °C","26 °C"]'::jsonb,2,
'نضرب المعدل الرأسي 6.5 في الارتفاع 2 كم، فيكون الانخفاض 13 درجة مئوية.','true','calculation','حساب تغير الحرارة مع الارتفاع','ΔT = 6.5 × 2 = 13 °C',array['غلاف جوي','حرارة']),
('MET-M-I-102','math','intermediate','الرطوبة النسبية','إذا كان ضغط بخار الماء الفعلي 12 hPa وضغط الإشباع 20 hPa، فما الرطوبة النسبية؟',
'["40%","50%","60%","80%"]'::jsonb,2,
'الرطوبة النسبية تساوي نسبة ضغط البخار الفعلي إلى ضغط الإشباع مضروبة في 100.','true','calculation','حساب الرطوبة النسبية','RH = (12 / 20) × 100 = 60%',array['رطوبة']),
('MET-M-A-101','math','advanced','اتجاه تغير الضغط','انخفض الضغط من 1008 hPa إلى 1002 hPa خلال 3 ساعات. ما متوسط معدل تغير الضغط؟',
'["+2 hPa/h","-2 hPa/h","-6 hPa/h","-3 hPa/h"]'::jsonb,1,
'التغير يساوي 1002 ناقص 1008 أي -6 hPa، وبالقسمة على 3 ساعات يكون -2 hPa/h.','true','calculation','حساب ميل تغير الضغط زمنياً','(1002 − 1008) / 3 = −2 hPa/h',array['ضغط','اتجاه زمني']),
('MET-M-A-102','math','advanced','مركبات الرياح','كانت مركبتا الرياح المتعامدتان 6 m/s شرقاً و8 m/s شمالاً. ما مقدار سرعة الرياح المحصلة؟',
'["2 m/s","7 m/s","10 m/s","14 m/s"]'::jsonb,2,
'نحسب مقدار المحصلة باستخدام نظرية فيثاغورس: الجذر التربيعي لمجموع مربعي المركبتين يساوي 10 m/s.','true','calculation','حساب مقدار متجه الرياح من مركبتيه','V = √(6² + 8²) = 10 m/s',array['رياح','متجهات']),
('MET-P-B-101','physics','basic','كثافة الهواء','عند ثبات الضغط، ماذا يحدث لكثافة الهواء عندما ترتفع درجة حرارته؟',
'["تزداد عادةً","تنخفض عادةً","تبقى ثابتة دائماً","تصبح صفراً"]'::jsonb,1,
'وفق قانون الغاز المثالي، وعند ثبات الضغط والكتلة المولية، تتناسب الكثافة عكسياً مع درجة الحرارة المطلقة.','true','concept','ربط درجة الحرارة بكثافة الهواء','ρ = p / (R T)',array['كثافة','غاز مثالي']),
('MET-P-B-102','physics','basic','القوة والضغط','يؤثر ضغط مقداره 1000 Pa على سطح مساحته 2 m². ما مقدار القوة العمودية؟',
'["500 N","1000 N","2000 N","4000 N"]'::jsonb,2,
'القوة تساوي الضغط مضروباً في المساحة: 1000 × 2 = 2000 نيوتن.','true','calculation','حساب القوة من الضغط والمساحة','F = p × A = 1000 × 2 = 2000 N',array['ضغط','قوة']),
('MET-P-I-101','physics','intermediate','الطفو والحمل الحراري','في الظروف المتقاربة، لماذا يميل جزء الهواء الأدفأ من محيطه إلى الصعود؟',
'["لأن كثافته تكون أقل غالباً","لأن كتلته تختفي","لأن ضغطه يساوي صفراً","لأنه لا يتأثر بالجاذبية"]'::jsonb,0,
'عند تقارب الضغط، يكون الهواء الأدفأ أقل كثافة غالباً من الهواء المحيط، فتؤثر فيه قوة طفو صاعدة.','true','concept','تفسير الحمل الحراري في الغلاف الجوي','ρ ∝ 1/T عند ثبات الضغط',array['حمل حراري','استقرار جوي']),
('MET-P-I-102','physics','intermediate','قوة كوريوليس','في النصف الشمالي من الكرة الأرضية، ما اتجاه انحراف الحركة الأفقية بسبب تأثير كوريوليس؟',
'["إلى اليسار من اتجاه الحركة","إلى اليمين من اتجاه الحركة","نحو خط الاستواء دائماً","نحو القطب دائماً"]'::jsonb,1,
'في النصف الشمالي يكون الانحراف إلى يمين اتجاه الحركة، وفي النصف الجنوبي إلى اليسار.','true','concept','تحديد اتجاه تأثير كوريوليس','f = 2 Ω sin(φ)',array['كوريوليس','ديناميكا جوية']),
('MET-P-A-101','physics','advanced','الرياح الجيوستروفية','في تقريب الرياح الجيوستروفية بعيداً عن الاحتكاك، ما القوتان اللتان تتوازنان أفقياً؟',
'["قوة تدرج الضغط وقوة كوريوليس","الجاذبية والاحتكاك السطحي","قوة الطفو والإشعاع","قوة الطرد المركزي والتكاثف"]'::jsonb,0,
'ينشأ التوازن الجيوستروفي التقريبي من توازن قوة تدرج الضغط مع تأثير كوريوليس، عندما يكون الاحتكاك مهملاً تقريباً.','true','concept','فهم توازن القوى في الحركة الجوية واسعة النطاق','Pressure-gradient force ≈ Coriolis force',array['رياح جيوستروفية','ديناميكا']),
('MET-P-A-102','physics','advanced','قانون التربيع العكسي','إذا تضاعفت المسافة عن مصدر إشعاع نقطي، فما مقدار شدة الإشعاع مقارنة بالقيمة الأصلية وفق قانون التربيع العكسي؟',
'["النصف","الثلث","الربع","الضعف"]'::jsonb,2,
'تتناسب الشدة عكسياً مع مربع المسافة؛ وعند مضاعفة المسافة تصبح الشدة ربع قيمتها.','true','calculation','تطبيق قانون التربيع العكسي للإشعاع','I₂/I₁ = (r₁/r₂)² = 1/4',array['إشعاع','طاقة'])
on conflict(question_code) do nothing;

revoke all on function private.admin_exam_studio_data() from public,anon;
revoke all on function private.admin_save_exam_question(jsonb) from public,anon;
revoke all on function private.get_academy_exam_questions(text,text,integer) from public,anon;
revoke all on function private.begin_academy_exam(uuid) from public,anon;
grant execute on function private.admin_exam_studio_data() to authenticated;
grant execute on function private.admin_save_exam_question(jsonb) to authenticated;
grant execute on function private.get_academy_exam_questions(text,text,integer) to authenticated;
grant execute on function private.begin_academy_exam(uuid) to authenticated;
