import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../domain/entities/place_suggestion.dart';
import 'place_category_lexicon.dart';

/// Overpass — the "everything of this kind, around here" source.
///
/// This is the answer to the complaint that the search knows too few
/// places. Text search can only find what somebody wrote a matching name
/// for, and around Damascus not one fuel station is called "بنزين" — they
/// are "كازية دمر", "محطة الجد", "كازية القصور", or nothing at all. A text
/// index has no path from the word to the pin. Overpass does: it queries
/// OSM by *tag*, so `amenity=fuel` within six kilometres returns all twelve
/// of them, unnamed ones included, and does it for free with no key.
///
/// It is not a general search — you cannot ask it "شارع الثورة" — so it
/// runs only when [PlaceCategoryLexicon] recognises the query as a kind of
/// place, and it runs on a longer debounce than the text providers because
/// each call is a real database query against a shared community server.
class OverpassPoiDataSource {
  final Dio _dio;

  const OverpassPoiDataSource(this._dio);

  /// Every [category] feature within [radiusKm] of [near].
  Future<List<PlaceSuggestion>> nearby(
    PlaceCategory category, {
    required LatLng near,
    required double radiusKm,
    required String categoryLabel,
    int limit = GeocodingConfig.providerLimit,
  }) async {
    final radiusMeters = (radiusKm * 1000).round();
    final lat = near.latitude.toStringAsFixed(6);
    final lon = near.longitude.toStringAsFixed(6);

    // `nwr` covers nodes, ways and relations in one clause — a fuel station
    // is a node in one town and a building outline in the next, and the
    // driver does not care which. `out center` collapses the ways and
    // relations to a single coordinate so everything arrives as a pin.
    final clauses = category.tags
        .map((tag) {
          final parts = tag.split('=');
          if (parts.length != 2) return '';
          return 'nwr["${parts[0]}"="${parts[1]}"]'
              '(around:$radiusMeters,$lat,$lon);';
        })
        .where((c) => c.isNotEmpty)
        .join();
    if (clauses.isEmpty) return const [];

    final query =
        '[out:json][timeout:${GeocodingConfig.categoryTimeout.inSeconds}];'
        '($clauses);'
        'out center ${limit * 2};';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/interpreter',
        data: {'data': query},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          receiveTimeout: GeocodingConfig.categoryTimeout,
        ),
      );
      return _parse(response.data, categoryLabel: categoryLabel);
    } catch (_) {
      // Overpass is a shared community service and will occasionally say no.
      // The text results are already on screen; this source only ever adds.
      return const [];
    }
  }

  List<PlaceSuggestion> _parse(
    Map<String, dynamic>? body, {
    required String categoryLabel,
  }) {
    final elements = body?['elements'];
    if (elements is! List) return const [];

    final results = <PlaceSuggestion>[];
    for (final element in elements) {
      if (element is! Map) continue;

      final center = element['center'];
      final lat =
          (element['lat'] as num?)?.toDouble() ??
          (center is Map ? (center['lat'] as num?)?.toDouble() : null);
      final lon =
          (element['lon'] as num?)?.toDouble() ??
          (center is Map ? (center['lon'] as num?)?.toDouble() : null);
      if (lat == null || lon == null) continue;

      final tags = element['tags'];
      final tagMap = tags is Map ? tags : const {};

      results.add(
        PlaceSuggestion(
          id: 'overpass:${element['type'] ?? ''}${element['id'] ?? '$lat,$lon'}',
          // An unnamed station is still a station the driver can pull into,
          // so it is listed under what it *is* rather than dropped.
          name: _nameOf(tagMap) ?? categoryLabel,
          context: _contextOf(tagMap, categoryLabel: categoryLabel),
          latLng: LatLng(lat, lon),
          kind: PlaceKind.poi,
          source: PlaceSource.overpass,
        ),
      );
    }
    return results;
  }

  static String? _nameOf(Map<dynamic, dynamic> tags) {
    for (final key in const ['name:ar', 'name', 'brand', 'operator']) {
      final value = tags[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _contextOf(
    Map<dynamic, dynamic> tags, {
    required String categoryLabel,
  }) {
    final parts = <String>[];

    void add(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || parts.contains(text)) return;
      parts.add(text);
    }

    // Naming the category on every tile is what makes a list of unfamiliar
    // shop names readable: "الجد" means nothing, "الجد — محطة وقود" does.
    add(categoryLabel);
    add(tags['addr:street']);
    add(tags['addr:suburb']);
    add(tags['addr:city']);

    if (parts.isEmpty) return null;
    return parts.take(3).join('، ');
  }
}
