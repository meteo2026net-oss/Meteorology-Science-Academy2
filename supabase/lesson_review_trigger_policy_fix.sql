drop policy if exists academy_lesson_reviews_admin_update on private.academy_lesson_reviews;
create policy academy_lesson_reviews_admin_update on private.academy_lesson_reviews
for update to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));