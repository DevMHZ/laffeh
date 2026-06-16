# Laffeh — لفّة

**Your smarter route.** Laffeh is a Flutter route-planning app: drop your stops on the
map, let the optimizer find the best order, then preview the trip or drive it
turn-by-turn. Built around a road-logo brand identity (the Arabic word *لفّة*,
"a loop/round trip", drawn as a winding road).

## Features

- **Map-first point picking** — pan the map under a sniper-style aim reticle and drop
  points with one tap; tap a placed point to **rename**, **set as departure**, or
  **remove** it.
- **AI route optimization** — sends your stops to the Afdal VRP `POST /optimize`
  endpoint and draws the optimized polyline, with distance/time/savings metrics.
- **Trip preview (simulation)** — a video-style **scrubber** with a car-shaped playhead:
  drag to seek anywhere in the trip and replay a stretch. Free **zoom/rotate** the map
  while it plays; it **detaches** from following the car once you move it, with a
  **Recenter** button to re-attach. A **compass** appears when the map is turned off
  north and snaps it back.
- **Drive mode** — follows your real GPS location and heading along the route.
- **Saved routes**, **CSV import/export**, and **paste-a-list** bulk entry.
- **Localized** in English, Arabic, and French (`AppStrings`).
- **Branded loading** — an animated road-logo splash/launch screen and a set of playful
  optimization loading animations.

## Architecture

Clean-architecture feature slices under `lib/features/<feature>/`:

- `presentation/` — pages, widgets, and `cubit/` (state via **flutter_bloc**).
- `domain/` — entities and repository interfaces.
- `data/` — `datasources/` (Dio), `models/`, and repository implementations.

Cross-cutting code lives in `lib/core/` (config, network, theme, constants, widgets,
utils). Dependencies are wired with **get_it** in `core/di/service_locator.dart`.

**Networking** (`core/network/dio_client.dart`) uses three Dio clients:

- **AI route** — the optimizer (`AiRouteRemoteDataSource` → `/optimize`).
- **OSRM** — road-snapped routing geometry.
- **Nominatim** — reverse geocoding for point labels/addresses.

Map tiles are rendered with **flutter_map** (Mapbox Streets, falling back to CARTO/OSM).

## Getting started

1. Install Flutter, then `flutter pub get`.
2. Create a `.env` at the project root (read by `flutter_dotenv` / `EnvConfig`):

   ```env
   AI_ROUTE_BASE_URL=https://your-vrp-host/api/v1
   AI_ROUTE_API_KEY=your-key
   MAPBOX_ACCESS_TOKEN=pk.your_token   # optional; CARTO is used if empty
   ```

   All keys have sensible fallbacks in `EnvConfig`, so the app runs without a
   `.env` for local experimentation.

3. Run: `flutter run`.

## Tests & visual previews

`flutter test` runs the unit tests plus a set of **golden "preview" tests**
(`test/*_preview_test.dart`) that render the splash, loading animations, trip overlay,
and markers to `test/goldens/`. They're previews, not strict regression gates —
refresh them after intentional UI changes:

```sh
flutter test --update-goldens
```

## Project layout

```
lib/
  core/            config, network, di, theme, constants, widgets, utils
  features/
    route_planner/ map, point picking, optimization, simulation, drive mode
    saved_routes/  saved-route history
    onboarding/    first-run flow
test/              unit tests + golden preview tests
design/            local design references (not tracked)
```
