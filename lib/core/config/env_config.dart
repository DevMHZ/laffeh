import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static String _read(String key, {String fallback = ''}) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  static String get aiRouteBaseUrl => _read(
    'AI_ROUTE_BASE_URL',
    fallback: 'https://back.laffa.afdal.tech/api/v1',
  );

  /// No fallback on purpose. A key checked into the repository is a key
  /// anyone can read, and this one was public long enough to be treated as
  /// compromised. An unset key now fails loudly at the first request rather
  /// than quietly signing traffic with a shared default.
  ///
  /// Note this is an *identifier*, not a secret: `.env` is bundled as an
  /// asset, so whatever is here ships inside the APK and can be read out of
  /// it. Rate limits and quotas on the server are what actually protect the
  /// API — see the `limit` field on each key.
  static String get aiRouteApiKey => _read('AI_ROUTE_API_KEY');

  static String get mapStyleUrl => _read(
    'MAP_STYLE_URL',
    fallback: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static String get nominatimBaseUrl => _read(
    'NOMINATIM_BASE_URL',
    fallback: 'https://nominatim.openstreetmap.org',
  );

  /// Photon — the autocomplete geocoder. The public komoot instance is free
  /// and needs no key, but it is a courtesy service under fair use: point
  /// this at your own instance (or a mirror) before the fleet grows.
  static String get photonBaseUrl =>
      _read('PHOTON_BASE_URL', fallback: 'https://photon.komoot.io');

  /// Overpass — queries OSM by tag, which is how the search finds the fuel
  /// stations nobody named "بنزين". Also a shared community service; the
  /// app only calls it for category queries, on a long debounce.
  static String get overpassBaseUrl =>
      _read('OVERPASS_BASE_URL', fallback: 'https://overpass-api.de');

  // ── Supabase (Auth + Database) ─────────────────────────
  static String get supabaseUrl => _read('SUPABASE_URL');

  /// The anon / publishable key. Never the service_role key.
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  /// True only when both Supabase values are present. Everything auth /
  /// location-tracking related is a no-op until this is configured, so the
  /// rest of the app keeps running without a backend.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
