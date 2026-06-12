import 'package:latlong2/latlong.dart';

class LinkParser {
  LinkParser._();

  static LatLng? tryParseMapUrl(String input) {
    final trimmed = input.trim();

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.scheme == 'geo') {
      final queryPoint = uri.queryParameters['q'];
      if (queryPoint != null && queryPoint.trim().isNotEmpty) {
        final parsed = parseLatLngPair(queryPoint);
        if (parsed != null) return parsed;
      }
      return parseLatLngPair(uri.path);
    }

    if (uri.scheme == 'google.navigation') {
      final q = uri.queryParameters['q'];
      if (q != null && q.trim().isNotEmpty) return parseLatLngPair(q);
    }

    if (!trimmed.startsWith('http')) return null;

    final host = uri.host;

    // ── Google Maps ────────────────────────────────────────────
    if (host.contains('google')) {
      return _parseGoogleMaps(uri);
    }

    // ── Apple Maps ────────────────────────────────────────────
    if (host.contains('apple')) {
      return _parseAppleMaps(uri);
    }

    // ── What3words / Waze / others — could extend here ─────────
    return null;
  }

  static LatLng? _parseGoogleMaps(Uri uri) {
    // Format 1:  ?q=lat,lng
    //   https://maps.google.com/?q=33.5131,36.2767
    //   https://www.google.com/maps?q=33.5131,36.2767
    final q = uri.queryParameters['q'];
    if (q != null && q.trim().isNotEmpty) {
      final result = parseLatLngPair(q);
      if (result != null) return result;
    }

    final query = uri.queryParameters['query'];
    if (query != null && query.trim().isNotEmpty) {
      final result = parseLatLngPair(query);
      if (result != null) return result;
    }

    final destination = uri.queryParameters['destination'];
    if (destination != null && destination.trim().isNotEmpty) {
      final result = parseLatLngPair(destination);
      if (result != null) return result;
    }

    // Format 2:  @lat,lng,zoom   (often in paths)
    //   https://www.google.com/maps/place/.../@33.5131,36.2767,15z
    final atMatch = RegExp(
      r'@(-?\d+\.\d+),(-?\d+\.\d+)',
    ).firstMatch(uri.toString());
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    // Format 3:  ll=lat,lng   (old-style)
    final ll = uri.queryParameters['ll'];
    if (ll != null && ll.trim().isNotEmpty) {
      final result = parseLatLngPair(ll);
      if (result != null) return result;
    }

    return null;
  }

  static LatLng? _parseAppleMaps(Uri uri) {
    //  https://maps.apple.com/?ll=33.5131,36.2767
    final ll = uri.queryParameters['ll'];
    if (ll != null && ll.trim().isNotEmpty) {
      return parseLatLngPair(ll);
    }
    //  https://maps.apple.com/?q=33.5131,36.2767
    final q = uri.queryParameters['q'];
    if (q != null && q.trim().isNotEmpty) {
      return parseLatLngPair(q);
    }
    return null;
  }

  /// Parse "lat,lng" or "lat, lng" into a [LatLng].
  static LatLng? parseLatLngPair(String raw) {
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }
}
