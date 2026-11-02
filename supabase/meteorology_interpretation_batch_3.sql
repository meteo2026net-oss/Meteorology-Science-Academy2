-- Additional sounding, frontal-passage and precipitation interpretation questions.
insert into private.academy_exam_questions
(question_code,track,level,topic,prompt,choices,correct_index,explanation,active,question_type,learning_objective,formula,media_url,tags)
values
('MET-M-I-109','math','intermediate','حساب المعدل الحراري البيئي','يعرض المقطع الرأسي المرفق انخفاض الحرارة من 30°C عند السطح إلى −2°C عند ارتفاع 4 km. ما معدل التناقص الحراري البيئي المتوسط؟',
'["4 °C/km","6 °C/km","8 °C/km","9.8 °C/km"]'::jsonb,2,
'الانخفاض الكلي 32°C خلال 4 km؛ المعدل المتوسط 32/4 = 8°C/km.','true','data_interpretation','استخراج المعدل الحراري البيئي من المسبار الرأسي','Γenv = (30 − (−2)) / 4 = 8 °C/km','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/vertical_temperature_profile_case_a.svg',array['مسبار جوي','استقرار']),
('MET-M-I-110','math','intermediate','توزيع الهطول زمنياً','وفق مخطط الهطول، أي فترة زمنية سجلت أكبر تراكم متوقع؟',
'["00–06 UTC","06–12 UTC","12–18 UTC","جميع الفترات متساوية"]'::jsonb,1,
'القيم هي 4 و18 و6 mm على التوالي؛ أكبر تراكم هو 18 mm خلال الفترة 06–12 UTC.','true','data_interpretation','مقارنة التراكم المطري بين نوافذ زمنية','Ptotal per window','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/rainfall_period_case_a.svg',array['هطول','توزيع زمني']),
('MET-M-A-105','math','advanced','مجموع الهطول التراكمي','ما مجموع الهطول في الفترات الثلاث المعروضة في المخطط؟',
'["22 mm","24 mm","28 mm","30 mm"]'::jsonb,2,
'نجمع التراكمات: 4 + 18 + 6 = 28 mm. يجب الحفاظ على نافذة التجميع عند مقارنة منتجات النماذج.','true','data_interpretation','جمع كميات الهطول عبر نوافذ متتابعة','4 + 18 + 6 = 28 mm','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/rainfall_period_case_a.svg',array['هطول','تراكم']),
('MET-M-B-108','math','basic','التعرف إلى مرور جبهة باردة','في تسلسل الرصد المرفق، تنخفض الحرارة ونقطة الندى بعد وقت المرور، ويتغير اتجاه الرياح من جنوبية غربية إلى شمالية غربية. ما التفسير الأرجح؟',
'["مرور جبهة باردة","مرور جبهة دافئة","ثبات الكتلة الهوائية","تكوّن نسيم بحري يومي فقط"]'::jsonb,0,
'هبوط الحرارة ونقطة الندى مع تغير اتجاه الرياح بعد المرور يتوافق غالباً مع عبور جبهة باردة، مع ضرورة التحقق من الخرائط والرصد المكاني.','true','data_interpretation','تمييز إشارة مرور الجبهة من تغيرات عناصر الرصد','—','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/front_passage_case_a.svg',array['جبهات','محطات رصد']),
('MET-P-I-109','physics','intermediate','تصنيف الاستقرار من المسبار','يُظهر المسبار معدل تناقص بيئي يقارب 8°C/km. وبالمقارنة مع المعدل الجاف (نحو 9.8°C/km) والمشبع (نحو 6°C/km)، كيف يصنف هذا الملف بصورة مثالية؟',
'["مستقر مطلقاً","غير مستقر مطلقاً","عدم استقرار شرطي","انقلاب حراري"]'::jsonb,2,
'عندما يقع المعدل البيئي بين المعدلين المشبع والجاف يكون عدم الاستقرار شرطياً؛ يعتمد سلوك الحزمة على ما إذا كانت غير مشبعة أم مشبعة.','true','data_interpretation','استنتاج نوع الاستقرار من مقارنة المعدلات الحرارية','Γmoist < Γenv < Γdry','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/vertical_temperature_profile_case_a.svg',array['استقرار جوي','مسبار']),
('MET-P-A-108','physics','advanced','الفاصل بين خطوط تساوي الضغط','تزداد قيم خطوط تساوي الضغط في الرسم التخطيطي حول المنخفض بفواصل منتظمة. إذا كانت القيم المتتابعة 1000 و1004 و1008 hPa، فما الفاصل بين خطين متجاورين؟',
'["2 hPa","3 hPa","4 hPa","8 hPa"]'::jsonb,2,
'الفرق بين كل قيمتين متتاليتين هو 4 hPa؛ هذا هو الفاصل الكنتوري للخطوط المعروضة.','true','map_analysis','قراءة الفاصل الكنتوري في خرائط الضغط','1004 − 1000 = 4 hPa','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/synoptic_isobars_case_a.svg',array['خرائط سينوبتيكية','خطوط تساوي الضغط'])
on conflict(question_code) do nothing;
