-- Central, server-graded assessment and private completion certificates.
-- Apply after supabase/schema.sql and the hierarchy/content scripts.
-- Correct answers remain in the private schema and are never sent to the browser.

create table if not exists private.academy_exam_questions (
  id uuid primary key default gen_random_uuid(),
  question_code text not null unique,
  track text not null check (track in ('math','physics')),
  level text not null check (level in ('basic','intermediate','advanced')),
  topic text not null,
  prompt text not null,
  choices jsonb not null check (jsonb_typeof(choices) = 'array' and jsonb_array_length(choices) >= 2),
  correct_index integer not null check (correct_index >= 0),
  explanation text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint academy_exam_question_answer_idx check (correct_index < jsonb_array_length(choices))
);

alter table private.academy_exam_questions enable row level security;
revoke all on private.academy_exam_questions from public, anon, authenticated;
create index if not exists academy_exam_questions_track_level_idx
  on private.academy_exam_questions(track, level) where active;

insert into private.academy_exam_questions
(question_code,track,level,topic,prompt,choices,correct_index,explanation)
values
('M-B-001','math','basic','الوحدات','حوّل 2.5 كيلومتر إلى متر.','["25 m","250 m","2500 m","25000 m"]',2,'كل كيلومتر يساوي 1000 متر؛ 2.5 × 1000 = 2500 متر.'),
('M-B-002','math','basic','الجبر','إذا كانت T = 18 + 3x، فما قيمة T عندما x = 4؟','["21","24","30","36"]',2,'نعوض x=4: T=18+3×4=30.'),
('M-B-003','math','basic','الهندسة','ما مساحة مستطيل طوله 8 cm وعرضه 3 cm؟','["11 cm²","22 cm²","24 cm²","48 cm²"]',2,'المساحة = الطول × العرض = 8×3 = 24 cm².'),
('M-B-004','math','basic','الإحصاء','ما متوسط القيم 10 و12 و14؟','["10","11","12","13"]',2,'المتوسط = مجموع القيم ÷ عددها = 36÷3 = 12.'),
('M-I-001','math','intermediate','الدوال','إذا كانت f(x)=2x+1، فما f(5)؟','["6","10","11","12"]',2,'نعوض x=5: 2×5+1=11.'),
('M-I-002','math','intermediate','المتجهات','متجهان متعامدان مركبتاهما 3 و4. ما مقدار المحصلة؟','["1","5","7","12"]',1,'باستخدام فيثاغورس: √(3²+4²)=5.'),
('M-I-003','math','intermediate','الاحتمالات','عند رمي نرد متوازن، ما احتمال ظهور عدد زوجي؟','["1/6","1/3","1/2","2/3"]',2,'الأعداد الزوجية 2 و4 و6؛ ثلاث نتائج من أصل ست، أي 1/2.'),
('M-A-001','math','advanced','التكامل','ما التكامل غير المحدد للدالة 2x بالنسبة إلى x؟','["2x²+C","x²+C","x+C","2+C"]',1,'لأن مشتقة x² تساوي 2x، فالتكامل x²+C.'),
('M-A-002','math','advanced','الطرق العددية','في طريقة أويلر، نقرّب y عند x+h باستخدام:','["y(x)+h f(x,y)","y(x)−h²","f(x)/h","y(x)×h"]',0,'صيغة أويلر الصريحة: y(n+1)=y(n)+h f(x(n),y(n)).'),
('M-A-003','math','advanced','السلاسل الزمنية','إذا كانت القراءات كل 3 ساعات، فما عدد الفترات في اليوم؟','["3","6","8","12"]',2,'24 ساعة ÷ 3 ساعات = 8 فترات يومياً.'),
('P-B-001','physics','basic','القياس','ما وحدة الضغط في النظام الدولي؟','["نيوتن","باسكال","جول","واط"]',1,'وحدة الضغط هي الباسكال، وتساوي نيوتن لكل متر مربع.'),
('P-B-002','physics','basic','الكثافة','كتلة جسم 200 g وحجمه 100 cm³. ما كثافته؟','["0.5 g/cm³","2 g/cm³","20 g/cm³","200 g/cm³"]',1,'الكثافة = الكتلة ÷ الحجم = 200÷100 = 2 g/cm³.'),
('P-B-003','physics','basic','الحركة','قطعت مركبة أرصاد 120 km خلال ساعتين. ما سرعتها المتوسطة؟','["30 km/h","60 km/h","120 km/h","240 km/h"]',1,'السرعة المتوسطة = المسافة ÷ الزمن = 120÷2 = 60 km/h.'),
('P-B-004','physics','basic','الحرارة','أي عبارة تميز الحرارة عن درجة الحرارة؟','["الحرارة طاقة تنتقل بسبب فرق درجة الحرارة","هما الكمية نفسها دائماً","درجة الحرارة تقاس بالجول","الحرارة لا تنتقل"]',0,'الحرارة طاقة تنتقل بسبب فرق درجة الحرارة، أما درجة الحرارة فمقياس للحالة الحرارية.'),
('P-I-001','physics','intermediate','قوانين نيوتن','إذا تضاعفت القوة المحصلة على كتلة ثابتة، فإن التسارع:','["ينخفض للنصف","يتضاعف","لا يتغير","يصبح صفراً"]',1,'من قانون نيوتن الثاني a=F/m؛ عند ثبات الكتلة يتناسب التسارع طردياً مع القوة.'),
('P-I-002','physics','intermediate','الغازات المثالية','في العلاقة PV=nRT، ماذا تمثل T؟','["الزمن بالثواني","درجة الحرارة المطلقة بالكلفن","درجة الحرارة المئوية فقط","الكتلة"]',1,'في قانون الغاز المثالي نستخدم درجة الحرارة المطلقة بالكلفن.'),
('P-I-003','physics','intermediate','الرطوبة','إذا كان ضغط بخار الماء الفعلي 10 hPa وضغط الإشباع 20 hPa، فالرطوبة النسبية:','["25%","50%","75%","100%"]',1,'RH = (ضغط البخار الفعلي ÷ ضغط الإشباع)×100 = 50%.'),
('P-A-001','physics','advanced','الديناميكا الحرارية','ما المقصود بعملية أديباتية مثالية؟','["تبادل حرارة مستمر","لا يحدث فيها انتقال حرارة مع الوسط","درجة الحرارة ثابتة بالضرورة","الضغط ثابت بالضرورة"]',1,'في العملية الأديباتية يكون انتقال الحرارة Q صفراً، ولا يعني ذلك بالضرورة ثبات درجة الحرارة.'),
('P-A-002','physics','advanced','انتقال الحرارة','أي آلية لنقل الطاقة لا تحتاج إلى وسط مادي؟','["التوصيل","الحمل","الإشعاع","الانتشار الجزيئي"]',2,'الإشعاع الكهرومغناطيسي يمكنه الانتقال في الفراغ.'),
('P-A-003','physics','advanced','ديناميكا الغلاف الجوي','ما القوة الظاهرية المرتبطة بدوران الأرض والتي تؤثر في حركة الهواء؟','["قوة كوريوليس","قوة الطفو وحدها","قوة الاحتكاك الجزيئي فقط","قوة التوتر السطحي"]',0,'تأثير كوريوليس ينحرف بالحركة إلى اليمين في نصف الكرة الشمالي وإلى اليسار في الجنوبي.')
on conflict (question_code) do update set
 track=excluded.track,level=excluded.level,topic=excluded.topic,prompt=excluded.prompt,
 choices=excluded.choices,correct_index=excluded.correct_index,explanation=excluded.explanation,active=true;

create table if not exists public.academy_certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exam_attempt_id uuid not null unique references public.academy_exam_attempts(id) on delete restrict,
  certificate_code text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,16)),
  student_name text not null,
  track text not null check (track in ('math','physics')),
  score numeric(5,2) not null check (score >= 70 and score <= 100),
  issued_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index if not exists academy_certificates_user_idx
  on public.academy_certificates(user_id,issued_at desc);
alter table public.academy_certificates enable row level security;
drop policy if exists "certificates_read_own_or_admin" on public.academy_certificates;
create policy "certificates_read_own_or_admin"
on public.academy_certificates for select to authenticated
using ((select auth.uid()) = user_id or (select private.is_academy_admin()));
drop policy if exists "certificates_admin_manage" on public.academy_certificates;
create policy "certificates_admin_manage"
on public.academy_certificates for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));
grant select on public.academy_certificates to authenticated;
revoke insert, update, delete on public.academy_certificates from anon, authenticated;

create or replace function public.get_academy_exam_questions(
  p_track text default 'all',
  p_level text default 'all',
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_result jsonb;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if p_track not in ('all','math','physics') or p_level not in ('all','basic','intermediate','advanced') then
    raise exception 'Invalid exam filter';
  end if;
  if p_limit < 1 or p_limit > 100 then raise exception 'Invalid question limit'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'question_code',q.question_code,'track',q.track,'level',q.level,
    'topic',q.topic,'prompt',q.prompt,'choices',q.choices
  ) order by random()),'[]'::jsonb)
  into v_result
  from (
    select * from private.academy_exam_questions
    where active and (p_track='all' or track=p_track)
      and (p_level='all' or level=p_level)
    order by random() limit p_limit
  ) q;
  return v_result;
end;
$$;

create or replace function public.submit_academy_exam(
  p_track text,
  p_level text,
  p_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_item jsonb;
  v_question private.academy_exam_questions%rowtype;
  v_selected integer;
  v_total integer := 0;
  v_correct integer := 0;
  v_score numeric(5,2);
  v_passed boolean;
  v_attempt_id uuid;
  v_review jsonb := '[]'::jsonb;
  v_cert public.academy_certificates%rowtype;
  v_name text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_track not in ('all','math','physics') or p_level not in ('all','basic','intermediate','advanced') then
    raise exception 'Invalid exam track or level';
  end if;
  if jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) < 1 or jsonb_array_length(p_answers) > 20 then
    raise exception 'Submit between 1 and 20 answers';
  end if;
  if (select count(distinct value->>'question_code') from jsonb_array_elements(p_answers)) <> jsonb_array_length(p_answers) then
    raise exception 'Duplicate question';
  end if;
  for v_item in select value from jsonb_array_elements(p_answers) loop
    select * into v_question
    from private.academy_exam_questions
    where question_code = v_item->>'question_code'
      and active
      and (p_track='all' or track=p_track)
      and (p_level='all' or level=p_level);
    if not found then raise exception 'Unknown question or question outside this exam'; end if;
    v_selected := case when coalesce(v_item->>'selected_index','') ~ '^[0-9]+$' then (v_item->>'selected_index')::integer else -1 end;
    if v_selected < -1 or v_selected >= jsonb_array_length(v_question.choices) then raise exception 'Invalid answer choice'; end if;
    v_total := v_total + 1;
    if v_selected = v_question.correct_index then v_correct := v_correct + 1; end if;
    v_review := v_review || jsonb_build_array(jsonb_build_object(
      'question_code',v_question.question_code,'topic',v_question.topic,'prompt',v_question.prompt,
      'choices',v_question.choices,'selected_index',case when v_selected=-1 then null else v_selected end,
      'correct_index',v_question.correct_index,'explanation',v_question.explanation,
      'is_correct',v_selected=v_question.correct_index
    ));
  end loop;
  v_score := round((v_correct::numeric / v_total::numeric)*100,2);
  v_passed := v_score >= 70;
  insert into public.academy_exam_attempts
    (user_id,track,level,score,correct_count,total_count,passed,answers)
  values (v_uid,p_track,p_level,v_score,v_correct,v_total,v_passed,v_review)
  returning id into v_attempt_id;

  if v_passed and p_track in ('math','physics') then
    select coalesce(display_name,'طالب الأكاديمية') into v_name
    from public.academy_profiles where id=v_uid;
    insert into public.academy_certificates(user_id,exam_attempt_id,student_name,track,score)
    values (v_uid,v_attempt_id,coalesce(nullif(v_name,''),'طالب الأكاديمية'),p_track,v_score)
    returning * into v_cert;
  end if;

  return jsonb_build_object(
    'attempt_id',v_attempt_id,'score',v_score,'correct_count',v_correct,
    'total_count',v_total,'passed',v_passed,'review',v_review,
    'certificate',case when v_cert.id is null then null else jsonb_build_object(
      'certificate_code',v_cert.certificate_code,'student_name',v_cert.student_name,
      'track',v_cert.track,'score',v_cert.score,'issued_at',v_cert.issued_at
    ) end
  );
end;
$$;

revoke all on function public.get_academy_exam_questions(text,text,integer) from public, anon;
revoke all on function public.submit_academy_exam(text,text,jsonb) from public, anon;
grant execute on function public.get_academy_exam_questions(text,text,integer) to authenticated;
grant execute on function public.submit_academy_exam(text,text,jsonb) to authenticated;
