-- Run manually in Supabase SQL Editor only after creating and confirming the admin account.
-- Replace the email below with the exact email of the intended, verified administrator.
-- This is a privileged operation. Never expose this SQL as a public self-service action.
begin;

do $$
declare
  target_user_id uuid;
  target_email text := 'replace-with-admin-email@example.com';
begin
  select id into target_user_id
  from auth.users
  where lower(email) = lower(target_email)
  limit 1;

  if target_user_id is null then
    raise exception 'No Supabase Auth user found for email %', target_email;
  end if;

  insert into public.academy_profiles(id, display_name, role)
  select target_user_id,
         coalesce(nullif(raw_user_meta_data ->> 'display_name',''), 'مدير الأكاديمية'),
         'admin'
  from auth.users
  where id = target_user_id
  on conflict (id) do update
    set role = 'admin',
        updated_at = now();
end
$$;

commit;

-- Verify the assignment:
-- select u.email, p.role
-- from auth.users u join public.academy_profiles p on p.id = u.id
-- where lower(u.email) = lower('replace-with-admin-email@example.com');
