-- Ensure every applied-sectoral lesson example renders a useful solution in lesson.html.
update public.academy_lessons l
set content = jsonb_set(
  l.content,
  '{blocks}',
  (
    select jsonb_agg(
      case when b.value->>'type' = 'example'
        then b.value || jsonb_build_object(
          'solution',
          'يبدأ التفسير بتحديد المتغيرات الأساسية في الحالة، ثم ربطها بالمبدأ العلمي للدرس «' || l.title || '». بعد ذلك تُقارن المؤشرات مكانياً وزمنياً، ويفصل ما تدعمه البيانات عن الافتراضات. يجب ذكر القيود ومصدر عدم اليقين قبل صياغة الاستنتاج، وعدم تحويل المثال الافتراضي إلى قرار تشغيلي.'
        )
        else b.value
      end
      order by b.ordinality
    )
    from jsonb_array_elements(l.content->'blocks') with ordinality as b(value, ordinality)
  ),
  true
),
updated_at = now()
where l.slug like 'applied-%'
  and l.published = false
  and jsonb_typeof(l.content->'blocks') = 'array'
  and exists (
    select 1 from jsonb_array_elements(l.content->'blocks') e(value)
    where e.value->>'type' = 'example'
      and coalesce(e.value->>'solution','') = ''
  );
