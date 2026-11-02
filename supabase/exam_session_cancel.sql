create or replace function private.cancel_academy_exam_session(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_count integer;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 update private.academy_exam_sessions set submitted_at=now()
 where id=p_session_id and user_id=v_uid and submitted_at is null;
 get diagnostics v_count=row_count;
 if v_count=0 then raise exception 'Session not found or already closed'; end if;
 return jsonb_build_object('cancelled',true);
end;
$$;
create or replace function public.cancel_academy_exam_session(p_session_id uuid)
returns jsonb language sql security invoker set search_path=''
as $$ select private.cancel_academy_exam_session(p_session_id); $$;
revoke all on function private.cancel_academy_exam_session(uuid) from public,anon;
grant execute on function private.cancel_academy_exam_session(uuid) to authenticated;
revoke all on function public.cancel_academy_exam_session(uuid) from public,anon;
grant execute on function public.cancel_academy_exam_session(uuid) to authenticated;
