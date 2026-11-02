-- Prevent client-forged exam attempts. Only submit_academy_exam may insert
-- after validating question IDs, answer choices, score and pass status.
revoke insert, update, delete on public.academy_exam_attempts from anon, authenticated;
grant select on public.academy_exam_attempts to authenticated;
