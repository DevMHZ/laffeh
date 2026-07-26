-- ============================================================
-- Location model change: append-only history → current fix only.
--
-- `location_pings` stored one row per app launch, forever. This replaces it
-- with `device_locations`: exactly ONE row per device, overwritten on every
-- launch, so the table always holds "where this device was last seen".
--
-- Keyed by `device_id`, not `user_id`, because skipped (never-signed-in) users
-- have no user id and must still be trackable. `user_id` is stamped on the row
-- whenever a session exists.
-- ============================================================

create table if not exists public.device_locations (
  device_id  text primary key,
  user_id    uuid references auth.users (id) on delete set null,
  lat        double precision not null,
  lng        double precision not null,
  accuracy   double precision,
  updated_at timestamptz not null default now(),
  constraint device_locations_lat_range check (lat between -90 and 90),
  constraint device_locations_lng_range check (lng between -180 and 180)
);

create index if not exists idx_device_locations_user
  on public.device_locations (user_id);

-- Reuses the helper from the init migration: refreshes `updated_at` on every
-- overwrite, including the UPDATE half of an upsert.
drop trigger if exists trg_device_locations_updated_at on public.device_locations;
create trigger trg_device_locations_updated_at
  before update on public.device_locations
  for each row execute function public.set_updated_at();

-- ----- RLS ----------------------------------------------------------------
-- Clients upsert, so both INSERT and UPDATE must be open to anon (skipped
-- users write by device_id alone). SELECT stays restricted to a user's own row.
--
-- Trade-off, unchanged from `location_pings`: an anon client that knows a
-- device_id can overwrite that device's row. device_id is a random UUID so this
-- is impractical to guess, but it is not authenticated. Tighten with an Edge
-- Function if this ever matters.
alter table public.device_locations enable row level security;

drop policy if exists device_locations_insert_any on public.device_locations;
create policy device_locations_insert_any on public.device_locations
  for insert to anon, authenticated
  with check (
    device_id is not null
    and (user_id is null or user_id = auth.uid())
  );

drop policy if exists device_locations_update_any on public.device_locations;
create policy device_locations_update_any on public.device_locations
  for update to anon, authenticated
  using (device_id is not null)
  with check (
    device_id is not null
    and (user_id is null or user_id = auth.uid())
  );

drop policy if exists device_locations_select_own on public.device_locations;
create policy device_locations_select_own on public.device_locations
  for select to authenticated
  using (user_id = auth.uid());

-- ----- retiring the old table ---------------------------------------------
-- `location_pings` is unused once the app writes to `device_locations`, and the
-- launch-per-row history it holds is exactly what this change moves away from.
-- Dropped rather than kept around: it was pre-launch test data only.
-- This is irreversible — the rows are not migrated anywhere.
drop table if exists public.location_pings;
