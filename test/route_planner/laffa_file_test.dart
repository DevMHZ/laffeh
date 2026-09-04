import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/features/route_planner/data/models/laffa_file.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_finish.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';

/// A round exactly as the console writes it. Captured from a real export
/// rather than hand-written, so this test fails if the two sides drift.
const String consoleExport = '''
{
  "laffa": 1,
  "kind": "route",
  "generated_at": "2026-09-04T21:40:00.000Z",
  "generated_by": "Laffa Console 2.1.0",
  "trip": {
    "name": "Vehicle 1 · 2026-09-04",
    "vehicle_id": 1,
    "day_start_minutes": 480,
    "day_end_minutes": 1140
  },
  "finish": { "mode": "depot", "label": null, "lat": null, "lon": null },
  "stops": [
    { "seq": 0, "kind": "depot", "label": "Departure", "address": "DEPOT",
      "lat": 33.8938, "lon": 35.5018, "phone": null, "remarks": null,
      "weight": 0, "eta_minutes": 480, "window": null },
    { "seq": 1, "kind": "delivery", "label": "Stop 1", "address": "Point 3",
      "lat": 33.85045895313795, "lon": 35.518112182617195,
      "phone": "+9613000000", "remarks": "Ring twice, back door",
      "weight": 10, "eta_minutes": 491,
      "window": { "start": 480, "end": 1140 } },
    { "seq": 2, "kind": "delivery", "label": "Stop 2", "address": "Point 4",
      "lat": 33.87, "lon": 35.52, "phone": null, "remarks": null,
      "weight": 10, "eta_minutes": 520, "window": null },
    { "seq": 3, "kind": "depot", "label": "Departure", "address": "DEPOT",
      "lat": 33.8938, "lon": 35.5018, "phone": null, "remarks": null,
      "weight": 0, "eta_minutes": 560, "window": null }
  ],
  "totals": { "stops": 2, "distance_km": 24.227, "duration_minutes": 40 }
}
''';

void main() {
  group('a round the console exported', () {
    test('comes back with its stops in order', () {
      final file = LaffaFile.parse(consoleExport);

      expect(file.version, 1);
      expect(file.vehicleId, 1);
      expect(file.tripName, 'Vehicle 1 · 2026-09-04');
      // Four rows in, four points out: the trailing depot is a real place
      // the driver returns to, not a terminal to strip.
      expect(file.points.length, 4);
      expect(file.points.first.kind, RoutePointKind.depot);
      expect(file.points.first.latitude, closeTo(33.8938, 1e-9));
      expect(file.points[1].label, 'Stop 1');
      expect(file.points[1].phone, '+9613000000');
      expect(file.finish, const RouteFinish.depot());
    });

    test('keeps the remarks a driver needs at the door', () {
      final file = LaffaFile.parse(consoleExport);
      final id = file.points[1].id;
      expect(file.remarks[id], 'Ring twice, back door');
    });

    test('keeps a time window, and only a real one', () {
      final file = LaffaFile.parse(consoleExport);
      expect(file.points[1].timeWindow, isNotNull);
      expect(file.points[1].timeWindow!.startMinuteOfDay, 480);
      expect(file.points[1].timeWindow!.endMinuteOfDay, 1140);
      expect(file.points[2].timeWindow, isNull);
    });
  });

  group('what it refuses, and how it says so', () {
    test('a file from a newer Laffa is named, not guessed at', () {
      expect(
        () => LaffaFile.parse('{"laffa": 99, "stops": []}'),
        throwsA(
          isA<LaffaFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('newer version'), contains('99')),
          ),
        ),
      );
    });

    test('a damaged file says so plainly', () {
      expect(
        () => LaffaFile.parse('{not json'),
        throwsA(
          isA<LaffaFormatException>().having(
            (e) => e.message, 'message', contains('damaged'),
          ),
        ),
      );
    });

    test('someone else\'s JSON is not a Laffa round', () {
      expect(
        () => LaffaFile.parse('{"hello": "world"}'),
        throwsA(isA<LaffaFormatException>()),
      );
    });

    test('an empty round is refused', () {
      expect(
        () => LaffaFile.parse('{"laffa": 1, "stops": []}'),
        throwsA(isA<LaffaFormatException>()),
      );
    });
  });

  group('a file that has been through an email client', () {
    test('drops individual stops that lost their coordinates', () {
      const partial = '''
      {"laffa": 1, "stops": [
        {"kind":"depot","lat":33.89,"lon":35.50},
        {"kind":"delivery","lat":null,"lon":35.51},
        {"kind":"delivery","lat":33.87,"lon":35.52},
        {"kind":"delivery","lat":999,"lon":35.52}
      ]}''';
      final file = LaffaFile.parse(partial);
      // One unusable row should not cost the other stops.
      expect(file.points.length, 2);
    });

    test('reads numbers that arrived as strings', () {
      const stringy = '''
      {"laffa": 1, "stops": [
        {"kind":"depot","lat":"33.89","lon":"35.50"},
        {"kind":"delivery","lat":"33.87","lon":"35.52","weight":"7"}
      ]}''';
      final file = LaffaFile.parse(stringy);
      expect(file.points.length, 2);
      expect(file.points[1].weight, 7);
    });

    test('ignores keys it has never heard of', () {
      const future = '''
      {"laffa": 1, "somethingNew": {"a": 1}, "stops": [
        {"kind":"depot","lat":33.89,"lon":35.50,"futureField":true},
        {"kind":"delivery","lat":33.87,"lon":35.52}
      ]}''';
      expect(LaffaFile.parse(future).points.length, 2);
    });
  });

  group('where the day ends', () {
    test('an open round comes back open', () {
      const open = '''
      {"laffa":1,"finish":{"mode":"open"},"stops":[
        {"kind":"depot","lat":33.89,"lon":35.50},
        {"kind":"delivery","lat":33.87,"lon":35.52}]}''';
      expect(LaffaFile.parse(open).finish, const RouteFinish.open());
    });

    test('a chosen finish keeps its place and is not a delivery', () {
      const custom = '''
      {"laffa":1,"finish":{"mode":"custom","lat":33.95,"lon":35.60,"label":"Home"},
       "stops":[
        {"kind":"depot","lat":33.89,"lon":35.50},
        {"kind":"delivery","lat":33.87,"lon":35.52},
        {"kind":"finish","lat":33.95,"lon":35.60,"label":"Home"}]}''';
      final file = LaffaFile.parse(custom);
      expect(file.finish.effectiveMode, RouteEndMode.custom);
      expect(file.finish.location, const LatLng(33.95, 35.60));
      // The terminal must not come back as somewhere to deliver to.
      expect(file.points.length, 2);
    });

    test('a custom finish missing its coordinates degrades to a round trip',
        () {
      const broken = '''
      {"laffa":1,"finish":{"mode":"custom","label":"Home"},"stops":[
        {"kind":"depot","lat":33.89,"lon":35.50},
        {"kind":"delivery","lat":33.87,"lon":35.52}]}''';
      expect(LaffaFile.parse(broken).finish, const RouteFinish.depot());
    });
  });
}
