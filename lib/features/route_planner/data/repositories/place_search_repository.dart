import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/link_parser.dart';
import '../../domain/entities/place_suggestion.dart';
import '../datasources/osm_geocoding_datasource.dart';
import '../datasources/overpass_poi_datasource.dart';
import '../datasources/photon_geocoding_datasource.dart';
import '../datasources/place_category_lexicon.dart';
import '../datasources/recent_places_local_datasource.dart';
import 'place_search_ranker.dart';

/// One search box, five sources, one ranked list.
///
/// The old search was a single unbiased Nominatim call, and it failed the
/// driver twice over: it put far-away places first (ask for "صيدلية" from
/// Damascus and the first hit is in Istanbul), and it knew too few places
/// (ask for "بنزين" and it finds none of the twelve fuel stations within
/// six kilometres, because every one of them is called "كازية"). Neither
/// is fixable by swapping one geocoder for another — they are two
/// different failures. This class fixes both:
///
///  * **near first** — every provider is confined to a box around the
///    driver, and whatever comes back is re-ordered locally by distance,
///    text match and kind. Provider order is discarded.
///  * **more places** — a query the [PlaceCategoryLexicon] recognises as a
///    *kind* of place is also answered by tag, straight out of OSM, so an
///    unnamed station on a back road is as findable as a chain.
///
/// Results arrive as a stream rather than a future. The fast provider
/// answers in a few hundred milliseconds and the driver sees a list; the
/// slower ones fold in a beat later. Waiting for the slowest source before
/// showing anything is how a search box comes to feel broken.
class PlaceSearchRepository {
  final PhotonGeocodingDataSource _photon;
  final OsmGeocodingDataSource _nominatim;
  final OverpassPoiDataSource _overpass;
  final RecentPlacesLocalDataSource _recents;

  PlaceSearchRepository({
    required PhotonGeocodingDataSource photon,
    required OsmGeocodingDataSource nominatim,
    required OverpassPoiDataSource overpass,
    required RecentPlacesLocalDataSource recents,
  }) : _photon = photon,
       _nominatim = nominatim,
       _overpass = overpass,
       _recents = recents;

  final _cache = <String, _CacheEntry>{};

  /// Places the driver picked before, newest first — the list the sheet
  /// shows before a single letter is typed.
  List<PlaceSuggestion> recentPlaces({LatLng? near}) {
    final recents = _recents
        .read()
        .take(GeocodingConfig.recentsOnEmptyQuery)
        .toList();
    if (near == null) return recents;
    // Left in recency order on purpose — this list answers "where was I
    // last?", not "what is closest?". Each row still gets its distance,
    // because that number is how the driver tells one warehouse from the
    // other when both are called the warehouse.
    return recents
        .map(
          (place) => place.copyWith(
            distanceKm: DistanceUtils.haversineKm(near, place.latLng),
          ),
        )
        .toList();
  }

  Future<void> remember(PlaceSuggestion place) => _recents.remember(place);

  /// Search, emitting progressively better lists.
  ///
  /// [near] is where the driver is (or, failing a fix, what the map is
  /// looking at). [routePoints] are the stops already planned — offered
  /// because "back to the depot" is a real destination and should not need
  /// a round trip to a server.
  Stream<List<PlaceSuggestion>> search(
    String query, {
    LatLng? near,
    List<PlaceSuggestion> routePoints = const [],
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // ── Pasted coordinates or a map link ───────────────────
    // Unambiguous: the driver has already told us exactly where. Answer it
    // and stop, rather than sending a URL to a geocoder that will make
    // something up.
    final pasted =
        LinkParser.tryParseMapUrl(trimmed) ??
        LinkParser.parseLatLngPair(trimmed);
    if (pasted != null) {
      yield [
        PlaceSuggestion(
          id: 'coord:${pasted.latitude},${pasted.longitude}',
          name: AppStrings.searchPastedCoordinates,
          context:
              '${pasted.latitude.toStringAsFixed(5)}, '
              '${pasted.longitude.toStringAsFixed(5)}',
          latLng: pasted,
          kind: PlaceKind.coordinate,
          source: PlaceSource.coordinate,
        ),
      ];
      return;
    }

    if (trimmed.length < GeocodingConfig.minQueryLength) return;

    final cacheKey = _cacheKey(trimmed, near);
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isStale) {
      yield cached.results;
      return;
    }

    // ── Local candidates, free and instant ─────────────────
    final local = [
      ..._recents.read(),
      ...routePoints,
    ].where((p) => PlaceSearchRanker.matchesQuery(p, trimmed)).toList();

    if (local.isNotEmpty) {
      yield PlaceSearchRanker.rank(local, query: trimmed, near: near);
    }

    // What kind of question is this? A query naming a *category* ("بنزين")
    // is always a question about here, and is answered by tag below; a
    // query naming a *place* ("حلب") may well be about somewhere far away.
    // The two get different search ladders.
    final category = PlaceCategoryLexicon.match(trimmed);

    // ── Pass 1: the fast provider, confined to the working area ──
    final pool = <PlaceSuggestion>[...local];
    pool.addAll(
      await _photon.search(
        trimmed,
        near: near,
        radiusKm: near == null ? null : GeocodingConfig.nearRadiusKm,
      ),
    );

    // Did the working area actually answer the question? Not "did it return
    // rows" — a ring around Damascus fills up happily with حلبون, حلبتا and
    // حلبا when the driver typed حلب, and none of those is Aleppo. It
    // answered only if something in it carries the name that was typed.
    final answeredNearby =
        pool.length - local.length >= GeocodingConfig.widenBelowResults &&
        pool.any((p) => PlaceSearchRanker.isExactMatch(p, trimmed));

    var nominatimRadiusKm = GeocodingConfig.nearRadiusKm;

    if (near != null && !answeredNearby) {
      nominatimRadiusKm = GeocodingConfig.regionRadiusKm;

      // Both wider rings at once rather than one-then-maybe-the-other. The
      // sequential version looks thriftier and is worse: the region ring
      // finds *an* exact match — a residential street in Irbid also called
      // حلب — declares victory, and the city three hundred kilometres away
      // is never fetched at all. One extra request buys the right answer,
      // and it is only spent when the near ring already came up short.
      final wider = await Future.wait([
        _photon.search(
          trimmed,
          near: near,
          radiusKm: GeocodingConfig.regionRadiusKm,
        ),
        // No box at all — but only for a query that names something. A
        // driver asking for fuel is not asking about a station in Yanbu,
        // and letting a category query go global fills the list with
        // far-away text matches that can never be the answer.
        if (category == null)
          _photon.search(trimmed, near: near)
        else
          Future.value(const <PlaceSuggestion>[]),
      ]);
      for (final batch in wider) {
        pool.addAll(batch);
      }
    }

    if (pool.isNotEmpty) {
      yield PlaceSearchRanker.rank(pool, query: trimmed, near: near);
    }

    // ── Pass 2: the slower sources, in parallel ────────────
    // They only ever add to a list that is already on screen, so they are
    // allowed to take their time and to fail without anyone noticing.
    final topUps = await Future.wait([
      _nominatim.search(
        trimmed,
        near: near,
        radiusKm: near == null ? null : nominatimRadiusKm,
      ),
      if (category != null && near != null)
        _categorySweep(category, near: near)
      else
        Future.value(const <PlaceSuggestion>[]),
    ]);

    for (final batch in topUps) {
      pool.addAll(batch);
    }

    final ranked = PlaceSearchRanker.rank(pool, query: trimmed, near: near);
    _store(cacheKey, ranked);
    yield ranked;
  }

  /// Every place of a kind around the driver, widening once if the tight
  /// sweep found almost nothing — a rural round has the same right to find
  /// its nearest pharmacy as a city one.
  Future<List<PlaceSuggestion>> _categorySweep(
    PlaceCategory category, {
    required LatLng near,
  }) async {
    final label = AppStrings.placeCategoryLabel(category.labelKey);
    final tight = await _overpass.nearby(
      category,
      near: near,
      radiusKm: GeocodingConfig.categoryRadiusKm,
      categoryLabel: label,
    );
    if (tight.length >= GeocodingConfig.widenBelowResults) return tight;

    final wide = await _overpass.nearby(
      category,
      near: near,
      radiusKm: GeocodingConfig.categoryWideRadiusKm,
      categoryLabel: label,
    );
    return wide.isEmpty ? tight : wide;
  }

  /// One best coordinate for a locator that nobody is going to pick from a
  /// list — the WhatsApp / CSV import path.
  Future<LatLng?> resolveOne(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final pasted =
        LinkParser.tryParseMapUrl(trimmed) ??
        LinkParser.parseLatLngPair(trimmed);
    if (pasted != null) return pasted;

    final photon = await _photon.search(
      trimmed,
      near: near,
      radiusKm: near == null ? null : GeocodingConfig.regionRadiusKm,
      limit: 8,
    );
    if (photon.isNotEmpty) {
      final ranked = PlaceSearchRanker.rank(
        photon,
        query: trimmed,
        near: near,
        limit: 1,
      );
      if (ranked.isNotEmpty) return ranked.first.latLng;
    }

    return _nominatim.searchAddress(trimmed, near: near);
  }

  Future<String?> reverseAddress(LatLng point) =>
      _nominatim.reverseAddress(point);

  // ── Cache ────────────────────────────────────────────────

  /// Location is folded into the key at roughly kilometre resolution: the
  /// same word asked from another town is a different question, but ordinary
  /// driving must not invalidate a list the driver is still reading.
  String _cacheKey(String query, LatLng? near) {
    if (near == null) return query.toLowerCase();
    const p = GeocodingConfig.cacheLocationPrecision;
    return '${query.toLowerCase()}@'
        '${near.latitude.toStringAsFixed(p)},'
        '${near.longitude.toStringAsFixed(p)}';
  }

  void _store(String key, List<PlaceSuggestion> results) {
    if (results.isEmpty) return;
    if (_cache.length >= GeocodingConfig.cacheEntries) {
      // Cheapest possible eviction: the map preserves insertion order, so
      // the first key is the oldest one.
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(results, DateTime.now());
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  final List<PlaceSuggestion> results;
  final DateTime storedAt;

  const _CacheEntry(this.results, this.storedAt);

  bool get isStale =>
      DateTime.now().difference(storedAt) > GeocodingConfig.cacheTtl;
}
