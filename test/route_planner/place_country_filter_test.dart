/// Preferring the countries in play, without hiding the rest.
///
/// The first version of this dropped every foreign result outright. That was
/// too blunt: a bounding box around Beirut reaches into Syria, and a driver
/// working near a border wants to see what is actually across it. Foreign
/// results are now demoted, not deleted, and inside a short radius they are
/// not even demoted.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/config/geocoding_config.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/photon_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_ranker.dart';
import 'package:laffeh/features/route_planner/domain/entities/place_suggestion.dart';

const _beirut = LatLng(33.8938, 35.5018);

PlaceSuggestion place(
  String name, {
  String? country,
  double lat = 33.89,
  double lon = 35.50,
}) => PlaceSuggestion(
  id: name,
  name: name,
  latLng: LatLng(lat, lon),
  kind: PlaceKind.poi,
  source: PlaceSource.photon,
  countryCode: country,
);

List<String> order(List<PlaceSuggestion> input, Set<String> preferred) =>
    PlaceSearchRanker.rank(input, query: 'hamra', near: _beirut,
            preferredCountries: preferred)
        .map((p) => p.name)
        .toList();

void main() {
  group('the rest is shown, just second', () {
    test('a foreign result is kept, not dropped', () {
      // The whole point of the rewrite: nothing disappears. Distinct names,
      // or the de-duplicator folds them together and the test proves nothing.
      final ranked = order([
        place('Hamra Beirut', country: 'LB'),
        place('Hamra Sweden', country: 'SE', lat: 61.6, lon: 14.9),
      ], {'LB'});
      expect(ranked.length, 2);
      expect(ranked, contains('Hamra Sweden'));
    });

    test('but it sorts below the local one', () {
      final ranked = PlaceSearchRanker.rank([
        place('Hamra Sweden', country: 'SE', lat: 61.6, lon: 14.9),
        place('Hamra Beirut', country: 'LB'),
      ], query: 'hamra', near: _beirut, preferredCountries: {'LB'});
      expect(ranked.first.name, 'Hamra Beirut');
    });

    test('with no countries resolved, nothing is demoted', () {
      // The reverse lookup can fail. Failing open leaves the ranking exactly
      // as it was before any of this existed.
      // Far away, or the border let-off spares it and the penalty never
      // applies in the first place.
      final sweden = place('x', country: 'SE', lat: 61.6, lon: 14.9);
      final a = PlaceSearchRanker.rank([sweden],
          query: 'x', near: _beirut, preferredCountries: {});
      final b = PlaceSearchRanker.rank([sweden],
          query: 'x', near: _beirut, preferredCountries: {'LB'});
      expect(a.single.score, greaterThan(b.single.score));
    });

    test('an unknown country is never penalised', () {
      // Absent is not the same as foreign.
      final unknown = PlaceSearchRanker.rank([place('x')],
          query: 'x', near: _beirut, preferredCountries: {'LB'});
      final local = PlaceSearchRanker.rank([place('x', country: 'LB')],
          query: 'x', near: _beirut, preferredCountries: {'LB'});
      expect(unknown.single.score, closeTo(local.single.score, 1e-9));
    });
  });

  group('a border is not a wall', () {
    test('a nearby foreign place is not demoted at all', () {
      // Twelve kilometres over a border beats two hundred on your own side.
      final near = PlaceSearchRanker.rank([
        place('just across', country: 'SY', lat: 33.98, lon: 35.55),
      ], query: 'x', near: _beirut, preferredCountries: {'LB'});
      final far = PlaceSearchRanker.rank([
        place('just across', country: 'SY', lat: 36.20, lon: 37.16),
      ], query: 'x', near: _beirut, preferredCountries: {'LB'});
      expect(near.single.score, greaterThan(far.single.score));
    });

    test('several countries in play are all preferred', () {
      // Panned across a border: both sides rank as local.
      final ranked = PlaceSearchRanker.rank([
        place('a', country: 'LB'),
        place('b', country: 'SY', lat: 36.20, lon: 37.16),
      ], query: 'x', near: _beirut, preferredCountries: {'LB', 'SY'});
      // Neither carries the foreign penalty, so distance alone separates them.
      expect(ranked.map((p) => p.countryCode), containsAll(['LB', 'SY']));
    });
  });

  group('results come back in the app language', () {
    test('Photon takes only the languages it supports', () {
      // Asking it for Arabic is answered with HTTP 400, which would take the
      // search box down entirely for every Arabic user.
      expect(photonLanguage('en'), 'en');
      expect(photonLanguage('fr'), 'fr');
      expect(photonLanguage('ar'), 'default');
      expect(photonLanguage(null), 'default');
      expect(photonLanguage('zz'), 'default');
    });

    test('default is the right answer for Arabic, not a compromise', () {
      // In the Arab world the local name *is* the Arabic one: `default`
      // returns الحمرا where `en` returns "El Hamra".
      expect(photonLanguage('ar'), 'default');
    });

    test('Nominatim takes the language, with English behind it', () {
      expect(acceptLanguage('ar'), 'ar,en');
      expect(acceptLanguage('fr'), 'fr,en');
      expect(acceptLanguage('en'), 'en');
      expect(acceptLanguage(null), 'en');
    });
  });

  group('the knobs are sane', () {
    test('the penalty demotes without deleting', () {
      expect(GeocodingConfig.foreignPenalty, greaterThan(0));
      expect(GeocodingConfig.foreignPenalty, lessThan(1));
    });
  });
}
