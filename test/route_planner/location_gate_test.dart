import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:laffeh/core/services/location_gate.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

Position _fix(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// A Geolocator scripted per test, counting the two calls that matter: how
/// often the OS prompt was raised, and whether a cold fix was asked for.
class _FakeGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  _FakeGeolocator({
    this.servicesEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.grantsOnRequest,
    this.cachedFix,
    this.freshFixFails = false,
  });

  bool servicesEnabled;
  LocationPermission permission;

  /// What [requestPermission] answers — null means "whatever it already was".
  LocationPermission? grantsOnRequest;
  Position? cachedFix;
  bool freshFixFails;

  int prompts = 0;
  int freshFixes = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return permission = grantsOnRequest ?? permission;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => cachedFix;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    freshFixes++;
    if (freshFixFails) throw TimeoutException('no lock');
    return _fix(33.5131, 36.2767);
  }
}

void main() {
  late _FakeGeolocator geo;

  void install(_FakeGeolocator fake) {
    geo = fake;
    GeolocatorPlatform.instance = fake;
  }

  group('resolve', () {
    test(
      'asks when the OS still allows a prompt, and takes yes for an answer',
      () async {
        install(
          _FakeGeolocator(
            permission: LocationPermission.denied,
            grantsOnRequest: LocationPermission.whileInUse,
            cachedFix: _fix(33.5, 36.3),
          ),
        );

        expect(await LocationGate.resolve(), LocationAccess.granted);
        expect(geo.prompts, 1);
      },
    );

    test('a refusal the OS will ask about again is `denied`', () async {
      install(
        _FakeGeolocator(
          permission: LocationPermission.denied,
          grantsOnRequest: LocationPermission.denied,
        ),
      );

      expect(await LocationGate.resolve(), LocationAccess.denied);
      expect(geo.prompts, 1);
    });

    test('a permanent refusal is `blocked`, and is not prompted for', () async {
      install(_FakeGeolocator(permission: LocationPermission.deniedForever));

      expect(await LocationGate.resolve(), LocationAccess.blocked);
      expect(geo.prompts, 0, reason: 'the OS would never show the prompt');
    });

    test('location switched off device-wide outranks the permission', () async {
      install(
        _FakeGeolocator(
          servicesEnabled: false,
          permission: LocationPermission.whileInUse,
        ),
      );

      expect(await LocationGate.resolve(), LocationAccess.servicesOff);
    });

    test('a cached fix is enough — no cold lock is waited for', () async {
      install(_FakeGeolocator(cachedFix: _fix(33.5, 36.3)));

      expect(await LocationGate.resolve(), LocationAccess.granted);
      expect(geo.freshFixes, 0);
    });

    test('with nothing cached it does wait for a fresh fix', () async {
      install(_FakeGeolocator(cachedFix: null));

      expect(await LocationGate.resolve(), LocationAccess.granted);
      expect(geo.freshFixes, 1);
    });

    test(
      'a fix that never lands is still granted — permission is the point',
      () async {
        install(_FakeGeolocator(cachedFix: null, freshFixFails: true));

        expect(await LocationGate.resolve(), LocationAccess.granted);
      },
    );
  });

  group('status', () {
    test('never prompts and never fetches', () async {
      install(_FakeGeolocator(permission: LocationPermission.denied));

      expect(await LocationGate.status(), LocationAccess.denied);
      expect(geo.prompts, 0);
      expect(geo.freshFixes, 0);
    });

    test(
      'reports a permission granted while the app was in the background',
      () async {
        install(_FakeGeolocator(permission: LocationPermission.always));

        expect(await LocationGate.status(), LocationAccess.granted);
        expect(geo.freshFixes, 0);
      },
    );
  });
}
