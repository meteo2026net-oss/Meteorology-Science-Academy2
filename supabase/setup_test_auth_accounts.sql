-- Trusted operator-only setup for three real Supabase Auth test accounts.
-- 1) Create the three users in Supabase Dashboard > Authentication > Users.
-- 2) Confirm their email addresses.
-- 3) Replace the three email placeholders below, then run this script in SQL Editor.
-- Never put passwords, service_role keys, or secret keys in this file or the browser.
-- This script does NOT create auth.users records. Supabase Auth must create them first.

begin;

do $$
declare
  v_admin_email text := 'REPLACE-ADMIN-EMAIL@example.com';
  v_student_one_email text := 'REPLACE-STUDENT-ONE-EMAIL@example.com';
  v_student_two_email text := 'REPLACE-STUDENT-TWO-EMAIL@example.com';
  v_admin_id uuid;
  v_student_one_id uuid;
  v_student_two_id uuid;
begin
  if v_admin_email like 'REPLACE-%'
     or v_student_one_email like 'REPLACE-%'
     or v_student_two_email like 'REPLACE-%' then
    raise exception 'Replace all three email placeholders before running this script';
  end if;

  if lower(v_admin_email) in (lower(v_student_one_email), lower(v_student_two_email))
     or lower(v_student_one_email)=lower(v_student_two_email) then
    raise exception 'The three test accounts must use distinct email addresses';
  end if;

  select id into v_admin_id from auth.users
   where lower(email)=lower(v_admin_email) and email_confirmed_at is not null;
  select id into v_student_one_id from auth.users
   where lower(email)=lower(v_student_one_email) and email_confirmed_at is not null;
  select id into v_student_two_id from auth.users
   where lower(email)=lower(v_student_two_email) and email_confirmed_at is not null;

  if v_admin_id is null or v_student_one_id is null or v_student_two_id is null then
    raise exception 'All three Auth users must exist and have confirmed email addresses';
  end if;

  if v_admin_id=v_student_one_id or v_admin_id=v_student_two_id or v_student_one_id=v_student_two_id then
    raise exception 'Account IDs must be distinct';
  end if;

  if exists (
    select 1 from public.academy_profiles
    where id in (v_student_one_id,v_student_two_id) and role='admin'
  ) then
    raise exception 'A selected student account already has admin role; review identities before proceeding';
  end if;

  insert into public.academy_profiles(id,display_name,role)
  values
    (v_admin_id,'مدير تجريبي','admin'),
    (v_student_one_id,'طالب تجريبي 1','student'),
    (v_student_two_id,'طالب تجريبي 2','student')
  on conflict(id) do update set
    display_name=excluded.display_name,
    role=excluded.role,
    updated_at=now();

  if not exists(select 1 from public.academy_profiles where id=v_admin_id and role='admin')
     or (select count(*) from public.academy_profiles where id in (v_student_one_id,v_student_two_id) and role='student')<>2 then
    raise exception 'Post-assignment verification failed';
  end if;
end
$$;

commit;

-- Verify roles without displaying credentials:
-- select u.email,p.display_name,p.role,u.email_confirmed_at is not null as email_confirmed
-- from auth.users u join public.academy_profiles p on p.id=u.id
-- where lower(u.email) in (
--   lower('REPLACE-ADMIN-EMAIL@example.com'),
--   lower('REPLACE-STUDENT-ONE-EMAIL@example.com'),
--   lower('REPLACE-STUDENT-TWO-EMAIL@example.com')
-- )
-- order by p.role,p.display_name;
