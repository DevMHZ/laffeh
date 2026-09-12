import 'package:latlong2/latlong.dart';

class LinkParser {
  LinkParser._();

  static bool isGoogleMapsHost(String host) => RegExp(
    r'^(?:(?:www|maps|consent)\.)?google\.(?:com|[a-z]{2}|(?:co|com)\.[a-z]{2})$',
  ).hasMatch(host.toLowerCase());

  static bool isMapUri(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return isGoogleMapsHost(host) ||
        host == 'maps.app.goo.gl' ||
        (host == 'goo.gl' && uri.path.startsWith('/maps')) ||
        host == 'maps.apple' ||
        host == 'maps.apple.com';
  }

  /// A share may contain a business name before its URL. Extract only map
  /// URLs; ordinary addresses still go through the existing text importer.
  static List<String> extractMapUrls(String text) {
    final urls = <String>[];
    for (final match in RegExp(r'''https?://[^\s<>"']+''').allMatches(text)) {
      var value = match.group(0)!;
      while (value.endsWith('.') ||
          value.endsWith(',') ||
          (value.endsWith(')') &&
              ')'.allMatches(value).length > '('.allMatches(value).length)) {
        value = value.substring(0, value.length - 1);
      }
      final uri = Uri.tryParse(value);
      if (uri != null && isMapUri(uri)) urls.add(value);
    }
    return urls;
  }

  static String? placeLabel(Uri uri) {
    if (uri.host.startsWith('consent.google.')) {
      final next = Uri.tryParse(uri.queryParameters['continue'] ?? '');
      if (next != null && next.host != uri.host && isMapUri(next)) {
        return placeLabel(next);
      }
      return null;
    }
    final parts = uri.pathSegments;
    final place = parts.indexOf('place');
    if (place >= 0 && place + 1 < parts.length) {
      final name = parts[place + 1].replaceAll('+', ' ').trim();
      if (name.isNotEmpty &&
          !name.startsWith('data=') &&
          !name.startsWith('@') &&
          parseLatLngPair(name) == null) {
        return name;
      }
    }
    final name = uri.queryParameters['name'];
    return name == null || name.trim().isEmpty ? null : name.trim();
  }

  static LatLng? tryParseMapUrl(String input) {
    final trimmed = extractMapUrls(input).firstOrNull ?? input.trim();

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
    if (isGoogleMapsHost(host)) {
      return _parseGoogleMaps(uri);
    }

    // ── Apple Maps ────────────────────────────────────────────
    if (host == 'maps.apple.com' || host == 'maps.apple') {
      return _parseAppleMaps(uri);
    }

    // ── What3words / Waze / others — could extend here ─────────
    return null;
  }

  static LatLng? _parseGoogleMaps(Uri uri) {
    // Format 0: the EU consent interstitial.
    //   https://consent.google.com/m?continue=https://www.google.com/maps/...
    // A driver in France sharing a pin never reaches Google Maps at all —
    // the redirect lands here first, and the address they actually shared is
    // sitting unread in `continue`. Unwrap it and start again.
    if (uri.host.contains('consent.google')) {
      final onward = uri.queryParameters['continue'];
      if (onward != null && onward.trim().isNotEmpty) {
        final inner = Uri.tryParse(onward.trim());
        if (inner != null && inner.host != uri.host) {
          return tryParseMapUrl(inner.toString());
        }
      }
      return null;
    }

    // The POI coordinates take priority over @lat,lng: @ is only the
    // camera centre, which moves when Google opens its business sidebar.
    final decoded = Uri.decodeFull(uri.toString());
    final dataMatch = RegExp(
      r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
    ).firstMatch(decoded);
    if (dataMatch != null) {
      final point = parseLatLngPair('${dataMatch[1]},${dataMatch[2]}');
      if (point != null) return point;
    }

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

    final ll = uri.queryParameters['ll'];
    if (ll != null && ll.trim().isNotEmpty) {
      final result = parseLatLngPair(ll);
      if (result != null) return result;
    }

    final atMatch = RegExp(
      r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
    ).firstMatch(decoded);
    if (atMatch != null) {
      final point = parseLatLngPair('${atMatch[1]},${atMatch[2]}');
      if (point != null) return point;
    }

    // Format 5:  /maps/search/lat,lng   (short-link redirect target — no
    // place name, just a bare coordinate pair as its own path segment)
    //   https://www.google.com/maps/search/49.043893,+2.030417
    for (final segment in uri.pathSegments) {
      final result = parseLatLngPair(segment);
      if (result != null) return result;
    }

    return null;
  }

  static LatLng? _parseAppleMaps(Uri uri) {
    //  ll:          https://maps.apple.com/?ll=33.5131,36.2767  (classic)
    //  coordinate:  https://maps.apple.com/place?coordinate=33.5131,36.2767&name=…
    //               — what Apple Maps shares on iOS 18+, once the
    //               `maps.apple/p/…` short link has been expanded.
    //  q / sll / daddr: older sharing and directions links.
    for (final key in const ['ll', 'coordinate', 'q', 'sll', 'daddr']) {
      final value = uri.queryParameters[key];
      if (value == null || value.trim().isEmpty) continue;
      final parsed = parseLatLngPair(value);
      if (parsed != null) return parsed;
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
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return null;
    }
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }
}
