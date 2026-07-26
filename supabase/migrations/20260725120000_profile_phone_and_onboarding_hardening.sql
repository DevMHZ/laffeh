-- ============================================================
-- 1. profiles.phone + profiles.use_case_codes — both now readable on the row
-- 2. a profile row is created at sign-up (not only at step 4)
-- 3. save_onboarding fails loudly on a use-case code it can't resolve
-- 4. profiles_overview — one readable row per user, labels included
-- ============================================================

-- ----- 1. phone + reasons on the profile row ------------------------------
-- `phone` mirrors auth.users.phone, and `use_case_codes` mirrors the rows in
-- user_use_cases. Both are read-convenience copies written by the trigger and
-- the RPC below — user_use_cases stays the relational source of truth, but a
-- profile row is now self-explanatory in the dashboard.
alter table public.profiles add column if not exists phone text;
alter table public.profiles
  add column if not exists use_case_codes text[] not null default '{}';

create index if not exists idx_profiles_phone on public.profiles (phone);

-- Backfill anyone who signed up before this migration.
update public.profiles p
   set phone = u.phone
  from auth.users u
 where u.id = p.id
   and p.phone is distinct from u.phone;

update public.profiles p
   set use_case_codes = coalesce(picked.codes, '{}')
  from (
    select uuc.user_id, array_agg(uc.code order by uc.sort_order) as codes
    from public.user_use_cases uuc
    join public.use_cases uc on uc.id = uuc.use_case_id
    group by uuc.user_id
  ) picked
 where picked.user_id = p.id
   and p.use_case_codes is distinct from picked.codes;

-- ----- 2. row at sign-up --------------------------------------------------
-- The profile used to appear only when the user finished all four steps, so
-- anyone who dropped out mid-flow left no row at all. Create it on sign-up
-- with the phone, and let the flow fill in the rest — which means name and
-- company can no longer be NOT NULL.
alter table public.profiles alter column full_name    drop not null;
alter table public.profiles alter column company_name drop not null;

-- The blank/length checks must tolerate the not-yet-filled state.
alter table public.profiles drop constraint if exists profiles_full_name_not_blank;
alter table public.profiles drop constraint if exists profiles_company_name_not_blank;
alter table public.profiles add  constraint profiles_full_name_not_blank
  check (full_name is null or length(btrim(full_name)) > 0);
alter table public.profiles add  constraint profiles_company_name_not_blank
  check (company_name is null or length(btrim(company_name)) > 0);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone)
  values (new.id, new.phone)
  on conflict (id) do update set phone = excluded.phone;
  return new;
end;
$$;

drop trigger if exists trg_auth_user_created on auth.users;
create trigger trg_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep the mirror honest if the number is ever changed/confirmed later.
drop trigger if exists trg_auth_user_phone_changed on auth.users;
create trigger trg_auth_user_phone_changed
  after update of phone on auth.users
  for each row
  when (new.phone is distinct from old.phone)
  execute function public.handle_new_user();

-- ----- 3. save_onboarding: phone + strict code resolution -----------------
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
  v_uid     uuid := auth.uid();
  v_phone   text;
  v_codes   text[];
  v_wanted  integer := coalesce(array_length(p_use_case_codes, 1), 0);
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if v_wanted = 0 then
    raise exception 'USE_CASE_REQUIRED';
  end if;

  select u.phone into v_phone from auth.users u where u.id = v_uid;

  -- Resolve the codes first so an unknown one fails the whole submission.
  -- Previously they were dropped in silence: the save "succeeded" and no
  -- reasons were stored.
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
    other_use_case_text, onboarding_completed
  )
  values (
    v_uid,
    v_phone,
    btrim(p_full_name),
    btrim(p_company_name),
    v_codes,
    case when 'other' = any(p_use_case_codes) then nullif(btrim(coalesce(p_other_text, '')), '') end,
    true
  )
  on conflict (id) do update set
    phone                = coalesce(excluded.phone, public.profiles.phone),
    full_name            = excluded.full_name,
    company_name         = excluded.company_name,
    use_case_codes       = excluded.use_case_codes,
    other_use_case_text  = excluded.other_use_case_text,
    onboarding_completed = true;

  delete from public.user_use_cases where user_id = v_uid;

  insert into public.user_use_cases (user_id, use_case_id)
  select v_uid, uc.id
  from public.use_cases uc
  where uc.code = any(v_codes);
end;
$$;

revoke all on function public.save_onboarding(text, text, text[], text) from public, anon;
grant execute on function public.save_onboarding(text, text, text[], text) to authenticated;

-- ----- 4. one readable row per user --------------------------------------
-- profiles.use_case_codes holds the raw codes; this view adds the localized
-- labels by joining the catalogue, so the dashboard reads in plain language.
create or replace view public.profiles_overview
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
  p.created_at,
  p.updated_at
from public.profiles p
left join public.user_use_cases uuc on uuc.user_id = p.id
left join public.use_cases      uc  on uc.id = uuc.use_case_id
group by p.id;

grant select on public.profiles_overview to authenticated;
