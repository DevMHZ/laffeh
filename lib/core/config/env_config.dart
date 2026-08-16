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

  static String get aiRouteApiKey =>
      _read('AI_ROUTE_API_KEY', fallback: 'test-key-001');

  static String get mapStyleUrl => _read(
    'MAP_STYLE_URL',
    fallback: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static String get nominatimBaseUrl => _read(
    'NOMINATIM_BASE_URL',
    fallback: 'https://nominatim.openstreetmap.org',
  );

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
