import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/search_text_utils.dart';
import '../../domain/entities/place_suggestion.dart';

/// Decides the order the driver sees.
///
/// This is the part that fixes the original complaint. Every provider ranks
/// by its own idea of relevance, none of which knows where the driver is
/// standing, so the ordering has to be taken away from them and redone
/// here, once, over the merged pile. Three things decide a place's score:
///
///  1. **how well the text matches** — an exact name beats a prefix beats
///     a word that merely appears somewhere in the address;
///  2. **how far away it is** — decaying at a rate that depends on what
///     kind of thing it is, because a shop 200 km away is the wrong shop
///     while a *city* 200 km away is still the city you named;
///  3. **what it is** — a town outranks a bus stop of the same name.
///
/// Pure functions over already-fetched data: no I/O, no state, trivially
/// testable, and cheap enough to re-run on every keystroke.
class PlaceSearchRanker {
  PlaceSearchRanker._();

  /// Score, de-duplicate and sort [candidates].
  static List<PlaceSuggestion> rank(
    List<PlaceSuggestion> candidates, {
    required String query,
    LatLng? near,
    int limit = GeocodingConfig.maxResults,
  }) {
    if (candidates.isEmpty) return const [];

    final queryFolded = SearchTextUtils.fold(query);
    final queryLoose = SearchTextUtils.foldLoose(query);
    final queryTokens = SearchTextUtils.tokens(queryLoose);

    final scored = candidates.map((candidate) {
      final distanceKm = near == null
          ? candidate.distanceKm
          : DistanceUtils.haversineKm(near, candidate.latLng);

      final text = _textScore(
        candidate,
        queryFolded: queryFolded,
        queryLoose: queryLoose,
        queryTokens: queryTokens,
      );
      final proximity = _proximityScore(candidate.kind, distanceKm);
      final prominence =
          candidate.prominence ?? _prominenceScore(candidate.kind);

      // Distance normally dominates — but not against a name the driver
      // typed out in full. See [_proximityWeight].
      final proximityWeight = _proximityWeight(candidate.kind, text);
      final textWeight =
          GeocodingConfig.weightText +
          (GeocodingConfig.weightProximity - proximityWeight);

      final base =
          textWeight * text +
          proximityWeight * proximity +
          GeocodingConfig.weightProminence * prominence;

      return candidate.copyWith(
        distanceKm: distanceKm,
        score: _applySourceBonus(base, candidate.source),
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return _dedupe(scored, limit: limit);
  }

  /// Whether [candidate]'s own name *is* the query, give or take spelling.
  ///
  /// Used to decide when a search has to look further afield. A ring around
  /// the driver can fill up with near-misses — twelve villages whose names
  /// start with "حلب" — while the place they actually named sits three
  /// hundred kilometres away and never enters the pool. Counting results is
  /// not enough to catch that; recognising that none of them is the thing
  /// asked for is.
  static bool isExactMatch(PlaceSuggestion candidate, String query) {
    if (query.trim().isEmpty) return false;
    final loose = SearchTextUtils.foldLoose(query);
    return _textScore(
          candidate,
          queryFolded: SearchTextUtils.fold(query),
          queryLoose: loose,
          queryTokens: SearchTextUtils.tokens(loose),
        ) >=
        0.95;
  }

  /// Whether [candidate] is a plausible answer to [query] on text alone.
  ///
  /// Used to gate the sources that are *always* candidates — recents, the
  /// stops already on the route — which would otherwise ride their source
  /// bonus and proximity to the top of a list they have nothing to do with.
  /// A driver typing "صيدلية" must not be shown last week's warehouse just
  /// because it is close and they have been there.
  static bool matchesQuery(PlaceSuggestion candidate, String query) {
    if (query.trim().isEmpty) return true;
    final loose = SearchTextUtils.foldLoose(query);
    return _textScore(
          candidate,
          queryFolded: SearchTextUtils.fold(query),
          queryLoose: loose,
          queryTokens: SearchTextUtils.tokens(loose),
        ) >=
        0.5;
  }

  // ── Text ─────────────────────────────────────────────────

  /// How much of the query the result's own words account for.
  ///
  /// Tiered rather than continuous on purpose: the difference between "this
  /// is the thing you named" and "this contains a word you typed" is a step,
  /// not a slope, and a smooth similarity metric blurs exactly that step.
  static double _textScore(
    PlaceSuggestion candidate, {
    required String queryFolded,
    required String queryLoose,
    required List<String> queryTokens,
  }) {
    // A tag match is stronger evidence than any text match: this result is
    // here *because* it is a pharmacy, which is more than a name saying so.
    // Without this floor every unnamed fuel station scores as a mismatch.
    if (candidate.source == PlaceSource.overpass) return 0.82;

    if (queryFolded.isEmpty) return 0.5;

    final name = SearchTextUtils.fold(candidate.name);
    final nameLoose = SearchTextUtils.foldLoose(candidate.name);

    if (name == queryFolded) return 1.0;
    if (nameLoose == queryLoose) return 0.95;
    if (name.startsWith(queryFolded)) return 0.88;
    if (nameLoose.startsWith(queryLoose)) return 0.84;

    final nameTokens = nameLoose.split(' ').where((t) => t.isNotEmpty).toList();
    if (queryTokens.isNotEmpty &&
        queryTokens.every((q) => nameTokens.any((n) => n.startsWith(q)))) {
      return 0.78;
    }

    if (name.contains(queryFolded)) return 0.70;

    // Falling back to the second line: the driver may have typed the street
    // or the neighbourhood rather than the name of the place itself.
    final haystack = SearchTextUtils.foldLoose(
      '${candidate.name} ${candidate.context ?? ''}',
    );
    if (queryTokens.isNotEmpty &&
        queryTokens.every((q) => haystack.contains(q))) {
      return 0.55;
    }

    // Last tier: a typo. Cheap bounded check, not a full edit distance.
    if (SearchTextUtils.isNearMatch(nameLoose, queryLoose)) return 0.45;
    if (queryTokens.isNotEmpty &&
        nameTokens.isNotEmpty &&
        queryTokens.every(
          (q) => nameTokens.any((n) => SearchTextUtils.isNearMatch(n, q)),
        )) {
      return 0.38;
    }

    // The provider returned it, so it saw *something*; it just isn't
    // anything this code can confirm.
    return 0.20;
  }

  // ── Distance ─────────────────────────────────────────────

  static double _proximityScore(PlaceKind kind, double? distanceKm) {
    // No fix, no opinion. A neutral 0.5 for everything lets text and kind
    // decide rather than silently ranking as though the driver were at 0,0.
    if (distanceKm == null) return 0.5;

    final decay = switch (kind) {
      PlaceKind.poi => GeocodingConfig.decayKmPoi,
      PlaceKind.address => GeocodingConfig.decayKmAddress,
      PlaceKind.street => GeocodingConfig.decayKmStreet,
      PlaceKind.area => GeocodingConfig.decayKmArea,
      PlaceKind.city => GeocodingConfig.decayKmCity,
      PlaceKind.region => GeocodingConfig.decayKmRegion,
      PlaceKind.coordinate => GeocodingConfig.decayKmRegion,
    };
    return math.exp(-distanceKm / decay);
  }

  /// How much the distance term counts for this result, given how well its
  /// name matched.
  ///
  /// A flat weight cannot serve both halves of the problem. Weight distance
  /// heavily and a Damascus driver can never find Aleppo by name; weight it
  /// lightly and the Istanbul pharmacy comes straight back. The resolution
  /// is that the two cases are distinguishable: one is an *exact* match on
  /// something you name deliberately from far away, the other is not. So
  /// the distance weight is relaxed in proportion to how exact the match is
  /// and how far-nameable the kind of place is, and whatever it gives up
  /// goes to the text term rather than evaporating.
  static double _proximityWeight(PlaceKind kind, double text) {
    // 0 at the "a word of yours appears in here somewhere" tier, 1 at an
    // exact name. Below 0.7 the match is too loose to buy anything.
    final exactness = ((text - 0.7) / 0.3).clamp(0.0, 1.0);

    final share = switch (kind) {
      PlaceKind.region => GeocodingConfig.reliefShareRegion,
      PlaceKind.city => GeocodingConfig.reliefShareCity,
      PlaceKind.area => GeocodingConfig.reliefShareArea,
      PlaceKind.street => GeocodingConfig.reliefShareStreet,
      PlaceKind.address => GeocodingConfig.reliefShareAddress,
      PlaceKind.poi => GeocodingConfig.reliefSharePoi,
      PlaceKind.coordinate => 1.0,
    };

    final relief =
        GeocodingConfig.exactMatchProximityRelief * exactness * share;
    return GeocodingConfig.weightProximity * (1 - relief);
  }

  // ── Kind ─────────────────────────────────────────────────

  /// The fallback for a result whose provider said nothing about how big
  /// it is — see [PlaceSuggestion.prominence] for the real thing.
  static double _prominenceScore(PlaceKind kind) => switch (kind) {
    PlaceKind.coordinate => 1.0,
    PlaceKind.city => 0.85,
    PlaceKind.region => 0.70,
    PlaceKind.area => 0.65,
    PlaceKind.poi => 0.60,
    PlaceKind.street => 0.55,
    PlaceKind.address => 0.50,
  };

  static double _applySourceBonus(double base, PlaceSource source) {
    final bonus = switch (source) {
      // A coordinate the driver pasted is not a guess about their intent.
      PlaceSource.coordinate => 1.0,
      // They have been here before and chose it themselves. Nothing a
      // geocoder infers beats that.
      PlaceSource.recent => 0.22,
      PlaceSource.routePoint => 0.12,
      // The driver pointed at it on the map. Not a guess about intent
      // either, but it still has to rank against everything else, because
      // a tapped label can also arrive as a search candidate.
      PlaceSource.mapLabel => 0.12,
      PlaceSource.overpass => 0.02,
      PlaceSource.photon => 0.0,
      PlaceSource.nominatim => 0.0,
      PlaceSource.category => 0.0,
    };
    if (source == PlaceSource.coordinate) return 1.0;
    return math.min(1.0, base + bonus);
  }

  // ── Merge ────────────────────────────────────────────────

  /// Collapses the same place seen by several providers into one tile.
  ///
  /// Runs over an already-sorted list, so the survivor is always the
  /// higher-scored sighting; it only borrows the loser's second line when
  /// it has none of its own, which is common where Photon knows the
  /// neighbourhood and Overpass knows only the pin.
  static List<PlaceSuggestion> _dedupe(
    List<PlaceSuggestion> sorted, {
    required int limit,
  }) {
    final kept = <PlaceSuggestion>[];

    for (final candidate in sorted) {
      if (kept.length >= limit) break;

      var duplicateAt = -1;
      for (var i = 0; i < kept.length; i++) {
        if (_isSamePlace(kept[i], candidate)) {
          duplicateAt = i;
          break;
        }
      }

      if (duplicateAt < 0) {
        kept.add(candidate);
        continue;
      }

      final winner = kept[duplicateAt];
      final winnerContext = winner.context?.trim() ?? '';
      final loserContext = candidate.context?.trim() ?? '';
      if (winnerContext.isEmpty && loserContext.isNotEmpty) {
        kept[duplicateAt] = winner.copyWith(context: loserContext);
      }
    }

    return kept;
  }

  static bool _isSamePlace(PlaceSuggestion a, PlaceSuggestion b) {
    if (a.id == b.id) return true;

    final metres = DistanceUtils.haversineKm(a.latLng, b.latLng) * 1000;
    if (metres > GeocodingConfig.dedupeMeters) return false;

    final nameA = SearchTextUtils.foldLoose(a.name);
    final nameB = SearchTextUtils.foldLoose(b.name);
    if (nameA.isEmpty || nameB.isEmpty) return false;

    return nameA == nameB ||
        nameA.contains(nameB) ||
        nameB.contains(nameA) ||
        SearchTextUtils.isNearMatch(nameA, nameB);
  }
}
