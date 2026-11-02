-- Storage bucket for educational lesson assets.
-- Run after schema.sql. Public read is limited to this bucket; writes require academy admin.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('academy-assets','academy-assets',true,26214400,
 array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','application/pdf',
 'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation',
 'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "academy_assets_public_read" on storage.objects;
create policy "academy_assets_public_read" on storage.objects for select to anon,authenticated using(bucket_id='academy-assets');
drop policy if exists "academy_assets_admin_insert" on storage.objects;
create policy "academy_assets_admin_insert" on storage.objects for insert to authenticated with check(bucket_id='academy-assets' and (select private.is_academy_admin()));
drop policy if exists "academy_assets_admin_update" on storage.objects;
create policy "academy_assets_admin_update" on storage.objects for update to authenticated using(bucket_id='academy-assets' and (select private.is_academy_admin())) with check(bucket_id='academy-assets' and (select private.is_academy_admin()));
drop policy if exists "academy_assets_admin_delete" on storage.objects;
create policy "academy_assets_admin_delete" on storage.objects for delete to authenticated using(bucket_id='academy-assets' and (select private.is_academy_admin()));
