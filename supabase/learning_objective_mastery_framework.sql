create table if not exists private.academy_learning_objectives(
 objective_code text primary key,
 title text not null,
 domain text not null,
 description text not null,
 created_at timestamptz not null default now()
);
create table if not exists private.academy_lesson_objectives(
 lesson_id uuid not null references public.academy_lessons(id) on delete cascade,
 objective_code text not null references private.academy_learning_objectives(objective_code) on delete cascade,
 primary key(lesson_id,objective_code)
);
alter table private.academy_learning_objectives enable row level security;
alter table private.academy_lesson_objectives enable row level security;
drop policy if exists "authenticated read learning objectives" on private.academy_learning_objectives;
create policy "authenticated read learning objectives" on private.academy_learning_objectives for select to authenticated using(true);
drop policy if exists "authenticated read lesson objective map" on private.academy_lesson_objectives;
create policy "authenticated read lesson objective map" on private.academy_lesson_objectives for select to authenticated using(true);
grant usage on schema private to authenticated;
grant select on private.academy_learning_objectives,private.academy_lesson_objectives to authenticated;
insert into private.academy_learning_objectives(objective_code,title,domain,description) values
('model_principles','النمذجة العددية — الفهم العلمي والمفاهيمي','النمذجة العددية','إتقان الفهم العلمي والمفاهيمي ضمن النمذجة العددية'),
('model_analysis','النمذجة العددية — تحليل البيانات والمنتجات','النمذجة العددية','إتقان تحليل البيانات والمنتجات ضمن النمذجة العددية'),
('model_validation','النمذجة العددية — التحقق والتواصل المهني','النمذجة العددية','إتقان التحقق والتواصل المهني ضمن النمذجة العددية'),
('satellite_principles','الأقمار الصناعية — الفهم العلمي والمفاهيمي','الأقمار الصناعية','إتقان الفهم العلمي والمفاهيمي ضمن الأقمار الصناعية'),
('satellite_analysis','الأقمار الصناعية — تحليل البيانات والمنتجات','الأقمار الصناعية','إتقان تحليل البيانات والمنتجات ضمن الأقمار الصناعية'),
('satellite_validation','الأقمار الصناعية — التحقق والتواصل المهني','الأقمار الصناعية','إتقان التحقق والتواصل المهني ضمن الأقمار الصناعية'),
('radar_principles','رادار الطقس — الفهم العلمي والمفاهيمي','رادار الطقس','إتقان الفهم العلمي والمفاهيمي ضمن رادار الطقس'),
('radar_analysis','رادار الطقس — تحليل البيانات والمنتجات','رادار الطقس','إتقان تحليل البيانات والمنتجات ضمن رادار الطقس'),
('radar_validation','رادار الطقس — التحقق والتواصل المهني','رادار الطقس','إتقان التحقق والتواصل المهني ضمن رادار الطقس'),
('upperair_principles','الديناميكا والطبقات العليا — الفهم العلمي والمفاهيمي','الديناميكا والطبقات العليا','إتقان الفهم العلمي والمفاهيمي ضمن الديناميكا والطبقات العليا'),
('upperair_analysis','الديناميكا والطبقات العليا — تحليل البيانات والمنتجات','الديناميكا والطبقات العليا','إتقان تحليل البيانات والمنتجات ضمن الديناميكا والطبقات العليا'),
('upperair_validation','الديناميكا والطبقات العليا — التحقق والتواصل المهني','الديناميكا والطبقات العليا','إتقان التحقق والتواصل المهني ضمن الديناميكا والطبقات العليا'),
('sounding_principles','Skew-T والمسبار الرأسي — الفهم العلمي والمفاهيمي','Skew-T والمسبار الرأسي','إتقان الفهم العلمي والمفاهيمي ضمن Skew-T والمسبار الرأسي'),
('sounding_analysis','Skew-T والمسبار الرأسي — تحليل البيانات والمنتجات','Skew-T والمسبار الرأسي','إتقان تحليل البيانات والمنتجات ضمن Skew-T والمسبار الرأسي'),
('sounding_validation','Skew-T والمسبار الرأسي — التحقق والتواصل المهني','Skew-T والمسبار الرأسي','إتقان التحقق والتواصل المهني ضمن Skew-T والمسبار الرأسي'),
('verification_principles','التحقق الاحتمالي — الفهم العلمي والمفاهيمي','التحقق الاحتمالي','إتقان الفهم العلمي والمفاهيمي ضمن التحقق الاحتمالي'),
('verification_analysis','التحقق الاحتمالي — تحليل البيانات والمنتجات','التحقق الاحتمالي','إتقان تحليل البيانات والمنتجات ضمن التحقق الاحتمالي'),
('verification_validation','التحقق الاحتمالي — التحقق والتواصل المهني','التحقق الاحتمالي','إتقان التحقق والتواصل المهني ضمن التحقق الاحتمالي'),
('nowcasting_principles','الآنكاستنغ — الفهم العلمي والمفاهيمي','الآنكاستنغ','إتقان الفهم العلمي والمفاهيمي ضمن الآنكاستنغ'),
('nowcasting_analysis','الآنكاستنغ — تحليل البيانات والمنتجات','الآنكاستنغ','إتقان تحليل البيانات والمنتجات ضمن الآنكاستنغ'),
('nowcasting_validation','الآنكاستنغ — التحقق والتواصل المهني','الآنكاستنغ','إتقان التحقق والتواصل المهني ضمن الآنكاستنغ'),
('ensemble_principles','التنبؤ التجميعي — الفهم العلمي والمفاهيمي','التنبؤ التجميعي','إتقان الفهم العلمي والمفاهيمي ضمن التنبؤ التجميعي'),
('ensemble_analysis','التنبؤ التجميعي — تحليل البيانات والمنتجات','التنبؤ التجميعي','إتقان تحليل البيانات والمنتجات ضمن التنبؤ التجميعي'),
('ensemble_validation','التنبؤ التجميعي — التحقق والتواصل المهني','التنبؤ التجميعي','إتقان التحقق والتواصل المهني ضمن التنبؤ التجميعي'),
('operations_principles','إدارة التنبؤ — الفهم العلمي والمفاهيمي','إدارة التنبؤ','إتقان الفهم العلمي والمفاهيمي ضمن إدارة التنبؤ'),
('operations_analysis','إدارة التنبؤ — تحليل البيانات والمنتجات','إدارة التنبؤ','إتقان تحليل البيانات والمنتجات ضمن إدارة التنبؤ'),
('operations_validation','إدارة التنبؤ — التحقق والتواصل المهني','إدارة التنبؤ','إتقان التحقق والتواصل المهني ضمن إدارة التنبؤ'),
('ai_principles','الذكاء الاصطناعي للأرصاد — الفهم العلمي والمفاهيمي','الذكاء الاصطناعي للأرصاد','إتقان الفهم العلمي والمفاهيمي ضمن الذكاء الاصطناعي للأرصاد'),
('ai_analysis','الذكاء الاصطناعي للأرصاد — تحليل البيانات والمنتجات','الذكاء الاصطناعي للأرصاد','إتقان تحليل البيانات والمنتجات ضمن الذكاء الاصطناعي للأرصاد'),
('ai_validation','الذكاء الاصطناعي للأرصاد — التحقق والتواصل المهني','الذكاء الاصطناعي للأرصاد','إتقان التحقق والتواصل المهني ضمن الذكاء الاصطناعي للأرصاد')
on conflict(objective_code) do update set title=excluded.title,domain=excluded.domain,description=excluded.description;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='model' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-1-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='satellite' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-2-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='radar' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-3-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='upperair' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-4-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='sounding' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-5-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='verification' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-6-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='nowcasting' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-7-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='ensemble' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-8-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='operations' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-9-%'
 on conflict do nothing;
insert into private.academy_lesson_objectives(lesson_id,objective_code)
 select l.id, o.objective_code
 from public.academy_lessons l
 cross join lateral jsonb_array_elements_text(l.learning_objectives) with ordinality z(objective_text,n)
 join private.academy_learning_objectives o on o.objective_code='ai' || '_' || case z.n when 1 then 'principles' when 2 then 'analysis' else 'validation' end
 where l.slug like 'applied2-10-%'
 on conflict do nothing;
create or replace function public.get_my_learning_objective_mastery()
returns table(objective_code text,objective_title text,domain text,mapped_lessons bigint,attempted_lessons bigint,completed_lessons bigint,average_score numeric,mastery_status text)
language sql
stable
security invoker
set search_path=''
as $function$
 select o.objective_code,o.title,o.domain,
        count(distinct m.lesson_id)::bigint,
        count(distinct p.lesson_id) filter(where p.score is not null)::bigint,
        count(distinct p.lesson_id) filter(where p.completed)::bigint,
        round(avg(p.score) filter(where p.score is not null),2),
        case
         when count(distinct p.lesson_id) filter(where p.score is not null)<3 then 'insufficient_evidence'
         when avg(p.score) filter(where p.score is not null)>=80 then 'mastered'
         when avg(p.score) filter(where p.score is not null)>=60 then 'developing'
         else 'needs_practice'
        end
 from private.academy_learning_objectives o
 join private.academy_lesson_objectives m on m.objective_code=o.objective_code
 left join public.academy_lesson_progress p on p.lesson_id=m.lesson_id and p.user_id=(select auth.uid())
 where (select auth.uid()) is not null
 group by o.objective_code,o.title,o.domain
 order by o.domain,o.objective_code;
$function$;
revoke all on function public.get_my_learning_objective_mastery() from public,anon;
grant execute on function public.get_my_learning_objective_mastery() to authenticated;
comment on function public.get_my_learning_objective_mastery() is 'Returns objective-level mastery for the authenticated student only. Mastery requires at least three scored lessons; no psychometric claim is inferred from sparse data.';