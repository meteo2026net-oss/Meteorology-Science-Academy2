-- Visual data interpretation and synoptic-map questions with original repository-hosted SVGs.
insert into private.academy_exam_questions
(question_code,track,level,topic,prompt,choices,correct_index,explanation,active,question_type,learning_objective,formula,media_url,tags)
values
('MET-M-B-107','math','basic','قراءة سجل الضغط','بالنظر إلى مخطط الضغط المرفق، في أي وقت كانت قراءة الضغط هي الأقل؟',
'["00 UTC","01 UTC","02 UTC","03 UTC"]'::jsonb,3,
'تنخفض القراءات تدريجياً من 1016 إلى 1004 hPa؛ وأقل قيمة تظهر عند 03 UTC.','true','data_interpretation','استخراج القيمة الدنيا من سلسلة زمنية للرصد','—','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/pressure_trend_case_a.svg',array['ضغط جوي','سلسلة زمنية']),
('MET-M-I-107','math','intermediate','تحليل الحرارة ونقطة الندى','باستخدام جدول المحطات، أي محطة أقرب إلى حالة الإشباع؟',
'["المحطة A","المحطة B","المحطة C","المحطات متساوية"]'::jsonb,1,
'الفارق بين الحرارة ونقطة الندى هو 8 درجات في A، ودرجة واحدة في B، و8 درجات في C. أصغر فارق يعني هواء أقرب إلى الإشباع.','true','data_interpretation','تفسير فرق الحرارة ونقطة الندى بين محطات الرصد','T − Td', 'https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/station_temp_dewpoint_case_a.svg',array['رطوبة','نقطة الندى','محطات']),
('MET-M-I-108','math','intermediate','اتجاه الضغط الزمني','وفق المخطط، ما متوسط معدل تغير الضغط بين 00 و03 UTC؟',
'["+4 hPa/h","−4 hPa/h","−12 hPa/h","−3 hPa/h"]'::jsonb,1,
'تغير الضغط 1004−1016 = −12 hPa خلال 3 ساعات؛ المعدل المتوسط −4 hPa/h.','true','data_interpretation','حساب ميل تغير الضغط من سلسلة زمنية','(1004−1016)/3 = −4 hPa/h','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/pressure_trend_case_a.svg',array['ضغط','اتجاه زمني']),
('MET-P-I-107','physics','intermediate','تحليل تباعد خطوط الضغط','في المخطط السينوبتيكي، أي المنطقتين يظهر فيها تدرج الضغط الأفقي الأقوى تقريباً؟',
'["حول المنخفض L","حول المرتفع H","التدرج متساوٍ في المنطقتين","لا يمكن الاستدلال من تباعد الخطوط"]'::jsonb,0,
'تقارب خطوط تساوي الضغط يدل على تدرج ضغط أفقي أقوى؛ وتظهر الخطوط أكثر تقارباً حول المنخفض L في هذا الرسم التخطيطي.','true','map_analysis','ربط تباعد خطوط تساوي الضغط بقوة التدرج الأفقي','|∇p| increases as isobar spacing decreases','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/synoptic_isobars_case_a.svg',array['خرائط سينوبتيكية','ايزوبار']),
('MET-P-A-107','physics','advanced','قراءة قيم مراكز الضغط','ما الفرق بين الضغط عند مركز المنخفض L ومركز المرتفع H في الخريطة؟',
'["18 hPa","24 hPa","28 hPa","32 hPa"]'::jsonb,2,
'قيمة المرتفع 1024 hPa وقيمة المنخفض 996 hPa؛ الفرق 1024−996 = 28 hPa.','true','map_analysis','استخراج ومقارنة قيم الضغط من خريطة سينوبتيكية','1024 − 996 = 28 hPa','https://raw.githubusercontent.com/meteo2026net-oss/Meteorology-Science-Academy2/main/assets/quiz/synoptic_isobars_case_a.svg',array['خرائط ضغط','منخفض','مرتفع'])
on conflict(question_code) do nothing;
