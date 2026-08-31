import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/route_planner/data/datasources/map_label_reader.dart';
import 'package:laffeh/features/route_planner/domain/entities/place_suggestion.dart';

/// Where the finger landed, for features whose own geometry is a line.
const _tap = LatLng(33.5138, 36.2765);

/// Every layer id in the OpenFreeMap Liberty style — the app's default map,
/// captured from the live style so the grouping is tested against the real
/// thing rather than against what the grouping expects to see.
const _libertyLayerIds = <String>[
  'background',
  'natural_earth',
  'park',
  'park_outline',
  'landuse_residential',
  'landcover_wood',
  'landcover_grass',
  'landcover_ice',
  'landcover_wetland',
  'landuse_pitch',
  'landuse_track',
  'landuse_cemetery',
  'landuse_hospital',
  'landuse_school',
  'waterway_tunnel',
  'waterway_river',
  'waterway_other',
  'water',
  'landcover_sand',
  'aeroway_fill',
  'aeroway_runway',
  'aeroway_taxiway',
  'tunnel_motorway_link_casing',
  'tunnel_service_track_casing',
  'tunnel_link_casing',
  'tunnel_street_casing',
  'tunnel_secondary_tertiary_casing',
  'tunnel_trunk_primary_casing',
  'tunnel_motorway_casing',
  'tunnel_path_pedestrian',
  'tunnel_motorway_link',
  'tunnel_service_track',
  'tunnel_link',
  'tunnel_minor',
  'tunnel_secondary_tertiary',
  'tunnel_trunk_primary',
  'tunnel_motorway',
  'tunnel_major_rail',
  'tunnel_major_rail_hatching',
  'tunnel_transit_rail',
  'tunnel_transit_rail_hatching',
  'road_area_pattern',
  'road_motorway_link_casing',
  'road_service_track_casing',
  'road_link_casing',
  'road_minor_casing',
  'road_secondary_tertiary_casing',
  'road_trunk_primary_casing',
  'road_motorway_casing',
  'road_path_pedestrian',
  'road_motorway_link',
  'road_service_track',
  'road_link',
  'road_minor',
  'road_secondary_tertiary',
  'road_trunk_primary',
  'road_motorway',
  'road_major_rail',
  'road_major_rail_hatching',
  'road_transit_rail',
  'road_transit_rail_hatching',
  'road_one_way_arrow',
  'road_one_way_arrow_opposite',
  'bridge_motorway_link_casing',
  'bridge_service_track_casing',
  'bridge_link_casing',
  'bridge_street_casing',
  'bridge_path_pedestrian_casing',
  'bridge_secondary_tertiary_casing',
  'bridge_trunk_primary_casing',
  'bridge_motorway_casing',
  'bridge_path_pedestrian',
  'bridge_motorway_link',
  'bridge_service_track',
  'bridge_link',
  'bridge_street',
  'bridge_secondary_tertiary',
  'bridge_trunk_primary',
  'bridge_motorway',
  'bridge_major_rail',
  'bridge_major_rail_hatching',
  'bridge_transit_rail',
  'bridge_transit_rail_hatching',
  'building',
  'building-3d',
  'boundary_3',
  'boundary_2',
  'boundary_disputed',
  'waterway_line_label',
  'water_name_point_label',
  'water_name_line_label',
  'poi_r20',
  'poi_r7',
  'poi_r1',
  'poi_transit',
  'highway-name-path',
  'highway-name-minor',
  'highway-name-major',
  'highway-shield-non-us',
  'highway-shield-us-interstate',
  'road_shield_us',
  'airport',
  'label_other',
  'label_village',
  'label_town',
  'label_state',
  'label_city',
  'label_city_capital',
  'label_country_3',
  'label_country_2',
  'label_country_1',
];

/// Mapbox Streets v12 names its layers differently. Included because the
/// style is configurable and this feature must not quietly die on a swap.
const _mapboxLayerIds = <String>[
  'land',
  'water',
  'building',
  'road-primary',
  'road-label',
  'poi-label',
  'transit-label',
  'airport-label',
  'settlement-subdivision-label',
  'settlement-label',
  'state-label',
  'country-label',
  'natural-point-label',
  'water-point-label',
];

Map<String, dynamic> _feature({
  required Map<String, dynamic> properties,
  Map<String, dynamic>? geometry,
  String id = 'f1',
}) {
  return {
    'type': 'Feature',
    'id': id,
    'properties': properties,
    'geometry':
        geometry ??
        {
          'type': 'Point',
          'coordinates': [36.2800, 33.5200],
        },
  };
}

void main() {
  setUp(() => AppStrings.setLocale(const Locale('ar')));

  group('grouping a style\'s layers', () {
    test('the real Liberty style sorts into the expected tiers', () {
      final layers = MapLabelReader.groupLayers(_libertyLayerIds);

      expect(layers.poi, [
        'poi_r20',
        'poi_r7',
        'poi_r1',
        'poi_transit',
        'airport',
      ]);
      expect(layers.place, contains('label_city'));
      expect(layers.place, contains('label_village'));
      expect(layers.place, contains('label_other'));
      expect(layers.other, contains('highway-name-major'));
      expect(layers.other, contains('water_name_point_label'));
    });

    test('"point" is not "poi"', () {
      // A substring test files water_name_point_label under POI, so tapping
      // a river outranks tapping the pharmacy next to it.
      final layers = MapLabelReader.groupLayers(_libertyLayerIds);
      expect(layers.poi, isNot(contains('water_name_point_label')));
    });

    test('geometry layers are left alone', () {
      // road_transit_rail draws rails, not names. Querying it can only
      // return unnamed lines that outrank the label the driver tapped.
      final layers = MapLabelReader.groupLayers(_libertyLayerIds);
      for (final tier in [layers.poi, layers.place, layers.other]) {
        expect(tier, isNot(contains('road_transit_rail')));
        expect(tier, isNot(contains('tunnel_transit_rail')));
        expect(tier, isNot(contains('bridge_transit_rail_hatching')));
        expect(tier, isNot(contains('park')));
        expect(tier, isNot(contains('building')));
      }
    });

    test("the app's own route layers are never queried", () {
      final layers = MapLabelReader.groupLayers([
        ..._libertyLayerIds,
        'poly-bg',
        'poly-fg',
        'lyr-bg',
        'lyr-fg',
        'lyr-trail',
        'lyr-maneuver',
      ]);
      for (final own in ['poly-bg', 'poly-fg', 'lyr-bg', 'lyr-fg']) {
        expect(layers.poi, isNot(contains(own)));
        expect(layers.place, isNot(contains(own)));
        expect(layers.other, isNot(contains(own)));
      }
    });

    test('a different vendor\'s naming still works', () {
      final layers = MapLabelReader.groupLayers(_mapboxLayerIds);
      expect(layers.poi, containsAll(['poi-label', 'airport-label']));
      expect(
        layers.place,
        containsAll(['settlement-label', 'state-label', 'country-label']),
      );
      expect(layers.other, contains('road-label'));
      expect(layers.other, isNot(contains('building')));
    });

    test('a style with no labels at all disables the feature quietly', () {
      final layers = MapLabelReader.groupLayers([
        'background',
        'water',
        'road',
      ]);
      expect(layers.isEmpty, isTrue);
    });
  });

  group('reading a tapped feature', () {
    test('a POI keeps its own name, category and coordinate', () {
      final place = MapLabelReader.read(
        _feature(
          properties: {
            'name': 'صيدلية الشام',
            'class': 'shop',
            'subclass': 'pharmacy',
            'rank': 1,
          },
        ),
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );

      expect(place, isNotNull);
      expect(place!.name, 'صيدلية الشام');
      expect(place.context, 'صيدلية');
      expect(place.kind, PlaceKind.poi);
      expect(place.source, PlaceSource.mapLabel);
      // Its own coordinate, not the tap — the finger is not that accurate.
      expect(place.latLng.latitude, closeTo(33.52, 1e-6));
    });

    test('the specific category wins over the general one', () {
      final place = MapLabelReader.read(
        _feature(
          properties: {
            'name': 'كازية الربوة',
            'class': 'fuel',
            'subclass': 'fuel',
          },
        ),
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );
      expect(place!.context, 'محطة وقود');
    });

    test('a city is read as a city and carries its weight', () {
      final place = MapLabelReader.read(
        _feature(properties: {'name': 'حلب', 'class': 'city', 'rank': 2}),
        fallback: _tap,
        tierKind: PlaceKind.city,
      );

      expect(place!.kind, PlaceKind.city);
      expect(place.prominence, 0.95);
      expect(place.context, 'مدينة');
    });

    test('a suburb in the place tier is an area, not a city', () {
      final place = MapLabelReader.read(
        _feature(properties: {'name': 'المزة', 'class': 'suburb'}),
        fallback: _tap,
        tierKind: PlaceKind.city,
      );
      expect(place!.kind, PlaceKind.area);
      expect(place.context, 'حي');
    });

    test('a tapped street resolves to where the finger landed', () {
      // A street is a line kilometres long. Offering its first vertex would
      // send the driver to the far end of the road they pointed at.
      final place = MapLabelReader.read(
        _feature(
          properties: {'name': 'شارع الثورة', 'class': 'secondary'},
          geometry: {
            'type': 'LineString',
            'coordinates': [
              [36.30, 33.55],
              [36.31, 33.56],
            ],
          },
        ),
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );

      expect(place!.kind, PlaceKind.street);
      expect(place.latLng, _tap);
      expect(place.context, 'شارع');
    });

    test('an unnamed feature is not somewhere to go', () {
      expect(
        MapLabelReader.read(
          _feature(properties: {'class': 'fuel'}),
          fallback: _tap,
          tierKind: PlaceKind.poi,
        ),
        isNull,
      );
    });

    test('junk from the platform is survived, not thrown on', () {
      for (final junk in [null, 'not a map', 42, <String, dynamic>{}]) {
        expect(
          MapLabelReader.read(junk, fallback: _tap, tierKind: PlaceKind.poi),
          isNull,
        );
      }
    });

    test('readBest skips the unnamed and takes the first real name', () {
      final place = MapLabelReader.readBest(
        [
          _feature(properties: {'class': 'residential'}, id: 'a'),
          _feature(
            properties: {'name': 'صيدلية النور', 'subclass': 'pharmacy'},
            id: 'b',
          ),
          _feature(properties: {'name': 'دمشق', 'class': 'city'}, id: 'c'),
        ],
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );
      expect(place!.name, 'صيدلية النور');
    });
  });

  group('names follow the app language', () {
    test('Arabic prefers name:ar, then the local name', () {
      AppStrings.setLocale(const Locale('ar'));
      final place = MapLabelReader.read(
        _feature(
          properties: {
            'name': 'Umayyad Square',
            'name:ar': 'ساحة الأمويين',
            'name:en': 'Umayyad Square',
          },
        ),
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );
      expect(place!.name, 'ساحة الأمويين');
    });

    test('English prefers name:en', () {
      AppStrings.setLocale(const Locale('en'));
      final place = MapLabelReader.read(
        _feature(
          properties: {'name': 'ساحة الأمويين', 'name:en': 'Umayyad Square'},
        ),
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );
      expect(place!.name, 'Umayyad Square');
    });

    test('the local name is used when there is no translation', () {
      AppStrings.setLocale(const Locale('ar'));
      final place = MapLabelReader.read(
        _feature(properties: {'name': 'كازية دمر'}),
        fallback: _tap,
        tierKind: PlaceKind.poi,
      );
      expect(place!.name, 'كازية دمر');
    });
  });
}
