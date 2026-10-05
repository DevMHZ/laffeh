import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// A Google prediction has no coordinates until the user selects it.
class GooglePlacePrediction {
  final String placeId;
  final String name;
  final String context;

  const GooglePlacePrediction({
    required this.placeId,
    required this.name,
    required this.context,
  });

  String get fullLabel => context.isEmpty ? name : '$name, $context';
}

class GoogleGeocodedPlace {
  final LatLng point;
  final String label;
  final String? placeId;

  const GoogleGeocodedPlace(this.point, this.label, this.placeId);
}

/// The app never receives the Google credential. A fallback response, a
/// timeout, or any malformed result leaves the existing OSM path in charge.
class GoogleMobilePlacesDataSource {
  final Dio _dio;

  GoogleMobilePlacesDataSource(this._dio);

  Future<List<GooglePlacePrediction>> autocomplete(
    String query, {
    LatLng? near,
    String language = 'en',
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/mobile/places/autocomplete',
        queryParameters: {
          'q': query,
          'language': _language(language),
          if (near != null) 'lat': near.latitude,
          if (near != null) 'lon': near.longitude,
        },
      );
      final data = response.data;
      if (data?['provider'] != 'google' || data?['predictions'] is! List) {
        return const [];
      }
      return (data!['predictions'] as List)
          .whereType<Map>()
          .map(
            (item) => GooglePlacePrediction(
              placeId: item['place_id']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              context: item['context']?.toString() ?? '',
            ),
          )
          .where((item) => item.placeId.isNotEmpty && item.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<GoogleGeocodedPlace?> geocode(
    String query, {
    String language = 'en',
  }) => _lookup('/api/mobile/places/geocode', {
    'q': query,
    'language': _language(language),
  });

  Future<GoogleGeocodedPlace?> resolve(
    String placeId, {
    String language = 'en',
  }) => _lookup('/api/mobile/places/resolve', {
    'place_id': placeId,
    'language': _language(language),
  });

  Future<GoogleGeocodedPlace?> _lookup(
    String path,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: params,
      );
      final data = response.data;
      if (data?['provider'] != 'google' || data?['result'] is! Map) {
        return null;
      }
      final result = data!['result'] as Map;
      final lat = result['lat'];
      final lon = result['lon'];
      if (lat is! num ||
          lon is! num ||
          !lat.toDouble().isFinite ||
          !lon.toDouble().isFinite ||
          lat < -90 ||
          lat > 90 ||
          lon < -180 ||
          lon > 180) {
        return null;
      }
      return GoogleGeocodedPlace(
        LatLng(lat.toDouble(), lon.toDouble()),
        result['label']?.toString() ?? '',
        result['place_id']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _language(String value) =>
      const {'en', 'fr', 'ar'}.contains(value) ? value : 'en';
}
