import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A single forward-geocoding match: a human-readable name plus its
/// coordinate. Returned by [OsmGeocodingDataSource.searchAddresses] so the
/// user can pick the right place from a list when typing an address.
class GeoSearchResult {
  final String name;
  final LatLng latLng;
  const GeoSearchResult({required this.name, required this.latLng});
}

/// Geocoding backed by a Nominatim-compatible OpenStreetMap API.
///
/// The default endpoint is the public OSM Nominatim service. For production
/// volume, point `NOMINATIM_BASE_URL` at a hosted provider or self-hosted
/// Nominatim instance so the app is not dependent on the community server.
class OsmGeocodingDataSource {
  final Dio _dio;

  const OsmGeocodingDataSource(this._dio);

  /// Forward-geocode: text query → first matching coordinate, or `null`.
  Future<LatLng?> searchAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'format': 'jsonv2',
          'q': trimmed,
          'limit': 1,
          'accept-language': 'ar,en',
        },
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      final first = data.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  /// Forward-geocode returning up to [limit] matches so the caller can show
  /// a pick-one list. Empty on no match or any error.
  Future<List<GeoSearchResult>> searchAddresses(
    String query, {
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'format': 'jsonv2',
          'q': trimmed,
          'limit': limit,
          'addressdetails': 1,
          'accept-language': 'ar,en',
        },
      );
      final data = response.data;
      if (data == null) return const [];
      final results = <GeoSearchResult>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;
        final name = item['display_name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        results.add(GeoSearchResult(name: name, latLng: LatLng(lat, lon)));
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> reverseAddress(LatLng point) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': point.latitude,
          'lon': point.longitude,
          'zoom': 18,
          'addressdetails': 1,
          'accept-language': 'ar',
        },
      );

      final data = response.data;
      if (data == null) return null;

      final address = data['address'];
      if (address is Map<String, dynamic>) {
        final parts =
            [
                  address['road'],
                  address['neighbourhood'],
                  address['suburb'],
                  address['city_district'],
                  address['city'],
                  address['town'],
                  address['village'],
                ]
                .whereType<String>()
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toSet()
                .take(3)
                .toList();

        if (parts.isNotEmpty) return parts.join('، ');
      }

      final displayName = data['display_name']?.toString().trim();
      if (displayName == null || displayName.isEmpty) return null;
      return displayName
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .take(3)
          .join('، ');
    } catch (_) {
      return null;
    }
  }
}
