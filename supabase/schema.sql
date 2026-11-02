-- Meteorology Science Academy: initial Supabase schema
-- Apply only after reviewing in the intended Supabase project.
-- Uses publishable keys in browsers + RLS. Never expose a service_role/secret key.

create schema if not exists private;

create table if not exists public.academy_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'طالب الأكاديمية',
  role text not null default 'student' check (role in ('student','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_courses (
  id text primary key,
  title text not null,
  subject text not null check (subject in ('math','physics','meteorology')),
  description text not null default '',
  published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_lessons (
  id uuid primary key default gen_random_uuid(),
  course_id text not null references public.academy_courses(id) on delete cascade,
  slug text not null,
  title text not null,
  summary text not null default '',
  content jsonb not null default '{}'::jsonb,
  published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(course_id, slug)
);

create table if not exists public.academy_lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references public.academy_lessons(id) on delete cascade,
  completed boolean not null default false,
  score numeric(5,2) check (score is null or (score >= 0 and score <= 100)),
  updated_at timestamptz not null default now(),
  primary key(user_id, lesson_id)
);

create table if not exists public.academy_exam_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  track text not null check (track in ('math','physics','all')),
  level text not null check (level in ('basic','intermediate','advanced','all')),
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  correct_count integer not null check (correct_count >= 0),
  total_count integer not null check (total_count > 0 and correct_count <= total_count),
  passed boolean not null,
  answers jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists academy_lessons_course_idx on public.academy_lessons(course_id, published, sort_order);
create index if not exists academy_progress_user_idx on public.academy_lesson_progress(user_id, updated_at desc);
create index if not exists academy_attempts_user_idx on public.academy_exam_attempts(user_id, created_at desc);

-- Role checks are performed from a private SECURITY DEFINER helper. The role column
-- is not writable by ordinary users; bootstrap the first admin using trusted SQL.
create or replace function private.is_academy_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.academy_profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function private.is_academy_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_academy_admin() to authenticated;

create or replace function private.handle_new_academy_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.academy_profiles(id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name',''), 'طالب الأكاديمية')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_academy_user() from public;
drop trigger if exists on_auth_user_created_academy on auth.users;
create trigger on_auth_user_created_academy
after insert on auth.users
for each row execute function private.handle_new_academy_user();

alter table public.academy_profiles enable row level security;
alter table public.academy_courses enable row level security;
alter table public.academy_lessons enable row level security;
alter table public.academy_lesson_progress enable row level security;
alter table public.academy_exam_attempts enable row level security;

-- Profiles: each student sees their own profile. Admins can manage all profiles.
drop policy if exists "profile_read_own_or_admin" on public.academy_profiles;
create policy "profile_read_own_or_admin" on public.academy_profiles
for select to authenticated
using ((select auth.uid()) = id or (select private.is_academy_admin()));

drop policy if exists "profile_update_own_name" on public.academy_profiles;
create policy "profile_update_own_name" on public.academy_profiles
for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- Public course catalogue: published rows only. Admins manage all rows.
drop policy if exists "courses_read_published_or_admin" on public.academy_courses;
create policy "courses_read_published_or_admin" on public.academy_courses
for select to anon, authenticated
using (published = true or (select private.is_academy_admin()));

drop policy if exists "courses_admin_manage" on public.academy_courses;
create policy "courses_admin_manage" on public.academy_courses
for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));

drop policy if exists "lessons_read_published_or_admin" on public.academy_lessons;
create policy "lessons_read_published_or_admin" on public.academy_lessons
for select to anon, authenticated
using (
  (published = true and exists (
    select 1 from public.academy_courses c
    where c.id = course_id and c.published = true
  ))
  or (select private.is_academy_admin())
);

drop policy if exists "lessons_admin_manage" on public.academy_lessons;
create policy "lessons_admin_manage" on public.academy_lessons
for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));

-- Student progress is private to its owner; admins may audit it.
drop policy if exists "progress_read_own_or_admin" on public.academy_lesson_progress;
create policy "progress_read_own_or_admin" on public.academy_lesson_progress
for select to authenticated
using ((select auth.uid()) = user_id or (select private.is_academy_admin()));

drop policy if exists "progress_insert_own" on public.academy_lesson_progress;
create policy "progress_insert_own" on public.academy_lesson_progress
for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "progress_update_own" on public.academy_lesson_progress;
create policy "progress_update_own" on public.academy_lesson_progress
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "progress_admin_manage" on public.academy_lesson_progress;
create policy "progress_admin_manage" on public.academy_lesson_progress
for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));

-- Attempts are append-only for students. They can read their own history.
drop policy if exists "attempts_read_own_or_admin" on public.academy_exam_attempts;
create policy "attempts_read_own_or_admin" on public.academy_exam_attempts
for select to authenticated
using ((select auth.uid()) = user_id or (select private.is_academy_admin()));

drop policy if exists "attempts_insert_own" on public.academy_exam_attempts;
create policy "attempts_insert_own" on public.academy_exam_attempts
for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "attempts_admin_manage" on public.academy_exam_attempts;
create policy "attempts_admin_manage" on public.academy_exam_attempts
for all to authenticated
using ((select private.is_academy_admin()))
with check ((select private.is_academy_admin()));

-- New Supabase projects no longer expose new public tables automatically.
-- Grant only the operations used by this app; RLS still decides which rows are visible.
grant usage on schema public to anon, authenticated;
grant select on public.academy_courses, public.academy_lessons to anon, authenticated;
grant select on public.academy_profiles to authenticated;
grant update (display_name, updated_at) on public.academy_profiles to authenticated;
grant select, insert, update on public.academy_lesson_progress to authenticated;
grant select, insert on public.academy_exam_attempts to authenticated;
grant insert, update, delete on public.academy_courses, public.academy_lessons to authenticated;
