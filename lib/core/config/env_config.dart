import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Type-safe accessor over the `.env` file.
///
/// Loaded once from `main.dart` via [dotenv.load]. After loading,
/// any module can read values through this class instead of
/// reaching into [dotenv.env] directly.
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

  static String get mapStyleUrl =>
      _read('MAP_STYLE_URL', fallback: 'https://tiles.openfreemap.org/styles/liberty');

  static String get nominatimBaseUrl => _read(
    'NOMINATIM_BASE_URL',
    fallback: 'https://nominatim.openstreetmap.org',
  );
}
