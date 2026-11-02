-- Content-only policy/index cleanup after the initial academy schema.
-- Admin SELECT is already included in each published-or-admin read policy.
-- Separate write policies avoid overlapping permissive SELECT policies.

drop policy if exists "courses_admin_manage" on public.academy_courses;
create policy "courses_admin_insert" on public.academy_courses
for insert to authenticated with check ((select private.is_academy_admin()));
create policy "courses_admin_update" on public.academy_courses
for update to authenticated using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));
create policy "courses_admin_delete" on public.academy_courses
for delete to authenticated using ((select private.is_academy_admin()));

drop policy if exists "lessons_admin_manage" on public.academy_lessons;
create policy "lessons_admin_insert" on public.academy_lessons
for insert to authenticated with check ((select private.is_academy_admin()));
create policy "lessons_admin_update" on public.academy_lessons
for update to authenticated using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));
create policy "lessons_admin_delete" on public.academy_lessons
for delete to authenticated using ((select private.is_academy_admin()));

drop policy if exists "chapters_admin_manage" on public.academy_chapters;
create policy "chapters_admin_insert" on public.academy_chapters
for insert to authenticated with check ((select private.is_academy_admin()));
create policy "chapters_admin_update" on public.academy_chapters
for update to authenticated using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));
create policy "chapters_admin_delete" on public.academy_chapters
for delete to authenticated using ((select private.is_academy_admin()));

drop policy if exists "units_admin_manage" on public.academy_units;
create policy "units_admin_insert" on public.academy_units
for insert to authenticated with check ((select private.is_academy_admin()));
create policy "units_admin_update" on public.academy_units
for update to authenticated using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));
create policy "units_admin_delete" on public.academy_units
for delete to authenticated using ((select private.is_academy_admin()));

-- Cover the lesson hierarchy and progress foreign keys.
drop index if exists public.academy_lessons_published_order_idx;
create index if not exists academy_lesson_progress_lesson_id_idx
  on public.academy_lesson_progress(lesson_id);
create index if not exists academy_lessons_chapter_course_fk_idx
  on public.academy_lessons(chapter_id,course_id);
create index if not exists academy_lessons_unit_chapter_fk_idx
  on public.academy_lessons(unit_id,chapter_id);
