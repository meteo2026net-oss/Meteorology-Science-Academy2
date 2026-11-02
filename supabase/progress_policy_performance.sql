-- Index FK columns used by session and quiz metadata lookups.
create index if not exists academy_exam_sessions_exam_id_idx on private.academy_exam_sessions(exam_id);
create index if not exists academy_lesson_quiz_assignments_updated_by_idx on private.academy_lesson_quiz_assignments(updated_by);
create index if not exists academy_lesson_quiz_sessions_attempt_id_idx on private.academy_lesson_quiz_sessions(attempt_id);
create index if not exists academy_lesson_quiz_sessions_lesson_id_idx on private.academy_lesson_quiz_sessions(lesson_id);

-- Consolidate overlapping progress policies while preserving student ownership and admin management.
drop policy if exists progress_admin_manage on public.academy_lesson_progress;
drop policy if exists progress_insert_own on public.academy_lesson_progress;
drop policy if exists progress_update_own on public.academy_lesson_progress;
drop policy if exists progress_admin_delete on public.academy_lesson_progress;

create policy progress_insert_own_or_admin on public.academy_lesson_progress
 for insert to authenticated
 with check ((select auth.uid())=user_id or (select private.is_academy_admin()));

create policy progress_update_own_or_admin on public.academy_lesson_progress
 for update to authenticated
 using ((select auth.uid())=user_id or (select private.is_academy_admin()))
 with check ((select auth.uid())=user_id or (select private.is_academy_admin()));

create policy progress_admin_delete on public.academy_lesson_progress
 for delete to authenticated
 using ((select private.is_academy_admin()));
