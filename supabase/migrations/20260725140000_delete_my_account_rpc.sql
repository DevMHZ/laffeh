-- ============================================================
-- RPC: delete_my_account
--
-- Google Play requires an in-app path that permanently deletes the account and
-- its data. A client holding the anon/publishable key cannot touch
-- `auth.users`, so deletion runs through this SECURITY DEFINER function.
--
-- It takes NO parameters on purpose: the target is always `auth.uid()`, so a
-- caller can only ever delete themselves, never another account.
--
-- (Supabase's own docs reach for an Edge Function with the service_role key.
-- Same privilege, but this ships by pasting SQL — no function deploy step and
-- no service_role key to keep anywhere.)
-- ============================================================

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  -- `device_locations.user_id` is ON DELETE SET NULL, which would orphan the
  -- stored coordinates instead of removing them. Delete the row outright —
  -- the fix was collected under this account and must go with it.
  delete from public.device_locations where user_id = v_uid;

  -- `profiles` and `user_use_cases` are ON DELETE CASCADE from auth.users, so
  -- this one statement clears the profile, the chosen use-cases and the
  -- credentials together.
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
