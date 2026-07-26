-- ============================================================
-- Row Level Security
-- ============================================================

-- ----- profiles: owner-only -----------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ----- user_use_cases: owner-only -----------------------------------------
alter table public.user_use_cases enable row level security;

drop policy if exists user_use_cases_select_own on public.user_use_cases;
create policy user_use_cases_select_own on public.user_use_cases
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists user_use_cases_insert_own on public.user_use_cases;
create policy user_use_cases_insert_own on public.user_use_cases
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists user_use_cases_delete_own on public.user_use_cases;
create policy user_use_cases_delete_own on public.user_use_cases
  for delete to authenticated
  using (user_id = auth.uid());

-- ----- use_cases: read-only catalogue -------------------------------------
alter table public.use_cases enable row level security;

drop policy if exists use_cases_select_active on public.use_cases;
create policy use_cases_select_active on public.use_cases
  for select to anon, authenticated
  using (is_active);
-- (no insert/update/delete policies → clients cannot mutate the catalogue)

-- ----- location_pings: insert-only from clients ---------------------------
-- Anonymous (skipped) users must be able to write pings by device_id, so
-- INSERT is open to anon + authenticated. SELECT is restricted to a user's
-- own rows. Trade-off: open anon insert = possible spam; acceptable for MVP,
-- tighten later with an Edge Function / captcha if needed.
alter table public.location_pings enable row level security;

drop policy if exists location_pings_insert_any on public.location_pings;
create policy location_pings_insert_any on public.location_pings
  for insert to anon, authenticated
  with check (
    device_id is not null
    and (user_id is null or user_id = auth.uid())
  );

drop policy if exists location_pings_select_own on public.location_pings;
create policy location_pings_select_own on public.location_pings
  for select to authenticated
  using (user_id = auth.uid());
