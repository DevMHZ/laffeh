-- ============================================================
-- Saved routes follow the account, not the handset.
--
-- The route history has always lived in the app's own local storage. That is
-- still where it is read from — instantly, and with no network — but a signed-in
-- driver's history is now mirrored here as well, so signing in on a second
-- phone brings the same trips along.
--
-- `payload` is the app's existing route JSON, stored verbatim. Keeping one
-- opaque document rather than a relational spread of stops, geometry and
-- maneuvers means the local file and the cloud row can never drift apart, and
-- a record saved by an older build still decodes through the same reader.
-- The flat columns beside it are the ones a person (or a future dashboard)
-- would want to query on; the app itself reads only `payload`.
--
-- Rows go with the account: the foreign key cascades, so `delete_my_account()`
-- clears a driver's history along with their credentials without needing to
-- name this table.
-- ============================================================

create table if not exists public.saved_routes (
  -- The id the app generated on-device (`r_<microseconds>`). It is unique per
  -- account rather than globally, so two drivers whose phones happened to pick
  -- the same microsecond can't collide.
  user_id      uuid        not null references auth.users (id) on delete cascade,
  id           text        not null,
  name         text        not null,
  saved_at     timestamptz not null,
  routing_mode text        not null default 'car',
  stops_count  integer     not null default 0,
  distance_km  double precision,
  payload      jsonb       not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (user_id, id),
  constraint saved_routes_id_not_blank   check (length(btrim(id)) > 0),
  constraint saved_routes_id_max         check (length(id) <= 120),
  constraint saved_routes_name_not_blank check (length(btrim(name)) > 0),
  constraint saved_routes_name_max       check (length(name) <= 160),
  constraint saved_routes_stops_count    check (stops_count >= 0),
  constraint saved_routes_payload_object check (jsonb_typeof(payload) = 'object'),
  -- A long multi-stop route with full road geometry runs to about a megabyte.
  -- Four is headroom; anything past it is a bug or an abusive client, and
  -- should be refused at the door rather than stored.
  constraint saved_routes_payload_size   check (length(payload::text) <= 4194304)
);

create index if not exists idx_saved_routes_user_saved_at
  on public.saved_routes (user_id, saved_at desc);

-- Reuses the helper from the init migration.
drop trigger if exists trg_saved_routes_updated_at on public.saved_routes;
create trigger trg_saved_routes_updated_at
  before update on public.saved_routes
  for each row execute function public.set_updated_at();

-- ----- RLS ----------------------------------------------------------------
-- Owner-only, all four verbs: a driver's route history is their own. Nothing
-- is readable or writable by `anon` — a skipped user has no account to sync
-- to, and their history simply stays on the phone.
alter table public.saved_routes enable row level security;

drop policy if exists saved_routes_select_own on public.saved_routes;
create policy saved_routes_select_own on public.saved_routes
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists saved_routes_insert_own on public.saved_routes;
create policy saved_routes_insert_own on public.saved_routes
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists saved_routes_update_own on public.saved_routes;
create policy saved_routes_update_own on public.saved_routes
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists saved_routes_delete_own on public.saved_routes;
create policy saved_routes_delete_own on public.saved_routes
  for delete to authenticated
  using (user_id = auth.uid());
