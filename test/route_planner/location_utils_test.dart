import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:laffeh/core/error/exceptions.dart';
import 'package:laffeh/core/utils/location_utils.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

Position _fix({Duration age = Duration.zero, double accuracy = 5}) => Position(
  latitude: 24.741394,
  longitude: 46.672497,
  timestamp: DateTime.now().subtract(age),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _Gps extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  Position? cached;
  Future<Position?>? cacheRequest;
  Future<Position>? freshRequest;
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  int freshCalls = 0;
  int cacheCalls = 0;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    cacheCalls++;
    return cacheRequest == null ? cached : await cacheRequest;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    freshCalls++;
    settings = locationSettings;
    return freshRequest == null ? _fix() : await freshRequest!;
  }
}

void main() {
  late GeolocatorPlatform original;
  late _Gps gps;
  setUp(() {
    original = GeolocatorPlatform.instance;
    gps = _Gps();
    GeolocatorPlatform.instance = gps;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('a recent accurate OS fix avoids waiting for GPS again', () async {
    gps.cached = _fix(age: const Duration(seconds: 4));
    final point = await LocationUtils.getCurrentLatLng(
      maxCachedAge: const Duration(seconds: 10),
    );
    expect(point.latitude, gps.cached!.latitude);
    expect(gps.freshCalls, 0);
  });

  test(
    'stale, future-dated and inaccurate cached fixes do not start navigation',
    () async {
      for (final cached in [
        _fix(age: const Duration(minutes: 1)),
        _fix(age: const Duration(seconds: -10)),
        _fix(accuracy: 500),
        _fix(accuracy: double.nan),
      ]) {
        gps.cached = cached;
        final before = gps.freshCalls;
        await LocationUtils.getCurrentLatLng(
          maxCachedAge: const Duration(seconds: 10),
        );
        expect(gps.freshCalls, before + 1);
      }
    },
  );

  test('permission is still required when a cached location exists', () async {
    gps.cached = _fix();
    gps.permission = LocationPermission.deniedForever;
    await expectLater(
      LocationUtils.getCurrentLatLng(maxCachedAge: const Duration(seconds: 10)),
      throwsA(
        isA<LocationException>().having(
          (e) => e.message,
          'message',
          'LOCATION_PERMISSION_DENIED_FOREVER',
        ),
      ),
    );
    expect(gps.cacheCalls, 0);
    expect(gps.freshCalls, 0);
  });

  test(
    'ordinary current-location requests still request a fresh fix',
    () async {
      gps.cached = _fix();
      await LocationUtils.getCurrentLatLng();
      expect(gps.cacheCalls, 0);
      expect(gps.freshCalls, 1);
    },
  );

  testWidgets('an unresponsive cache cannot hold up fresh acquisition', (
    tester,
  ) async {
    gps.cacheRequest = Completer<Position?>().future;
    final request = LocationUtils.getCurrentLatLng(
      maxCachedAge: const Duration(seconds: 10),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await request).latitude, 24.741394);
    expect(gps.freshCalls, 1);
  });

  testWidgets(
    'the Dart deadline applies even when the platform never completes',
    (tester) async {
      gps.freshRequest = Completer<Position>().future;
      const budget = Duration(seconds: 8);
      final request = LocationUtils.getCurrentLatLng(timeout: budget);
      final expectation = expectLater(
        request,
        throwsA(
          isA<LocationException>().having(
            (e) => e.message,
            'message',
            'LOCATION_TIMEOUT',
          ),
        ),
      );
      await tester.pump();
      expect(gps.settings?.timeLimit, budget);
      await tester.pump(budget);
      await expectation;
    },
  );
}
