-- ============================================================
-- Policy acceptance (privacy policy / terms of service)
--
-- 1. profiles.terms_version + profiles.terms_accepted_at
-- 2. record_terms_acceptance() — called right after sign-up, so the record
--    exists the moment the account does (not only when onboarding finishes)
-- 3. save_onboarding() gains p_terms_version and stamps the same columns,
--    preserving the original timestamp while the version is unchanged
-- 4. profiles_overview exposes both columns
-- ============================================================

-- ----- 1. columns ---------------------------------------------------------
alter table public.profiles add column if not exists terms_version     text;
alter table public.profiles add column if not exists terms_accepted_at timestamptz;

comment on column public.profiles.terms_version is
  'Published policy version the user accepted (LegalConfig.termsVersion in the app).';
comment on column public.profiles.terms_accepted_at is
  'When that version was first accepted. Preserved while the version is unchanged.';

-- ----- 2. record acceptance at sign-up ------------------------------------
-- The profile row itself is created by the on-signup trigger, so this only
-- ever updates. Re-accepting the same version keeps the first timestamp.
create or replace function public.record_terms_acceptance(p_terms_version text)
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

  if nullif(btrim(coalesce(p_terms_version, '')), '') is null then
    raise exception 'TERMS_VERSION_REQUIRED';
  end if;

  insert into public.profiles (id, terms_version, terms_accepted_at)
  values (v_uid, btrim(p_terms_version), now())
  on conflict (id) do update set
    terms_version     = btrim(p_terms_version),
    terms_accepted_at = case
      when public.profiles.terms_version is distinct from btrim(p_terms_version)
        then now()
      else coalesce(public.profiles.terms_accepted_at, now())
    end;
end;
$$;

revoke all    on function public.record_terms_acceptance(text) from public, anon;
grant  execute on function public.record_terms_acceptance(text) to authenticated;

-- ----- 3. save_onboarding + p_terms_version -------------------------------
-- Same body as the hardened version (phone mirror + strict code resolution),
-- plus the acceptance stamp.
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
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
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
    btrim(p_full_name),
    btrim(p_company_name),
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

-- Adding a parameter creates a NEW overload; drop the 4-arg one so a call with
-- named params can never resolve ambiguously.
drop function if exists public.save_onboarding(text, text, text[], text);

revoke all    on function public.save_onboarding(text, text, text[], text, text) from public, anon;
grant  execute on function public.save_onboarding(text, text, text[], text, text) to authenticated;

-- ----- 4. surface it in the overview -------------------------------------
-- Dropped, not replaced: `create or replace view` may only *append* columns,
-- and the two new ones belong next to onboarding_completed rather than after
-- updated_at. Replacing in place fails with
--   42P16 cannot change name of view column "created_at" to "terms_version"
-- Nothing depends on this view (it is a reporting convenience, unused by the
-- app), so dropping it is free.
drop view if exists public.profiles_overview;

create view public.profiles_overview
with (security_invoker = true)
as
select
  p.id,
  p.phone,
  p.full_name,
  p.company_name,
  p.use_case_codes,
  coalesce(
    string_agg(uc.label_ar, '، ' order by uc.sort_order) filter (where uc.code is not null),
    ''
  ) as use_cases_ar,
  coalesce(
    string_agg(uc.label_en, ', ' order by uc.sort_order) filter (where uc.code is not null),
    ''
  ) as use_cases_en,
  p.other_use_case_text,
  p.onboarding_completed,
  p.terms_version,
  p.terms_accepted_at,
  p.created_at,
  p.updated_at
from public.profiles p
left join public.user_use_cases uuc on uuc.user_id = p.id
left join public.use_cases      uc  on uc.id = uuc.use_case_id
group by p.id;

grant select on public.profiles_overview to authenticated;
