-- Prevent client-forged exam attempts. Only submit_academy_exam may insert
-- after validating question IDs, answer choices, score and pass status.
revoke insert, update, delete on public.academy_exam_attempts from anon, authenticated;
grant select on public.academy_exam_attempts to authenticated;

-- Keep privileged question-bank and grading logic outside exposed API schema.
-- Public RPC entry points are SECURITY INVOKER wrappers; private functions perform
-- the narrowly-scoped privileged work and still validate auth.uid() themselves.

alter function public.get_academy_exam_questions(text,text,integer) set schema private;
alter function public.submit_academy_exam(text,text,jsonb) set schema private;

revoke all on function private.get_academy_exam_questions(text,text,integer) from public, anon;
revoke all on function private.submit_academy_exam(text,text,jsonb) from public, anon;
grant execute on function private.get_academy_exam_questions(text,text,integer) to authenticated;
grant execute on function private.submit_academy_exam(text,text,jsonb) to authenticated;

create or replace function public.get_academy_exam_questions(
  p_track text default 'all', p_level text default 'all', p_limit integer default 100
)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.get_academy_exam_questions(p_track,p_level,p_limit); $$;

create or replace function public.submit_academy_exam(
  p_track text, p_level text, p_answers jsonb
)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.submit_academy_exam(p_track,p_level,p_answers); $$;

revoke all on function public.get_academy_exam_questions(text,text,integer) from public, anon;
revoke all on function public.submit_academy_exam(text,text,jsonb) from public, anon;
grant execute on function public.get_academy_exam_questions(text,text,integer) to authenticated;
grant execute on function public.submit_academy_exam(text,text,jsonb) to authenticated;

-- Attempts are immutable to browser clients. Only the grading function inserts.
drop policy if exists "attempts_insert_own" on public.academy_exam_attempts;
drop policy if exists "attempts_admin_manage" on public.academy_exam_attempts;

-- Certificate rows are issued only by the grading function and are read-only to clients.
drop policy if exists "certificates_admin_manage" on public.academy_certificates;

-- Explicit deny policy documents the private question bank's client access boundary.
drop policy if exists "deny_client_access_to_exam_answer_bank" on private.academy_exam_questions;
create policy "deny_client_access_to_exam_answer_bank"
on private.academy_exam_questions for all to public
using (false) with check (false);

-- Public verification exposes only certificate validity and non-identifying award data.
create or replace function private.verify_academy_certificate(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_cert public.academy_certificates%rowtype;
begin
  if p_code is null or length(trim(p_code)) < 8 or length(trim(p_code)) > 32 then
    return jsonb_build_object('valid',false);
  end if;
  select * into v_cert
  from public.academy_certificates
  where certificate_code = upper(trim(p_code))
    and revoked_at is null;
  if not found then return jsonb_build_object('valid',false); end if;
  return jsonb_build_object(
    'valid',true,
    'certificate_code',v_cert.certificate_code,
    'track',v_cert.track,
    'score',v_cert.score,
    'issued_at',v_cert.issued_at
  );
end;
$$;
revoke all on function private.verify_academy_certificate(text) from public;
grant execute on function private.verify_academy_certificate(text) to anon, authenticated;

create or replace function public.verify_academy_certificate(p_code text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select private.verify_academy_certificate(p_code); $$;
revoke all on function public.verify_academy_certificate(text) from public;
grant execute on function public.verify_academy_certificate(text) to anon, authenticated;
