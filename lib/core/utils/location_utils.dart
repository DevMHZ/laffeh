import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../error/exceptions.dart';
import 'debug_log.dart';

/// Centralised wrapper around Geolocator.
///
/// All location-related branching (services disabled, permission
/// denied, permission denied forever) is contained here so the
/// repository / cubit just calls [getCurrentLatLng] and handles
/// a [LocationException].
class LocationUtils {
  LocationUtils._();

  static Future<LatLng> getCurrentLatLng() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    DebugLog.loc('getCurrentLatLng() serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) {
      throw const LocationException('LOCATION_SERVICE_DISABLED');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('LOCATION_PERMISSION_DENIED');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('LOCATION_PERMISSION_DENIED_FOREVER');
    }
    DebugLog.loc('getCurrentLatLng() permission=$permission — fetching fix…');

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );

    // Raw fix detail: on the Simulator this is the static "custom location"
    // (accuracy fixed, mocked=true), versus a noisy real fix on a phone.
    DebugLog.loc(
      'getCurrentLatLng() fix=${pos.latitude.toStringAsFixed(6)},'
      '${pos.longitude.toStringAsFixed(6)} '
      'acc=${pos.accuracy.toStringAsFixed(1)}m '
      'heading=${pos.heading.toStringAsFixed(1)} '
      'speed=${pos.speed.toStringAsFixed(2)}m/s '
      'mocked=${pos.isMocked}',
    );

    return LatLng(pos.latitude, pos.longitude);
  }

  /// The OS's last cached fix — returns (almost) instantly, with no wait for
  /// a fresh GPS lock, or null if there's none yet. Used to make "go to my
  /// location" respond immediately, then refine with [getCurrentLatLng].
  static Future<LatLng?> getLastKnownLatLng() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      DebugLog.loc(
        'getLastKnownLatLng() cached=${pos.latitude.toStringAsFixed(6)},'
        '${pos.longitude.toStringAsFixed(6)} acc=${pos.accuracy.toStringAsFixed(1)}m',
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      DebugLog.loc('getLastKnownLatLng() failed: $e');
      return null;
    }
  }

  /// Backs the "Enable location" button on the error banner.
  ///
  /// Inspects, at tap time, whatever is actually blocking access and
  /// sends the user straight to the fix:
  ///   * services off   → open the OS location settings
  ///   * merely denied   → re-show the OS permission prompt
  ///   * denied forever  → open the app's settings page
  ///
  /// Returns true only when services are on AND permission is granted —
  /// i.e. the caller can now retry fetching a position.
  static Future<bool> resolveAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
