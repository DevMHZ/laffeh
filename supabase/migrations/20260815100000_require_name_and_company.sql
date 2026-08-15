-- ============================================================
-- Make full_name and company_name mandatory at sign-up, server-side.
--
-- The client already refuses to advance past the name/company step with either
-- one blank, but that was the only thing enforcing it: `save_onboarding` was
-- happy to write whatever it was handed, and the not-null on company_name was
-- dropped back in 20260725120000 (the row is created by the sign-up trigger,
-- long before the profile steps run, so it has to start out null).
--
-- The remaining `profiles_company_name_not_blank` check does catch an empty
-- string, but as a raw 23514 constraint violation — an opaque failure at the
-- last step of onboarding. A guard clause up front fails the same call with a
-- named error the app maps to the right field instead.
--
-- Body is otherwise identical to 20260727100000.
-- ============================================================

create or replace function public.save_onboarding(
  p_full_name      text,
  p_company_name   text,
  p_use_case_codes text[],
  p_other_text     text default null,
  p_terms_version  text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_phone   text;
  v_codes   text[];
  v_wanted  integer := coalesce(array_length(p_use_case_codes, 1), 0);
  v_terms   text    := nullif(btrim(coalesce(p_terms_version, '')), '');
  v_name    text    := nullif(btrim(coalesce(p_full_name, '')), '');
  v_company text    := nullif(btrim(coalesce(p_company_name, '')), '');
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if v_name is null then
    raise exception 'FULL_NAME_REQUIRED';
  end if;

  -- Mandatory: every account belongs to a company, and the field is the only
  -- place that is recorded.
  if v_company is null then
    raise exception 'COMPANY_REQUIRED';
  end if;

  -- Same ceilings the table checks, raised here so they read as validation
  -- rather than as a constraint violation.
  if length(v_name) > 120 then
    raise exception 'FULL_NAME_TOO_LONG';
  end if;

  if length(v_company) > 160 then
    raise exception 'COMPANY_TOO_LONG';
  end if;

  if v_wanted = 0 then
    raise exception 'USE_CASE_REQUIRED';
  end if;

  select u.phone into v_phone from auth.users u where u.id = v_uid;

  -- Resolve the codes first so an unknown one fails the whole submission.
  select coalesce(array_agg(uc.code order by uc.sort_order), '{}')
    into v_codes
    from public.use_cases uc
   where uc.code = any(p_use_case_codes)
     and uc.is_active;

  if coalesce(array_length(v_codes, 1), 0) <> v_wanted then
    raise exception 'USE_CASE_UNKNOWN: matched % of % codes (%)',
      coalesce(array_length(v_codes, 1), 0),
      v_wanted,
      array_to_string(p_use_case_codes, ',');
  end if;

  insert into public.profiles (
    id, phone, full_name, company_name, use_case_codes,
    other_use_case_text, onboarding_completed,
    terms_version, terms_accepted_at
  )
  values (
    v_uid,
    v_phone,
    v_name,
    v_company,
    v_codes,
    case when 'other' = any(p_use_case_codes) then nullif(btrim(coalesce(p_other_text, '')), '') end,
    true,
    v_terms,
    case when v_terms is not null then now() end
  )
  on conflict (id) do update set
    phone                = coalesce(excluded.phone, public.profiles.phone),
    full_name            = excluded.full_name,
    company_name         = excluded.company_name,
    use_case_codes       = excluded.use_case_codes,
    other_use_case_text  = excluded.other_use_case_text,
    onboarding_completed = true,
    terms_version        = coalesce(v_terms, public.profiles.terms_version),
    -- Keep the original acceptance time unless the version actually changed.
    terms_accepted_at    = case
      when v_terms is null then public.profiles.terms_accepted_at
      when public.profiles.terms_version is distinct from v_terms then now()
      else coalesce(public.profiles.terms_accepted_at, now())
    end;

  delete from public.user_use_cases where user_id = v_uid;

  insert into public.user_use_cases (user_id, use_case_id)
  select v_uid, uc.id
  from public.use_cases uc
  where uc.code = any(v_codes);
end;
$$;

revoke all    on function public.save_onboarding(text, text, text[], text, text) from public, anon;
grant  execute on function public.save_onboarding(text, text, text[], text, text) to authenticated;

-- An account is only "complete" once both are filled in, so make that the
-- table's own rule rather than something only the RPC knows.
--
-- `not valid` skips the scan of existing rows — the rule still applies to every
-- insert and update from here on, which is the point, and this way the
-- migration cannot fail on a row left behind by an earlier version of the flow.
-- Once the existing data is known to be clean:
--   alter table public.profiles validate constraint profiles_onboarding_needs_name_company;
alter table public.profiles drop constraint if exists profiles_onboarding_needs_name_company;
alter table public.profiles add  constraint profiles_onboarding_needs_name_company
  check (
    not onboarding_completed
    or (
      full_name        is not null and length(btrim(full_name))    > 0
      and company_name is not null and length(btrim(company_name)) > 0
    )
  ) not valid;
