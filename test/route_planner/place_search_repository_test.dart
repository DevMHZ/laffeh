import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laffeh/core/config/geocoding_config.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/overpass_poi_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/photon_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/place_category_lexicon.dart';
import 'package:laffeh/features/route_planner/data/datasources/recent_places_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/domain/entities/place_suggestion.dart';

class _MockPhoton extends Mock implements PhotonGeocodingDataSource {}

class _MockNominatim extends Mock implements OsmGeocodingDataSource {}

class _MockOverpass extends Mock implements OverpassPoiDataSource {}

const _damascus = LatLng(33.5138, 36.2765);
const _aleppo = LatLng(36.2021, 37.1343);

PlaceSuggestion _place(
  String name, {
  required LatLng at,
  PlaceKind kind = PlaceKind.poi,
  PlaceSource source = PlaceSource.photon,
  double? prominence,
}) {
  return PlaceSuggestion(
    id: '$name@${at.latitude}',
    name: name,
    latLng: at,
    kind: kind,
    source: source,
    prominence: prominence,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPhoton photon;
  late _MockNominatim nominatim;
  late _MockOverpass overpass;
  late PlaceSearchRepository repo;

  setUpAll(() {
    registerFallbackValue(_damascus);
    registerFallbackValue(
      const PlaceCategory(labelKey: 'catFuel', tags: ['amenity=fuel']),
    );
  });

  setUp(() async {
    AppStrings.setLocale(const Locale('ar'));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    photon = _MockPhoton();
    nominatim = _MockNominatim();
    overpass = _MockOverpass();

    when(
      () => nominatim.search(
        any(),
        near: any(named: 'near'),
        radiusKm: any(named: 'radiusKm'),
        countryCode: any(named: 'countryCode'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);

    when(
      () => overpass.nearby(
        any(),
        near: any(named: 'near'),
        radiusKm: any(named: 'radiusKm'),
        categoryLabel: any(named: 'categoryLabel'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);

    repo = PlaceSearchRepository(
      photon: photon,
      nominatim: nominatim,
      overpass: overpass,
      recents: RecentPlacesLocalDataSource(prefs),
    );
  });

  /// Every `_photon.search` call made during a search, as (radiusKm) values.
  List<double?> photonRadii() {
    return verify(
      () => photon.search(
        any(),
        near: any(named: 'near'),
        radiusKm: captureAny(named: 'radiusKm'),
        limit: any(named: 'limit'),
      ),
    ).captured.cast<double?>();
  }

  group('search ladder', () {
    test('a full, on-the-nose local ring is not widened', () async {
      when(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => List.generate(
          6,
          (i) => _place(
            'شارع الثورة',
            at: LatLng(33.52 + i * 0.001, 36.28),
            kind: PlaceKind.street,
          ),
        ),
      );

      await repo.search('شارع الثورة', near: _damascus).drain<void>();

      expect(photonRadii(), [GeocodingConfig.nearRadiusKm]);
    });

    test('near-misses do not count as an answer — the ring widens', () async {
      // The حلب case: the local ring fills with names that merely *start*
      // the same way, and the city itself is three hundred km out.
      when(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: GeocodingConfig.nearRadiusKm,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => List.generate(
          8,
          (i) => _place(
            'حلبون',
            at: LatLng(33.6 + i * 0.01, 36.3),
            kind: PlaceKind.city,
            prominence: 0.78,
          ),
        ),
      );
      when(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _place('حلب', at: _aleppo, kind: PlaceKind.city, prominence: 0.95),
        ],
      );

      final snapshots = await repo
          .search('حلب', near: _damascus)
          .toList();

      // Both wider rings run, and they run because nothing nearby was
      // actually called حلب — not because the ring came back short.
      expect(photonRadii(), [
        GeocodingConfig.nearRadiusKm,
        GeocodingConfig.regionRadiusKm,
        null, // the unbounded pass
      ]);
      expect(snapshots.last.first.name, 'حلب');
    });

    test('a category query never goes global', () async {
      // "بنزين" is a question about here. Letting it off the leash fills
      // the list with fuel stations a thousand kilometres away that share
      // the word — which is exactly what the driver complained about.
      when(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const []);

      when(
        () => overpass.nearby(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          categoryLabel: any(named: 'categoryLabel'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => List.generate(
          6,
          (i) => _place(
            'كازية الربوة',
            at: LatLng(33.52 + i * 0.002, 36.28),
            source: PlaceSource.overpass,
          ),
        ),
      );

      final snapshots = await repo.search('بنزين', near: _damascus).toList();

      expect(photonRadii(), isNot(contains(null)));
      expect(snapshots.last, isNotEmpty);
      expect(snapshots.last.first.source, PlaceSource.overpass);
    });
  });

  group('shortcuts', () {
    test('pasted coordinates answer instantly and ask nobody', () async {
      final snapshots = await repo
          .search('33.5131, 36.2767', near: _damascus)
          .toList();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.single.kind, PlaceKind.coordinate);
      expect(snapshots.single.single.latLng.latitude, closeTo(33.5131, 1e-6));
      verifyNever(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('a Google Maps link is resolved without a geocoder', () async {
      final snapshots = await repo
          .search('https://www.google.com/maps?q=33.5131,36.2767')
          .toList();

      expect(snapshots.single.single.kind, PlaceKind.coordinate);
      verifyNever(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('one letter asks nobody anything', () async {
      final snapshots = await repo.search('ح', near: _damascus).toList();
      expect(snapshots, isEmpty);
      verifyNever(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      );
    });
  });

  group('results arrive progressively', () {
    test('the fast provider is shown before the slow ones finish', () async {
      when(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => List.generate(
          6,
          (i) => _place('صيدلية الشام', at: LatLng(33.52 + i * 0.001, 36.28)),
        ),
      );
      when(
        () => nominatim.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          countryCode: any(named: 'countryCode'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _place(
            'صيدلية عرفة',
            at: const LatLng(33.5300, 36.2900),
            source: PlaceSource.nominatim,
          ),
        ],
      );

      final snapshots = await repo
          .search('صيدلية الشام', near: _damascus)
          .toList();

      expect(snapshots.length, greaterThanOrEqualTo(2));
      expect(snapshots.first, isNotEmpty);
      expect(snapshots.last.length, greaterThan(snapshots.first.length));
    });
  });

  group('recents', () {
    test('a picked place leads the list next time it is typed', () async {
      final warehouse = _place(
        'مستودع المزة',
        at: const LatLng(33.4900, 36.2400),
      );
      await repo.remember(warehouse);

      expect(repo.recentPlaces(near: _damascus).single.name, 'مستودع المزة');
      expect(
        repo.recentPlaces(near: _damascus).single.distanceKm,
        isNotNull,
      );

      when(
        () => photon.search(
          any(),
          near: any(named: 'near'),
          radiusKm: any(named: 'radiusKm'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => List.generate(
          6,
          (i) => _place('مستودع الشام', at: LatLng(33.515 + i * 0.001, 36.277)),
        ),
      );

      final snapshots = await repo
          .search('مستودع المزة', near: _damascus)
          .toList();

      expect(snapshots.last.first.name, 'مستودع المزة');
      expect(snapshots.last.first.source, PlaceSource.recent);
    });

    test('picking the same place again does not duplicate it', () async {
      final stop = _place('مستودع المزة', at: const LatLng(33.49, 36.24));
      await repo.remember(stop);
      await repo.remember(stop);
      expect(repo.recentPlaces(), hasLength(1));
    });
  });
}
