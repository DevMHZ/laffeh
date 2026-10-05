import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnvConfig {
  EnvConfig._();

  static String? _accountUrl;
  static String? _accountKey;

  /// The API owns the account-service cutover. A newly installed app can use
  /// the managed service until the final sync and switch to Hostinger on its
  /// next launch, without another store release. Cache the last good answer
  /// so a temporary config outage does not change a driver's account target.
  static Future<void> loadAccountConfig(
    SharedPreferences prefs, {
    Dio? client,
  }) async {
    const urlKey = 'account_service_url_v1';
    const anonKey = 'account_service_anon_key_v1';
    bool valid(String? url, String? key) {
      final parsed = Uri.tryParse(url ?? '');
      return parsed != null &&
          parsed.scheme == 'https' &&
          parsed.host.isNotEmpty &&
          parsed.userInfo.isEmpty &&
          parsed.query.isEmpty &&
          parsed.fragment.isEmpty &&
          (parsed.path.isEmpty || parsed.path == '/') &&
          key != null &&
          key.isNotEmpty &&
          !key.startsWith('sb_secret_');
    }

    final cachedUrl = prefs.getString(urlKey);
    final cachedKey = prefs.getString(anonKey);
    if (valid(cachedUrl, cachedKey)) {
      _accountUrl = cachedUrl;
      _accountKey = cachedKey;
    }
    final requestClient = client ?? Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );
    try {
      final response = await requestClient.get<Map<String, dynamic>>(
        '${dispatchBaseUrl.replaceAll(RegExp(r'/+$'), '')}/api/mobile/account-config',
      );
      final url = response.data?['url'] as String?;
      final key = response.data?['anon_key'] as String?;
      if (valid(url, key)) {
        _accountUrl = url!.replaceAll(RegExp(r'/+$'), '');
        _accountKey = key;
        await prefs.setString(urlKey, _accountUrl!);
        await prefs.setString(anonKey, _accountKey!);
      }
    } catch (_) {
      // First launch falls back to the bundled managed-service settings.
    } finally {
      if (client == null) requestClient.close(force: true);
    }
  }

  static String get dispatchBaseUrl {
    const localOverride = String.fromEnvironment('DISPATCH_BASE_URL');
    if (kDebugMode && localOverride.isNotEmpty) return localOverride;
    return _read(
      'DISPATCH_BASE_URL',
      fallback: 'https://back.laffa.afdal.tech',
    );
  }

  static String _read(String key, {String fallback = ''}) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  static String get aiRouteBaseUrl => _read(
    'MOBILE_ROUTE_BASE_URL',
    fallback: 'https://back.laffa.afdal.tech/api/mobile',
  );

  /// Publishable ID for the bounded, single-driver routing service. This is
  /// intentionally public and cannot authorize B2B, tracking or account APIs.
  /// Server policy: vrp-saas-osm/backend/mobile_access.py.
  static const String laffaMobileAppKey =
      'laffa_mobile_public_AgViki7W0zE-EYCuxqgBa9wlCgxfTWd4';

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
  static String get supabaseUrl => _accountUrl ?? _read('SUPABASE_URL');

  /// The anon / publishable key. Never the service_role key.
  static String get supabaseAnonKey =>
      _accountKey ?? _read('SUPABASE_ANON_KEY');

  /// True only when both Supabase values are present. Everything auth /
  /// location-tracking related is a no-op until this is configured, so the
  /// rest of the app keeps running without a backend.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
