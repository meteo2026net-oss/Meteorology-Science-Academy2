create or replace function public.get_academy_certificate_audit(p_code text)
returns table(event_type text,reason text,actor_name text,created_at timestamptz)
language sql stable security invoker set search_path=''
as $function$
 select e.event_type,e.reason,coalesce(p.display_name,'إدارة الأكاديمية'),e.created_at
 from private.academy_certificate_events e
 left join public.academy_profiles p on p.id=e.actor_id
 where e.certificate_code=upper(btrim(p_code))
   and (select private.is_academy_admin())
 order by e.created_at desc limit 20;
$function$;
revoke all on function public.get_academy_certificate_audit(text) from public,anon;
grant execute on function public.get_academy_certificate_audit(text) to authenticated;