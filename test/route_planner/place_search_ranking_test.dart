import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/features/route_planner/data/datasources/place_category_lexicon.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_ranker.dart';
import 'package:laffeh/features/route_planner/domain/entities/place_suggestion.dart';
import 'package:laffeh/core/utils/search_text_utils.dart';

/// Umayyad Square — the fixture "here" for every test below.
const _damascus = LatLng(33.5138, 36.2765);

PlaceSuggestion _place(
  String name, {
  required LatLng at,
  PlaceKind kind = PlaceKind.poi,
  PlaceSource source = PlaceSource.photon,
  String? context,
  String? id,
}) {
  return PlaceSuggestion(
    id: id ?? '$name@${at.latitude},${at.longitude}',
    name: name,
    context: context,
    latLng: at,
    kind: kind,
    source: source,
  );
}

void main() {
  group('proximity ranking', () {
    test('a near match outranks a far one with the same name', () {
      // The bug this whole subsystem exists for: the public geocoder,
      // asked for "صيدلية" from Damascus, answers with Istanbul first.
      final istanbul = _place('صيدلية', at: const LatLng(41.0001, 28.9127));
      final damascus = _place('صيدلية', at: const LatLng(33.5481, 36.3180));

      final ranked = PlaceSearchRanker.rank(
        [istanbul, damascus],
        query: 'صيدلية',
        near: _damascus,
      );

      expect(ranked.first.latLng.latitude, closeTo(33.5481, 0.001));
      expect(ranked.first.distanceKm, lessThan(10));
    });

    test('a named city stays findable from far away', () {
      // The opposite failure. Distance must not become the only thing that
      // matters, or a driver planning a run to Aleppo can never name it.
      final aleppo = _place(
        'حلب',
        at: const LatLng(36.2021, 37.1343),
        kind: PlaceKind.city,
      );
      final nearbyShop = _place(
        'محل حلب للحلويات',
        at: const LatLng(33.5150, 36.2800),
      );

      final ranked = PlaceSearchRanker.rank(
        [nearbyShop, aleppo],
        query: 'حلب',
        near: _damascus,
      );

      expect(ranked.first.name, 'حلب');
    });

    test('an exact nearby name beats a closer partial match', () {
      final exact = _place('صيدلية الشفاء', at: const LatLng(33.5300, 36.2900));
      final partial = _place(
        'مكتبة الشفاء',
        at: const LatLng(33.5140, 36.2770),
      );

      final ranked = PlaceSearchRanker.rank(
        [partial, exact],
        query: 'صيدلية الشفاء',
        near: _damascus,
      );

      expect(ranked.first.name, 'صيدلية الشفاء');
    });
  });

  group('sources', () {
    test('a place picked before leads a list of equals', () {
      final fresh = _place('مستودع المزة', at: const LatLng(33.5000, 36.2500));
      final remembered = _place(
        'مستودع المزة',
        at: const LatLng(33.4900, 36.2400),
        source: PlaceSource.recent,
        id: 'recent:1',
      );

      final ranked = PlaceSearchRanker.rank(
        [fresh, remembered],
        query: 'مستودع',
        near: _damascus,
      );

      expect(ranked.first.source, PlaceSource.recent);
    });

    test('an unnamed category hit still ranks — it matched by tag', () {
      // "كازية دمر" contains not one letter of "بنزين". Text scoring alone
      // would rank it as a mismatch and bury the only real answer.
      final station = _place(
        'كازية دمر',
        at: const LatLng(33.5304, 36.2344),
        source: PlaceSource.overpass,
      );
      final textHit = _place(
        'بنزين ابو حسن',
        at: const LatLng(35.9000, 36.0000),
      );

      final ranked = PlaceSearchRanker.rank(
        [textHit, station],
        query: 'بنزين',
        near: _damascus,
      );

      expect(ranked.first.name, 'كازية دمر');
    });

    test('recents unrelated to the query are gated out', () {
      final warehouse = _place(
        'مستودع الشركة',
        at: _damascus,
        source: PlaceSource.recent,
      );
      expect(PlaceSearchRanker.matchesQuery(warehouse, 'صيدلية'), isFalse);
      expect(PlaceSearchRanker.matchesQuery(warehouse, 'مستودع'), isTrue);
    });
  });

  group('merging', () {
    test('the same place from two providers collapses to one row', () {
      final fromPhoton = _place(
        'صيدلية النور',
        at: const LatLng(33.5200, 36.2800),
        source: PlaceSource.photon,
        context: 'حي المزة، دمشق',
      );
      final fromNominatim = _place(
        'صيدلية النور',
        at: const LatLng(33.52005, 36.28005),
        source: PlaceSource.nominatim,
        id: 'nominatim:1',
      );

      final ranked = PlaceSearchRanker.rank(
        [fromPhoton, fromNominatim],
        query: 'صيدلية النور',
        near: _damascus,
      );

      expect(ranked, hasLength(1));
      expect(ranked.first.context, 'حي المزة، دمشق');
    });

    test('the survivor borrows a second line when it has none', () {
      final bare = _place(
        'كازية القصور',
        at: const LatLng(33.5234, 36.3098),
        source: PlaceSource.overpass,
      );
      final described = _place(
        'كازية القصور',
        at: const LatLng(33.52341, 36.30981),
        source: PlaceSource.photon,
        context: 'حي القصور، دمشق',
        id: 'photon:1',
      );

      final ranked = PlaceSearchRanker.rank(
        [bare, described],
        query: 'كازية',
        near: _damascus,
      );

      expect(ranked, hasLength(1));
      expect(ranked.first.context, 'حي القصور، دمشق');
    });
  });

  group('text folding', () {
    test('spellings a driver actually types all fold together', () {
      expect(SearchTextUtils.fold('صيدليّة'), SearchTextUtils.fold('صيدليه'));
      expect(SearchTextUtils.fold('أحمد'), SearchTextUtils.fold('احمد'));
      expect(SearchTextUtils.fold('مصطفى'), SearchTextUtils.fold('مصطفي'));
      expect(SearchTextUtils.fold('شارع ٣٠'), 'شارع 30');
    });

    test('the definite article is optional for matching', () {
      expect(
        SearchTextUtils.foldLoose('شارع الثورة'),
        SearchTextUtils.foldLoose('شارع ثورة'),
      );
      expect(SearchTextUtils.foldLoose('Al Mazzeh'), 'mazzeh');
    });

    test('one typo still matches', () {
      expect(SearchTextUtils.isNearMatch('mazzeh', 'mazzah'), isTrue);
      expect(SearchTextUtils.isNearMatch('mazzeh', 'mazze'), isTrue);
      expect(SearchTextUtils.isNearMatch('mazzeh', 'damascus'), isFalse);
    });
  });

  group('category lexicon', () {
    test('colloquial words for fuel all reach amenity=fuel', () {
      for (final word in [
        'بنزين',
        'كازية',
        'محروقات',
        'مازوت',
        'gas station',
      ]) {
        final category = PlaceCategoryLexicon.match(word);
        expect(category, isNotNull, reason: word);
        expect(category!.tags, contains('amenity=fuel'), reason: word);
      }
    });

    test('a category word inside a longer question still counts', () {
      expect(
        PlaceCategoryLexicon.match('أقرب صيدلية')?.labelKey,
        'catPharmacy',
      );
      expect(
        PlaceCategoryLexicon.match('محطة وقود قريبة')?.labelKey,
        'catFuel',
      );
    });

    test('a place asked for by name is not a category', () {
      expect(PlaceCategoryLexicon.match('شارع الثورة'), isNull);
      expect(PlaceCategoryLexicon.match('حلب'), isNull);
    });
  });
}
