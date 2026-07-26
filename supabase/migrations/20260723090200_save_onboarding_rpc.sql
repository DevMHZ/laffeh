-- ============================================================
-- RPC: save_onboarding
-- Persists an onboarding submission as ONE atomic unit:
--   1. upsert profile (keyed by auth.uid())
--   2. replace the user's use-case selections
--   3. store the "other" free text only when `other` is selected
--   4. mark onboarding_completed = true
-- Any failure rolls the whole thing back (single function body).
-- ============================================================

create or replace function public.save_onboarding(
  p_full_name     text,
  p_company_name  text,
  p_use_case_codes text[],
  p_other_text    text default null
)
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

  if coalesce(array_length(p_use_case_codes, 1), 0) = 0 then
    raise exception 'USE_CASE_REQUIRED';
  end if;

  insert into public.profiles (id, full_name, company_name, other_use_case_text, onboarding_completed)
  values (
    v_uid,
    btrim(p_full_name),
    btrim(p_company_name),
    case when 'other' = any(p_use_case_codes) then nullif(btrim(coalesce(p_other_text, '')), '') end,
    true
  )
  on conflict (id) do update set
    full_name            = excluded.full_name,
    company_name         = excluded.company_name,
    other_use_case_text  = excluded.other_use_case_text,
    onboarding_completed = true;

  delete from public.user_use_cases where user_id = v_uid;

  insert into public.user_use_cases (user_id, use_case_id)
  select v_uid, uc.id
  from public.use_cases uc
  where uc.code = any(p_use_case_codes)
    and uc.is_active;
end;
$$;

revoke all on function public.save_onboarding(text, text, text[], text) from public, anon;
grant execute on function public.save_onboarding(text, text, text[], text) to authenticated;
