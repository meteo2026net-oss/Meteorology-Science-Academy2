-- Prepare six draft lesson quizzes against matching existing lesson content.
-- All remain unpublished because the corresponding courses/lessons are currently drafts.
insert into private.academy_lesson_quiz_assignments
(lesson_id,question_codes,duration_minutes,pass_score,published,updated_at)
values
('68a663e4-1fbd-4b89-9eac-bbdc7b4bace7',array['MET-M-B-101','MET-P-B-103','MET-M-I-103','MET-P-I-107','MET-P-A-107'],10,70,false,now()),
('2ed49775-c841-427c-8603-a7070ef33916',array['MET-M-B-103','MET-M-I-105','MET-P-I-102','MET-P-A-101','MET-P-B-101'],10,70,false,now()),
('05fea94e-6a1f-47ab-959f-e70e4064485b',array['MET-M-I-102','MET-M-I-104','MET-M-I-107','MET-P-B-104','MET-P-B-105'],10,70,false,now()),
('92894761-8a51-4e20-b87e-93784fd6e752',array['MET-P-B-101','MET-P-I-103','MET-P-I-104','MET-M-I-103','MET-P-I-105'],12,70,false,now()),
('d973f7e5-df36-43ca-a5a2-0e2042c579ff',array['MET-M-I-103','MET-M-I-108','MET-P-I-107','MET-P-A-107','MET-P-A-101'],12,70,false,now()),
('b8fd2f55-7446-4633-8eb7-e47c1cb49323',array['MET-M-B-104','MET-P-B-104','MET-P-B-106','MET-P-I-105','MET-P-I-103'],12,70,false,now())
on conflict(lesson_id) do update set question_codes=excluded.question_codes,duration_minutes=excluded.duration_minutes,
 pass_score=excluded.pass_score,published=false,updated_at=now();
