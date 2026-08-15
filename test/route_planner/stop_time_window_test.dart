import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/routing_config.dart';
import 'package:laffeh/features/route_planner/data/models/route_point_model.dart';
import 'package:laffeh/features/route_planner/data/models/route_request_model.dart';
import 'package:laffeh/features/route_planner/domain/entities/stop_time_window.dart';

StopTimeWindow _w(int startH, int startM, int endH, int endM) => StopTimeWindow(
  startMinuteOfDay: startH * 60 + startM,
  endMinuteOfDay: endH * 60 + endM,
);

int _at(int hour, [int minute = 0]) => hour * 60 + minute;

void main() {
  group('StopTimeWindow.relativeTo', () {
    test('a window later the same day is a plain offset', () {
      // Leave 08:00, be there 14:00–15:00 → 360..420 minutes out.
      final r = _w(14, 0, 15, 0).relativeTo(_at(8));
      expect(r.startMinutes, 360);
      expect(r.endMinutes, 420);
    });

    test('a window already open at departure starts immediately', () {
      // Leaving 08:00 into an 07:00–09:00 window: the first hour is gone,
      // but the stop is reachable right now — not tomorrow morning.
      final r = _w(7, 0, 9, 0).relativeTo(_at(8));
      expect(r.startMinutes, 0);
      expect(r.endMinutes, 60);
    });

    test('a window after midnight rolls into the next day', () {
      // Leave 22:00, be there 01:00–02:00 → 180..240 minutes out.
      final r = _w(1, 0, 2, 0).relativeTo(_at(22));
      expect(r.startMinutes, 180);
      expect(r.endMinutes, 240);
    });

    test('a window spanning midnight stays contiguous', () {
      // Leave 08:00, be there 23:00–01:00 → 900..1020, not a negative span.
      final r = _w(23, 0, 1, 0).relativeTo(_at(8));
      expect(r.startMinutes, 900);
      expect(r.endMinutes, 1020);
      expect(r.endMinutes > r.startMinutes, isTrue);
    });

    test('departing exactly at the window start yields a zero offset', () {
      final r = _w(9, 30, 10, 0).relativeTo(_at(9, 30));
      expect(r.startMinutes, 0);
      expect(r.endMinutes, 30);
    });

    test('never produces a negative or inverted window', () {
      for (var departure = 0; departure < 1440; departure += 37) {
        for (var start = 0; start < 1440; start += 53) {
          for (final span in [15, 120, 600]) {
            final w = StopTimeWindow(
              startMinuteOfDay: start,
              endMinuteOfDay: (start + span) % 1440,
            );
            final r = w.relativeTo(departure);
            expect(r.startMinutes, greaterThanOrEqualTo(0));
            expect(r.endMinutes, greaterThanOrEqualTo(r.startMinutes));
          }
        }
      }
    });
  });

  group('StopTimeWindow.clockFromRelative', () {
    test('projects an ETA back onto the wall clock', () {
      expect(StopTimeWindow.clockFromRelative(_at(8), 90), _at(9, 30));
    });

    test('wraps past midnight', () {
      expect(StopTimeWindow.clockFromRelative(_at(23), 120), _at(1));
    });
  });

  group('StopTimeWindow serialization', () {
    test('round-trips through JSON', () {
      final w = _w(14, 15, 15, 45);
      expect(StopTimeWindow.fromJson(w.toJson()), w);
    });

    test('rejects junk instead of throwing', () {
      expect(StopTimeWindow.fromJson(null), isNull);
      expect(StopTimeWindow.fromJson('14:00'), isNull);
      expect(StopTimeWindow.fromJson({'start': 60}), isNull);
      expect(StopTimeWindow.fromJson({'start': -1, 'end': 60}), isNull);
      expect(StopTimeWindow.fromJson({'start': 0, 'end': 1440}), isNull);
    });
  });

  group('RoutePointModel wire format', () {
    test('omits the window keys entirely when the stop has no deadline', () {
      final json = const RoutePointModel(
        address: 'A',
        lat: 1,
        lon: 2,
        weight: 10,
      ).toJson();
      // Absent, not null: the backend then applies its own 0..480 default
      // rather than us pinning every stop to a window we didn't choose.
      expect(json.containsKey('time_window_start'), isFalse);
      expect(json.containsKey('time_window_end'), isFalse);
    });

    test('sends relative minutes when the stop has a deadline', () {
      final json = const RoutePointModel(
        address: 'A',
        lat: 1,
        lon: 2,
        weight: 10,
        timeWindowStart: 60,
        timeWindowEnd: 180,
      ).toJson();
      expect(json['time_window_start'], 60);
      expect(json['time_window_end'], 180);
    });

    test('parses the response arrival time when present', () {
      final p = RoutePointModel.fromJson({
        'address': 'A',
        'lat': 1,
        'lon': 2,
        'weight': 10,
        'arrival_time': 42,
      });
      expect(p.arrivalTimeMinutes, 42);
    });
  });

  group('RouteRequestModel wire format', () {
    Map<String, dynamic> build({int driverHours = 8}) => RouteRequestModel(
      numVehicles: 1,
      vehicleCapacity: 10000,
      depotLat: 33.8,
      depotLon: 35.5,
      routingMode: 'car',
      timeLimitSeconds: 4,
      driverHours: driverHours,
      defaultServiceTimeMinutes: 5,
      deliveries: const [],
    ).toJson();

    test('sends driver_hours, not the unsupported max_vehicle_time', () {
      final json = build();
      expect(json['driver_hours'], 8);
      expect(json['default_service_time'], 5);
      // max_vehicle_time is not in the backend schema — it was silently
      // discarded, so sending it only made the payload look meaningful.
      expect(json.containsKey('max_vehicle_time'), isFalse);
    });
  });

  group('RoutingConfig.driverHoursForHorizon', () {
    test('keeps the default day when every window fits inside it', () {
      expect(RoutingConfig.driverHoursForHorizon(120), 8);
      expect(RoutingConfig.driverHoursForHorizon(480), 8);
    });

    test('stretches the day to contain a later window', () {
      // A stop due 11 hours out would be unreachable in an 8-hour day.
      expect(RoutingConfig.driverHoursForHorizon(660), 11);
      expect(RoutingConfig.driverHoursForHorizon(661), 12);
    });

    test('never exceeds a full day', () {
      expect(RoutingConfig.driverHoursForHorizon(5000), 24);
    });
  });
}
