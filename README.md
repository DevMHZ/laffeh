# لفّة · Laffeh

AI-powered route optimization built around the **Afdal VRP**. Drop points on the map, hit, and get back the smartest order plus driveable polylines for the go / return / full trip.


## ✨ Features

- 🗺️ **Map-first UX** powered by `google_maps_flutter`.
- 📍 Tap-to-add waypoints, drag-to-reorder, rename, delete, promote to depot.
- 🤖 **AI optimization** via the Afdal `/api/v1/optimize` endpoint.
- 🛣️ Driveable polylines from the **Google Directions API** (with straight-line fallback).
- 📊 Results sheet with distance, ETA, savings vs. naive order, and fuel estimate.
- 🇸🇦 Arabic copy and RTL layout out of the box.
- 🔐 No API keys hardcoded — keys come from `.env` and Gradle.

---

## 🧱 Project Structure

```
lib/
├─ main.dart                       # bootstraps dotenv + DI then runApp
├─ app.dart                        # MaterialApp, theme, RTL Directionality
│
├─ core/
│  ├─ config/
│  │  ├─ app_config.dart           # tunable defaults (depot, weights, timeouts)
│  │  └─ env_config.dart           # typed accessor over .env
│  ├─ constants/app_constants.dart # all Arabic strings
│  ├─ di/service_locator.dart      # GetIt registrations
│  ├─ error/
│  │  ├─ exceptions.dart           # data-layer exceptions
│  │  └─ failures.dart             # public typed failures
│  ├─ network/
│  │  ├─ dio_client.dart           # named Dio instances (AI + Directions)
│  │  ├─ api_result.dart           # ApiSuccess / ApiFailure result type
│  │  └─ network_info.dart         # offline check
│  ├─ theme/
│  │  ├─ app_colors.dart           # palette
│  │  ├─ app_text_styles.dart      # text styles
│  │  └─ app_theme.dart            # MaterialApp theme
│  ├─ utils/
│  │  ├─ distance_utils.dart       # haversine + formatters
│  │  ├─ location_utils.dart       # Geolocator wrapper
│  │  └─ polyline_utils.dart       # polyline decoding
│  └─ widgets/                     # AppButton, AppLoading, AppErrorView, ...
│
└─ features/
   ├─ route_planner/
   │  ├─ data/
   │  │  ├─ datasources/
   │  │  │  ├─ ai_route_remote_datasource.dart      # POST /api/v1/optimize
   │  │  │  └─ google_maps_remote_datasource.dart   # GET /directions/json
   │  │  ├─ models/
   │  │  │  ├─ route_point_model.dart
   │  │  │  ├─ route_request_model.dart
   │  │  │  ├─ route_response_model.dart
   │  │  │  ├─ optimized_route_model.dart
   │  │  │  └─ route_metrics_model.dart
   │  │  └─ repositories/route_repository_impl.dart
   │  ├─ domain/
   │  │  ├─ entities/
   │  │  │  ├─ route_point.dart
   │  │  │  ├─ route_metrics.dart
   │  │  │  └─ optimized_route.dart
   │  │  ├─ repositories/route_repository.dart
   │  │  └─ usecases/
   │  │     ├─ optimize_route_usecase.dart
   │  │     └─ get_directions_usecase.dart
   │  └─ presentation/
   │     ├─ cubit/
   │     │  ├─ route_planner_cubit.dart
   │     │  └─ route_planner_state.dart
   │     ├─ pages/
   │     │  ├─ splash_page.dart
   │     │  └─ route_planner_page.dart
   │     └─ widgets/
   │        ├─ route_map_view.dart
   │        ├─ route_points_sheet.dart
   │        ├─ route_point_tile.dart
   │        ├─ route_summary_sheet.dart
   │        ├─ route_metrics_card.dart
   │        ├─ map_action_button.dart
   │        └─ optimize_route_button.dart
   └─ settings/
      └─ presentation/pages/settings_page.dart
```

---

## 🚀 Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure environment

Copy `.env.example` to `.env` and fill in real values:

```env
GOOGLE_MAPS_API_KEY=AIza...
AI_ROUTE_BASE_URL=https://back.laffa.afdal.tech/api/v1
AI_ROUTE_API_KEY=test-key-001
```

`.env` is gitignored — never commit it.

### 3. Android — Google Maps key

The Maps key is injected into `AndroidManifest.xml` via Gradle `manifestPlaceholders`. The Gradle script (`android/app/build.gradle.kts`) reads it from, in order:

1. `android/local.properties`:
   ```properties
   GOOGLE_MAPS_API_KEY=AIza...
   ```
2. The root `.env` file.

If neither has a real value, the manifest is built with the placeholder string and Google Maps will refuse to render. The Settings page in-app will show a red banner.

> Why two sources? `local.properties` is the Android idiom (already gitignored); `.env` is the Flutter idiom. The script tries `local.properties` first because it's the more "native" Android workflow.

### 4. iOS — Google Maps key

`google_maps_flutter` requires the iOS SDK to be initialized with a key. Edit `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

if let path = Bundle.main.path(forResource: "Laffeh-Secrets", ofType: "plist"),
   let secrets = NSDictionary(contentsOfFile: path),
   let key = secrets["GOOGLE_MAPS_API_KEY"] as? String {
  GMSServices.provideAPIKey(key)
}
```

Then add `ios/Runner/Laffeh-Secrets.plist` (gitignored — pattern already in your `.gitignore`):

```xml
<plist version="1.0">
<dict>
  <key>GOOGLE_MAPS_API_KEY</key>
  <string>AIza...</string>
</dict>
</plist>
```

Location strings are already wired in `ios/Runner/Info.plist`.

### 5. Run

```bash
# Android
flutter run -d android

# iOS (requires macOS + Xcode)
flutter run -d ios
```

---

## 🔌 API Contract (Afdal VRP)

Documented in `C:\Users\moham\OneDrive\Desktop\api_test\api_README.md`. The data layer assumes:

**`POST {AI_ROUTE_BASE_URL}/optimize`**

Headers
```
X-API-Key: <AI_ROUTE_API_KEY>
Content-Type: application/json
```

Body
```json
{
  "num_vehicles": 1,
  "vehicle_capacity": 10000,
  "depot_lat": 24.7136,
  "depot_lon": 46.6753,
  "routing_mode": "car",
  "time_limit": 15,
  "max_vehicle_time": 480,
  "deliveries": [
    {"address": "Olaya St #2", "lat": 24.6702, "lon": 46.7394, "weight": 20}
  ]
}
```

Documented response shape (Python sample):
```json
{
  "total_distance": 123.45,
  "vehicles_used": 1,
  "routes": [
    {
      "vehicle_id": 1,
      "total_distance": 50.21,
      "total_load": 220,
      "stops": [{"address": "..."}]
    }
  ]
}
```

### Assumptions / open questions

The Python test prints only `address` per stop — the live response likely also includes `lat` / `lon` (and possibly an `arrival_time` or `cumulative_distance`). The data models accept those fields when present (`RoutePointModel.fromJson` handles common aliases), but if any are missing the repository falls back to matching response stops back to the user's input by address, then by coordinate proximity (~10 m).

Optional metric fields the UI surfaces if returned (otherwise shown as `غير متاح من الخادم`):
- `total_duration_minutes` / `estimated_time` / `duration`
- `saved_distance` / `distance_saved`
- `saved_time` / `saved_duration`
- `fuel_liters` / `fuel_consumption` / `fuel_saving`

Polylines: the AI API doesn't appear to return geometry. We call **Google Directions API** with the optimized order to get a real polyline (`overview_polyline`). If Directions is unavailable (no key, quota exhausted, no route) we fall back to straight segments between stops and mark the metrics as approximated.

---

## 🏗️ Architecture Notes

**Bloc/Cubit + use cases + repository.** The `RoutePlannerCubit` orchestrates UI state via an explicit `RoutePlannerStatus` enum (`initial → loadingLocation → locationReady → pointsUpdated → optimizing → optimizedSuccess | optimizedFailure`). State is immutable with `copyWith`.

**Failures, not exceptions.** Repository methods return `ApiResult<T>` (`ApiSuccess` / `ApiFailure`). Datasources throw typed `*Exception`s; the repo converts them into `Failure`s for the UI. Dio errors never leak past the data layer.

**Dependency injection.** `GetIt` registers singletons for Dio clients, data sources, and the repository, and a factory for the cubit. Wired in `core/di/service_locator.dart`.

**Networking.** Two Dio instances (one per remote): the AI client carries `X-API-Key` and base URL by default; the Directions client adds `key` per request. A `pretty_dio_logger` interceptor is attached only in debug.

**RTL.** Locked to Arabic + RTL in `app.dart`. All copy lives in `core/constants/app_constants.dart` so swapping in an `easy_localization` pipeline later is just a table lookup.

---

## 🛡️ Error Handling

Friendly Arabic messages cover:
- موقع المستخدم — قياس متعذر / إذن مرفوض / GPS مغلق
- خادم الذكاء الاصطناعي — مهلة، خطأ، استجابة غير صالحة
- مفتاح Google Maps مفقود (شريط تحذير علوي + شاشة الإعدادات)
- اتصال إنترنت مفقود (`InternetAddress.lookup`)
- أقل من نقطتين قبل الضغط على «تحسين المسار»

---

## 📦 Packages

| Use | Package |
| --- | --- |
| State | `flutter_bloc`, `bloc`, `equatable` |
| DI | `get_it` |
| Networking | `dio`, `pretty_dio_logger` |
| Env | `flutter_dotenv` |
| Map / Location | `google_maps_flutter`, `geolocator`, `geocoding`, `permission_handler`, `flutter_polyline_points` |
| UI | `flutter_screenutil`, `iconsax`, `intl`, `flutter_easyloading`, `flutter_svg`, `shimmer` |

---

## 🧪 Reproducing the API test

The folder `C:\Users\moham\OneDrive\Desktop\api_test` contains a Python script you can run end-to-end:

```bash
pip install requests
python test_25_orders.py
```

It posts `25_orders.json` to the production endpoint and prints the optimized itinerary. The Flutter app sends an equivalent payload.

---

## 🧭 User Flow

```
Splash
  ↓
RoutePlanner (map open)
  ↓ tap on map
add depot → add stops → reorder / rename / delete
  ↓
"تحسين المسار" button
  ↓
Loading overlay → AI VRP → Directions API
  ↓
Results sheet
  • metric grid (وقت / مسافة / توفير / وقود)
  • toggle: ذهاب · المسار الكامل · العودة
  • optimized order list
  • "بدء مسار جديد" → reset
```
