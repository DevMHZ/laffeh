import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/debug_log.dart';

/// What the app knows about location access — and, when it is not granted,
/// what would actually fix it.
enum LocationAccess {
  /// Permission is granted, and the device has a position to give.
  granted,

  /// Refused, but the OS will still show its prompt again — asking is enough.
  denied,

  /// Refused for good. Only the app's page in the system settings undoes it.
  blocked,

  /// Not a permission problem: location services are off device-wide.
  servicesOff,
}

/// Settles the location question before the driver reaches the planner.
///
/// The planner has always asked on its way in and shown a banner when that
/// failed — but by then the map is already open on a fallback city, which
/// reads as if the app simply does not know where you are. Resolving it on the
/// splash means nobody gets inside with the question still open.
class LocationGate {
  LocationGate._();

  /// How long to wait for a *first ever* fix, on a device with nothing cached.
  /// Long enough for a cold GPS lock, short enough that a driver indoors is
  /// not held on the splash staring at a logo.
  static const Duration coldFixBudget = Duration(seconds: 8);

  /// Asks once — if the OS will still let us ask — and confirms the device can
  /// actually place the user.
  static Future<LocationAccess> resolve() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesOff;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _classify(permission, warmFix: true);
  }

  /// Status only: no prompt, no fix. For re-checking after the driver has been
  /// sent out to the system settings and come back.
  static Future<LocationAccess> status() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesOff;
    }
    return _classify(await Geolocator.checkPermission(), warmFix: false);
  }

  static Future<LocationAccess> _classify(
    LocationPermission permission, {
    required bool warmFix,
  }) async {
    switch (permission) {
      case LocationPermission.deniedForever:
        return LocationAccess.blocked;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        if (warmFix) await _warmFix();
        return LocationAccess.granted;
    }
  }

  /// A cached fix already means the device knows where it is, and it comes
  /// back instantly — so only a device with nothing cached at all pays for a
  /// cold lock. Failing here is not a refusal: permission is what the rest of
  /// the app needs, and the planner fetches again on its way in.
  static Future<void> _warmFix() async {
    try {
      if (await Geolocator.getLastKnownPosition() != null) return;
      // Both limits on purpose: `timeLimit` stops the platform still hunting
      // for satellites after we have given up, `timeout` is what guarantees
      // this returns at all if the platform channel itself wedges.
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: coldFixBudget,
      ).timeout(coldFixBudget);
    } catch (e) {
      DebugLog.loc('LocationGate: no fix while on the splash ($e)');
    }
  }
}
