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
}
