import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/place_suggestion.dart';

/// Nominatim — the address half of place search, plus reverse geocoding.
///
/// It is the weaker of the two text providers at autocomplete (no typo
/// tolerance, no prefix matching worth the name) and its default ranking is
/// the reason this whole subsystem exists: asked for "صيدلية" it answers
/// with a pharmacy in Istanbul, because relevance to it means textual
/// relevance to the planet. Confined to a `viewbox` with `bounded=1` it
/// becomes something else entirely — the same query comes back as six
/// pharmacies in Damascus — and it remains better than Photon at complete,
/// structured addresses with house numbers.
///
/// So it stays, on two conditions: it is always given a box to search in,
/// and it is never the only source. It is also asked less often than the
/// autocomplete provider — the public instance is a community service with
/// a one-request-per-second ceiling, and a request per keystroke would
/// abuse it. Point `NOMINATIM_BASE_URL` at your own instance for volume.
class OsmGeocodingDataSource {
  final Dio _dio;

  const OsmGeocodingDataSource(this._dio);

  static const _poiCategories = {
    'amenity',
    'shop',
    'tourism',
    'leisure',
    'healthcare',
    'office',
    'craft',
    'emergency',
    'aeroway',
    'railway',
  };

  /// Forward-geocode with an optional locality bias.
  ///
  /// When [near] and [radiusKm] are both given the search is *bounded* to
  /// that box — results outside it are not returned at all. That is
  /// deliberate: a soft bias here does not survive a generic query, and a
  /// result 900 km away is never the answer to a question typed by someone
  /// who has to drive there today. The caller widens the ring, or drops it,
  /// when a bounded pass comes back thin.
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng? near,
    double? radiusKm,
    String? countryCode,
    String? language,
    int limit = GeocodingConfig.providerLimit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final params = <String, dynamic>{
      'format': 'jsonv2',
      'q': trimmed,
      'limit': limit,
      'addressdetails': 1,
      'accept-language': acceptLanguage(language),
    };

    if (near != null && radiusKm != null) {
      final box = DistanceUtils.boxAround(near, radiusKm);
      params['viewbox'] =
          '${box.southWest.longitude},${box.southWest.latitude},'
          '${box.northEast.longitude},${box.northEast.latitude}';
      params['bounded'] = 1;
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      params['countrycodes'] = countryCode.toLowerCase();
    }

    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: params,
        options: Options(receiveTimeout: GeocodingConfig.providerTimeout),
      );
      return _parse(response.data);
    } catch (_) {
      return const [];
    }
  }

  /// Forward-geocode a single locator to one coordinate — the import path
  /// (a pasted list, a CSV column), where there is no one to pick from a
  /// list and the best guess has to do. Biased when the caller knows where
  /// the round is, since an imported "شارع بغداد" means the one in this
  /// city.
  Future<LatLng?> searchAddress(String query, {LatLng? near}) async {
    final results = await search(
      query,
      near: near,
      radiusKm: near == null ? null : GeocodingConfig.regionRadiusKm,
      limit: 1,
    );
    if (results.isNotEmpty) return results.first.latLng;

    // Bounded search found nothing — the address may simply be elsewhere.
    if (near == null) return null;
    final unbounded = await search(query, limit: 1);
    return unbounded.isEmpty ? null : unbounded.first.latLng;
  }

  List<PlaceSuggestion> _parse(List<dynamic>? data) {
    if (data == null) return const [];

    final results = <PlaceSuggestion>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) continue;

      final display = item['display_name']?.toString().trim() ?? '';
      final segments = display
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      var name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        if (segments.isEmpty) continue;
        name = segments.first;
      }

      final context = segments.where((s) => s != name).take(3).join('، ');

      results.add(
        PlaceSuggestion(
          id: 'nominatim:${item['osm_type'] ?? ''}${item['osm_id'] ?? '$lat,$lon'}',
          name: name,
          context: context.isEmpty ? null : context,
          latLng: LatLng(lat, lon),
          kind: _kindOf(item),
          source: PlaceSource.nominatim,
          prominence: item['category'] == 'place'
              ? prominenceForOsmPlace(item['type']?.toString())
              : null,
        ),
      );
    }
    return results;
  }

  static PlaceKind _kindOf(Map<String, dynamic> item) {
    final category = item['category']?.toString();
    if (category != null && _poiCategories.contains(category)) {
      return PlaceKind.poi;
    }
    if (category == 'highway') return PlaceKind.street;

    switch (item['addresstype']?.toString()) {
      case 'road':
      case 'pedestrian':
        return PlaceKind.street;
      case 'house':
      case 'building':
      case 'house_number':
        return PlaceKind.address;
      case 'suburb':
      case 'neighbourhood':
      case 'quarter':
      case 'city_district':
      case 'district':
      case 'hamlet':
        return PlaceKind.area;
      case 'city':
      case 'town':
      case 'village':
      case 'municipality':
        return PlaceKind.city;
      case 'state':
      case 'province':
      case 'county':
      case 'region':
      case 'country':
        return PlaceKind.region;
      default:
        return PlaceKind.poi;
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

  /// The ISO country code the driver is standing in, or null. Used to keep
  /// a widened search from crossing a border it has no reason to cross.
  Future<String?> countryCodeAt(LatLng point) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': point.latitude,
          'lon': point.longitude,
          'zoom': 5,
          'addressdetails': 1,
        },
      );
      final address = response.data?['address'];
      if (address is! Map) return null;
      final code = address['country_code']?.toString().trim();
      return (code == null || code.isEmpty) ? null : code;
    } catch (_) {
      return null;
    }
  }
}


/// The `accept-language` Nominatim should answer in.
///
/// Unlike Photon, Nominatim takes any BCP 47 tag, so the app's language goes
/// through as-is. English trails it as a fallback for places that carry no
/// name in the requested language; without that a driver gets a blank line
/// rather than a name they merely cannot read.
String acceptLanguage(String? appLanguage) {
  final code = (appLanguage ?? '').trim().toLowerCase();
  if (code.isEmpty) return 'en';
  return code == 'en' ? 'en' : '$code,en';
}
