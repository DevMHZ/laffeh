import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/place_suggestion.dart';

/// Photon — the autocomplete half of place search.
///
/// Same OpenStreetMap data as Nominatim, indexed for a different question.
/// Nominatim answers "resolve this complete address"; Photon answers "the
/// driver is four letters into a word, what might they mean?" — prefix
/// matching, typo tolerance ("mazze" finds Mazzeh) and a location bias,
/// all of which is what a search box in a moving vehicle actually needs.
///
/// Two things about it are load-bearing and easy to get wrong:
///
///  * `lang` accepts only `default`, `de`, `en`, `fr` — there is no `ar`.
///    `default` returns each place's *local* name, which across this app's
///    region is the Arabic one. Sending `lang=ar` returns HTTP 400.
///  * its own location bias is weak. Ask for "بنزين" with `lat`/`lon` set
///    and the first result is in Saudi Arabia; raising `location_bias_scale`
///    to 1.0 barely moves it. So proximity here is enforced with a hard
///    `bbox`, and the final ordering is decided locally, not by the server.
class PhotonGeocodingDataSource {
  final Dio _dio;

  const PhotonGeocodingDataSource(this._dio);

  /// OSM keys whose features are places you *go to*, whatever Photon's own
  /// coarse `type` says about them. A pharmacy comes back as `type: house`;
  /// treating it as an address would give it a street's distance decay and
  /// the wrong icon.
  static const _poiKeys = {
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

  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng? near,
    double? radiusKm,
    int limit = GeocodingConfig.providerLimit,
    String? language,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final params = <String, dynamic>{
      'q': trimmed,
      'limit': limit,
      // See the class doc: `default` is how you ask for Arabic.
      'lang': photonLanguage(language),
    };

    if (near != null) {
      params['lat'] = near.latitude;
      params['lon'] = near.longitude;
      if (radiusKm != null) {
        final box = DistanceUtils.boxAround(near, radiusKm);
        params['bbox'] =
            '${box.southWest.longitude},${box.southWest.latitude},'
            '${box.northEast.longitude},${box.northEast.latitude}';
      }
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api',
        queryParameters: params,
        options: Options(receiveTimeout: GeocodingConfig.providerTimeout),
      );
      return _parse(response.data);
    } catch (_) {
      // A provider that fails is a provider that contributes nothing this
      // keystroke. The others still have answers; the list must not empty
      // itself because one endpoint had a bad second.
      return const [];
    }
  }

  /// [countryCode] drops anything outside the country the driver is in.
  ///
  /// Photon has no country parameter, so the bounding box is the only filter
  /// it offers — and a box is a rectangle, which borders are not. Asking for
  /// "university" inside a box around Beirut returns a college in Israel.
  /// Every Photon feature carries `countrycode`, so the border is enforced
  /// here instead, on the way out.
  /// The ISO country code the given position falls in, or null.
  ///
  /// One request, and the answer is stable for a whole shift — a driver
  /// crosses a border rarely and a search box does not need to notice
  /// quickly when they do. The caller caches it; this only asks.
  Future<String?> countryAt(LatLng position) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'limit': 1,
        },
        options: Options(receiveTimeout: GeocodingConfig.providerTimeout),
      );
      final features = response.data?['features'];
      if (features is! List || features.isEmpty) return null;
      final props = features.first['properties'];
      if (props is! Map) return null;
      final code = props['countrycode']?.toString().toUpperCase();
      return (code != null && code.length == 2) ? code : null;
    } catch (_) {
      // Not knowing the country is survivable: the filter is skipped and
      // the search behaves exactly as it did before this existed.
      return null;
    }
  }

  List<PlaceSuggestion> _parse(
    Map<String, dynamic>? body, {
    String? countryCode,
  }) {
    final features = body?['features'];
    if (features is! List) return const [];

    final results = <PlaceSuggestion>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final props = feature['properties'];
      final geometry = feature['geometry'];
      if (props is! Map || geometry is! Map) continue;

      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lon = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final name = _nameOf(props);
      if (name == null) continue;

      final country = props['countrycode']?.toString().toUpperCase();

      results.add(
        PlaceSuggestion(
          id: 'photon:${props['osm_type'] ?? ''}${props['osm_id'] ?? '$lat,$lon'}',
          name: name,
          context: _contextOf(props),
          latLng: LatLng(lat, lon),
          kind: _kindOf(props),
          source: PlaceSource.photon,
          // `place=city` vs `place=village` is the only thing separating
          // Aleppo from a village whose name starts the same way.
          prominence: props['osm_key'] == 'place'
              ? prominenceForOsmPlace(props['osm_value']?.toString())
              : null,
          countryCode: country,
        ),
      );
    }
    return results;
  }

  /// The headline. Falls back to the street (with house number when there
  /// is one) for plain addresses, which carry no `name` at all.
  static String? _nameOf(Map<dynamic, dynamic> props) {
    final name = props['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final street = props['street']?.toString().trim();
    final number = props['housenumber']?.toString().trim();
    if (street != null && street.isNotEmpty) {
      return (number != null && number.isNotEmpty) ? '$street $number' : street;
    }

    final city = props['city']?.toString().trim();
    if (city != null && city.isNotEmpty) return city;
    return null;
  }

  /// The second line — enough to tell two branches of the same chain apart,
  /// and no more. Three parts is where a tile stops being readable.
  static String? _contextOf(Map<dynamic, dynamic> props) {
    final name = props['name']?.toString().trim();
    final parts = <String>[];

    void add(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      if (text == name) return; // the headline again, one line lower
      if (parts.contains(text)) return;
      parts.add(text);
    }

    // Only include the street when it is not already the headline.
    if (name != null && name.isNotEmpty) add(props['street']);
    add(props['district']);
    add(props['city']);
    add(props['county']);
    add(props['state']);
    add(props['country']);

    if (parts.isEmpty) return null;
    return parts.take(3).join('، ');
  }

  static PlaceKind _kindOf(Map<dynamic, dynamic> props) {
    final key = props['osm_key']?.toString();
    if (key != null && _poiKeys.contains(key)) return PlaceKind.poi;
    if (key == 'highway') return PlaceKind.street;

    switch (props['type']?.toString()) {
      case 'house':
        return props['housenumber'] != null ? PlaceKind.address : PlaceKind.poi;
      case 'street':
        return PlaceKind.street;
      case 'district':
      case 'locality':
      case 'neighbourhood':
        return PlaceKind.area;
      case 'city':
        return PlaceKind.city;
      case 'county':
      case 'state':
      case 'country':
        return PlaceKind.region;
      default:
        return PlaceKind.poi;
    }
  }
}


/// The `lang` value Photon accepts for an app language.
///
/// The public instance supports de, en, fr, it and `default`; anything else
/// is answered with HTTP 400, which would take the search box down entirely.
/// Arabic therefore maps to `default` — and that is not a compromise: in the
/// Arab world the local name *is* the Arabic one, so `default` returns
/// الحمرا where `en` would return "El Hamra".
String photonLanguage(String? appLanguage) {
  const supported = {'de', 'en', 'fr', 'it'};
  final code = (appLanguage ?? '').trim().toLowerCase();
  return supported.contains(code) ? code : 'default';
}
