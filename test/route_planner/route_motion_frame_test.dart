import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:laffeh/features/route_planner/presentation/utils/route_motion_frame.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/map_geometry.dart';

const route = [
  LatLng(33.89, 35.50),
  LatLng(33.89, 35.51),
  LatLng(33.90, 35.51),
  LatLng(33.90, 35.52),
];

Map<String, dynamic> frame(
  double progress, {
  List<LatLng> path = route,
  double? nextStop,
  double rotation = 0,
  LatLng? fallback,
}) => RouteMotionFrame.build(
  path: path,
  progress: progress,
  image: 'test-car',
  imageScale: 1,
  rotation: rotation,
  nextStop: nextStop,
  fallbackPosition: fallback,
);

List<dynamic> features(Map<String, dynamic> value) => value['features'] as List;
Map<String, dynamic> feature(Map<String, dynamic> value, String role) =>
    features(value).singleWhere((f) => f['properties']['role'] == role)
        as Map<String, dynamic>;
List<dynamic> coordinates(Map<String, dynamic> value, String role) =>
    feature(value, role)['geometry']['coordinates'] as List;

void main() {
  group('a native frame joins the route exactly at the car', () {
    test('preview stays joined at normal speed, fast playback and rewinds', () {
      for (final p in [0.001, 0.015, 0.3, 0.92, 0.2, 0.21, 1.0]) {
        final value = frame(p);
        expect(coordinates(value, 'trail').last, coordinates(value, 'vehicle'));
        expect(features(value), hasLength(2));
      }
    });

    test('driving current and completed legs share the vehicle endpoint', () {
      for (final p in [0.01, 0.3, 0.5, 0.75, 0.999]) {
        final value = frame(p, nextStop: 1);
        final car = coordinates(value, 'vehicle');
        expect(coordinates(value, 'done').last, car);
        expect(coordinates(value, 'trail').first, car);
        expect(coordinates(value, 'trail').last, [35.52, 33.90]);
      }
    });

    test('starting, arriving and finishing do not draw past the vehicle', () {
      expect(features(frame(0)), hasLength(1));
      final start = frame(0, nextStop: 0.5);
      expect(coordinates(start, 'trail').first, [35.50, 33.89]);
      final arrival = frame(0.5, nextStop: 0.5);
      expect(features(arrival), hasLength(2)); // car and completed leg only
      expect(
        coordinates(arrival, 'done').last,
        coordinates(arrival, 'vehicle'),
      );
      final end = frame(1, nextStop: 1);
      expect(features(end), hasLength(2));
      expect(coordinates(end, 'done').last, [35.52, 33.90]);
    });

    test(
      'loops and duplicate vertices preserve the correct route traversal',
      () {
        final loop = [...route, route.last, route.first];
        final original = List<LatLng>.of(loop);
        for (final p in [0.001, 0.25, 0.5, 0.9, 1.0]) {
          final value = frame(p, path: loop, nextStop: 1);
          final car = coordinates(value, 'vehicle');
          expect(coordinates(value, 'done').last, car);
          if (p < 1) expect(coordinates(value, 'trail').first, car);
        }
        expect(
          loop,
          original,
          reason: 'Rendering must not mutate saved geometry',
        );
        expect(coordinates(frame(1, path: loop), 'vehicle'), [35.50, 33.89]);
      },
    );

    test('camera-relative rotation cannot move any geographic geometry', () {
      final original = frame(0.37, nextStop: 0.8);
      for (final rotation in [-180.0, -90.0, 45.0, 180.0]) {
        final rotated = frame(0.37, nextStop: 0.8, rotation: rotation);
        for (final role in ['vehicle', 'done', 'trail']) {
          expect(coordinates(rotated, role), coordinates(original, role));
        }
        expect(feature(rotated, 'vehicle')['properties']['rotation'], rotation);
      }
    });

    test('missing geometry falls back to GPS without fabricating a road', () {
      final value = frame(0.3, path: [], fallback: const LatLng(1, 2));
      expect(features(value), hasLength(1));
      expect(coordinates(value, 'vehicle'), [2, 1]);
      expect(frame(0.3, path: []), MapGeometry.emptyGeoJson);
      expect(features(frame(0.3, path: [route.first])), hasLength(1));
      expect(
        features(frame(0.3, path: [route.first, route.first])),
        hasLength(1),
      );
    });

    test('progress outside the trip is clamped to a valid endpoint', () {
      for (final p in [-1.0, double.nan, double.infinity]) {
        expect(coordinates(frame(p), 'vehicle'), [35.50, 33.89]);
      }
      expect(coordinates(frame(2), 'vehicle'), [35.52, 33.90]);
    });
  });

  group('native updates cannot race or replay stale positions', () {
    test(
      'slow native writes coalesce queued motion to the latest frame',
      () async {
        final firstWrite = Completer<void>();
        final latestWritten = Completer<void>();
        final written = <int>[];
        final writer = LatestFrameWriter<int>((value) async {
          written.add(value);
          if (value == 1) await firstWrite.future;
          if (value == 4) latestWritten.complete();
        });
        writer.submit(1);
        writer.submit(2);
        writer.submit(3);
        writer.submit(4);
        expect(written, [1]);
        firstWrite.complete();
        await latestWritten.future;
        expect(written, [1, 4]);
        writer.dispose();
      },
    );

    test(
      'exiting clears after an in-flight frame and discards queued cars',
      () async {
        final firstWrite = Completer<void>();
        final cleared = Completer<void>();
        final written = <Map<String, dynamic>>[];
        final writer = LatestFrameWriter<Map<String, dynamic>>((value) async {
          written.add(value);
          if (written.length == 1) await firstWrite.future;
          if (features(value).isEmpty) cleared.complete();
        });
        writer.submit(frame(0.3));
        writer.submit(frame(0.4));
        writer.submit(MapGeometry.emptyGeoJson);
        firstWrite.complete();
        await cleared.future;
        expect(written, hasLength(2));
        expect(written.last, MapGeometry.emptyGeoJson);
        writer.dispose();
      },
    );

    test('a failed native call cannot strand the next frame', () async {
      final firstWrite = Completer<void>();
      final recovered = Completer<void>();
      final errors = <Object>[];
      final written = <int>[];
      final writer = LatestFrameWriter<int>((value) async {
        written.add(value);
        if (value == 1) {
          await firstWrite.future;
          throw StateError('native source temporarily unavailable');
        }
        recovered.complete();
      }, onError: (error, _) => errors.add(error));
      writer.submit(1);
      writer.submit(2);
      firstWrite.complete();
      await recovered.future;
      expect(errors, hasLength(1));
      expect(written, [1, 2]);
      writer.dispose();
    });

    test(
      'disposing drops pending work and ignores further submissions',
      () async {
        final firstWrite = Completer<void>();
        final written = <int>[];
        final writer = LatestFrameWriter<int>((value) async {
          written.add(value);
          await firstWrite.future;
        });
        writer.submit(1);
        writer.submit(2);
        writer.dispose();
        writer.submit(3);
        firstWrite.complete();
        await Future<void>.delayed(Duration.zero);
        expect(written, [1]);
      },
    );
  });
}
