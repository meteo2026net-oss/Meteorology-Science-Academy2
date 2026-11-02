create table if not exists public.academy_lab_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lab_code text not null check (lab_code in ('pressure_altitude','humidity_dewpoint','wind_vector')),
  inputs jsonb not null default '{}'::jsonb,
  outputs jsonb not null default '{}'::jsonb,
  reflection text not null check (char_length(btrim(reflection)) between 20 and 1000),
  created_at timestamptz not null default now(),
  constraint academy_lab_attempts_inputs_object check (jsonb_typeof(inputs) = 'object'),
  constraint academy_lab_attempts_outputs_object check (jsonb_typeof(outputs) = 'object'),
  constraint academy_lab_attempts_payload_size check (octet_length(inputs::text) <= 4000 and octet_length(outputs::text) <= 4000)
);
alter table public.academy_lab_attempts enable row level security;
revoke all on table public.academy_lab_attempts from anon, authenticated;
grant select, insert on table public.academy_lab_attempts to authenticated;
drop policy if exists "students read own lab attempts" on public.academy_lab_attempts;
drop policy if exists "admins read all lab attempts" on public.academy_lab_attempts;
drop policy if exists "students and admins read lab attempts" on public.academy_lab_attempts;
create policy "students and admins read lab attempts" on public.academy_lab_attempts
for select to authenticated
using ((select auth.uid()) = user_id or private.is_academy_admin());
create index if not exists academy_lab_attempts_user_created_idx
on public.academy_lab_attempts(user_id, created_at desc);
comment on table public.academy_lab_attempts is 'Student-submitted records from educational meteorology simulations; students can insert and read only their own records, admins can read all.';