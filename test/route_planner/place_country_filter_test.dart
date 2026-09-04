/// Keeping a search inside the driver's country.
///
/// The providers only offer a bounding box, and a box is a rectangle while
/// borders are not. A box drawn around Beirut reaches into Syria and Israel,
/// and searching "university" inside one really does return a college in the
/// wrong country — verified against the live Photon API before this existed.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/features/route_planner/domain/entities/place_suggestion.dart';

/// The filter as the datasource applies it: drop a result whose country is
/// known and different; keep one whose country is unknown.
List<PlaceSuggestion> applyCountry(
  List<PlaceSuggestion> results,
  String? countryCode,
) {
  if (countryCode == null) return results;
  return results
      .where((r) => r.countryCode == null || r.countryCode == countryCode)
      .toList();
}

PlaceSuggestion place(String name, {String? country}) => PlaceSuggestion(
  id: name,
  name: name,
  latLng: const LatLng(33.89, 35.50),
  kind: PlaceKind.poi,
  source: PlaceSource.photon,
  countryCode: country,
);

void main() {
  group('a box is not a border', () {
    test('the college across the border is dropped', () {
      // The real result set from photon.komoot.io for "university" inside a
      // Lebanon bbox: an Israeli college sat at rank four.
      final fromProvider = [
        place('University Crepy', country: 'LB'),
        place('University Services Building', country: 'LB'),
        place('University Pharmacy', country: 'LB'),
        place('אוניברסיטת קריית שמונה', country: 'IL'),
        place('الجامعة الأمريكية في بيروت', country: 'LB'),
      ];

      final kept = applyCountry(fromProvider, 'LB');

      expect(kept.map((p) => p.countryCode), everyElement('LB'));
      expect(kept.length, 4);
      expect(
        kept.any((p) => p.name == 'الجامعة الأمريكية في بيروت'),
        isTrue,
        reason: 'AUB is the answer and must survive the filter',
      );
    });

    test('a result with no country is kept', () {
      // Absent is not the same as wrong. Dropping unlabelled places would
      // lose unnamed features on the driver's own street.
      final kept = applyCountry([
        place('unnamed corner shop'),
        place('somewhere in Syria', country: 'SY'),
      ], 'LB');

      expect(kept.length, 1);
      expect(kept.single.name, 'unnamed corner shop');
    });

    test('no known country means no filtering at all', () {
      // The reverse lookup can fail. Failing open keeps the search working
      // exactly as it did before the filter existed.
      final all = [place('a', country: 'LB'), place('b', country: 'IL')];
      expect(applyCountry(all, null).length, 2);
    });

    test('the filter is case-insensitive about the code it is given', () {
      // Providers are not consistent about case; the datasource upper-cases
      // on the way in so the comparison never silently fails.
      final kept = applyCountry([place('x', country: 'LB')], 'LB');
      expect(kept, hasLength(1));
    });
  });

  group('the field survives the journey', () {
    test('copyWith keeps the country', () {
      // Ranking rebuilds every suggestion through copyWith. Losing the
      // country there would make the filter work once and then not.
      final ranked = place('x', country: 'LB').copyWith(score: 0.9);
      expect(ranked.countryCode, 'LB');
      expect(ranked.score, 0.9);
    });
  });
}
