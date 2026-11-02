create table if not exists private.academy_certificate_events(
 id uuid primary key default gen_random_uuid(),
 certificate_id uuid not null,
 certificate_code text not null,
 event_type text not null check(event_type in ('revoked')),
 reason text not null,
 actor_id uuid,
 created_at timestamptz not null default now()
);
create index if not exists academy_certificate_events_code_idx on private.academy_certificate_events(certificate_code,created_at desc);
alter table private.academy_certificate_events enable row level security;
drop policy if exists academy_certificate_events_admin_select on private.academy_certificate_events;
create policy academy_certificate_events_admin_select on private.academy_certificate_events for select to authenticated using ((select private.is_academy_admin()));

create or replace function private.revoke_academy_certificate(p_code text,p_reason text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare v_uid uuid:=(select auth.uid()); v_cert public.academy_certificates%rowtype;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if not coalesce((select private.is_academy_admin()),false) then raise exception 'Admin access required'; end if;
 if p_code is null or length(btrim(p_code))<8 or length(btrim(p_code))>32 then raise exception 'Invalid certificate code'; end if;
 if p_reason is null or char_length(btrim(p_reason))<20 or char_length(p_reason)>2000 then raise exception 'Revocation reason must contain 20 to 2000 characters'; end if;
 update public.academy_certificates
 set revoked_at=now()
 where certificate_code=upper(btrim(p_code)) and revoked_at is null
 returning * into v_cert;
 if not found then raise exception 'Certificate not found or already revoked'; end if;
 insert into private.academy_certificate_events(certificate_id,certificate_code,event_type,reason,actor_id)
 values(v_cert.id,v_cert.certificate_code,'revoked',btrim(p_reason),v_uid);
 return jsonb_build_object('revoked',true,'certificate_code',v_cert.certificate_code,'revoked_at',v_cert.revoked_at);
end;
$function$;
revoke all on function private.revoke_academy_certificate(text,text) from public,anon;
grant execute on function private.revoke_academy_certificate(text,text) to authenticated;

create or replace function public.revoke_academy_certificate(p_code text,p_reason text)
returns jsonb
language sql
security invoker
set search_path=''
as $function$
 select private.revoke_academy_certificate(p_code,p_reason);
$function$;
revoke all on function public.revoke_academy_certificate(text,text) from public,anon;
grant execute on function public.revoke_academy_certificate(text,text) to authenticated;
comment on function public.revoke_academy_certificate(text,text) is 'Admin-only certificate revocation with mandatory reason and private audit event.';
