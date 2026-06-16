import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../error/exceptions.dart';

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

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );

    return LatLng(pos.latitude, pos.longitude);
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
