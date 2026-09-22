import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'link_parser.dart';
import 'google_place_identity.dart';

class ResolvedMapLocation {
  final LatLng latLng;
  final String? label;
  const ResolvedMapLocation(this.latLng, {this.label});
}

/// Follows map shares without executing their pages. Google can answer a
/// short link with a 200 HTML landing page instead of an HTTP redirect;
/// its data-desktop-link is the next Maps URL, not the end of the lookup.
class MapLinkResolver {
  MapLinkResolver._();

  static Future<LatLng?> parseMapLine(String line, {Dio? client}) async =>
      (await resolveMapLine(line, client: client))?.latLng;

  static Future<ResolvedMapLocation?> resolveMapLine(
    String line, {
    Dio? client,
  }) async {
    final url = LinkParser.extractMapUrls(line).firstOrNull ?? line.trim();
    final initial = Uri.tryParse(url);
    if (initial == null) return null;
    final direct = LinkParser.tryParseMapUrl(url);
    if (direct != null) {
      return ResolvedMapLocation(direct, label: LinkParser.placeLabel(initial));
    }
    if (!LinkParser.isMapUri(initial)) return null;

    final dio =
        client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
    final cancel = CancelToken();
    try {
      return await _resolve(dio, initial, cancel).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          cancel.cancel();
          return null;
        },
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    } finally {
      if (client == null) dio.close(force: true);
    }
  }

  static Future<ResolvedMapLocation?> _resolve(
    Dio dio,
    Uri initial,
    CancelToken cancel,
  ) async {
    var uri = initial;
    final visited = <String>{};
    GooglePlaceIdentity? requestedPlace;
    for (var hop = 0; hop < 10; hop++) {
      if (!LinkParser.isMapUri(uri) || !visited.add(uri.toString())) {
        return null;
      }
      final parsed = LinkParser.tryParseMapUrl(uri.toString());
      if (parsed != null && requestedPlace == null) {
        return ResolvedMapLocation(parsed, label: LinkParser.placeLabel(uri));
      }
      // Coordinates in a consent wrapper were already handled above. An ID-
      // only destination can redirect back to consent, so follow Google's GET
      // response instead of repeatedly unwrapping the same continue URL. No
      // consent form is submitted and no account session or cookie is used.
      Uri? consentDestination;
      if (uri.host.startsWith('consent.google.')) {
        final onward = uri.queryParameters['continue'];
        if (onward == null) return null;
        consentDestination = Uri.tryParse(onward);
        if (consentDestination == null ||
            !LinkParser.isMapUri(consentDestination) ||
            consentDestination.host.startsWith('consent.google.')) {
          return null;
        }
      }
      if (LinkParser.isGoogleMapsHost(uri.host)) {
        requestedPlace ??= GooglePlaceIdentity.fromUri(
          consentDestination ?? uri,
        );
      }
      final response = await _get(dio, uri, cancel);
      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        if (location == null || location.isEmpty) return null;
        uri = uri.resolve(location);
        continue;
      }
      if (status != 200) return null;
      final html = response.data ?? '';
      final preview = _placePreviewLink(html, uri);
      if (preview != null) {
        final details = await _get(dio, preview, cancel);
        if (details.statusCode == 200) {
          final place = _parsePlaceDetails(
            details.data ?? '',
            requestedPlace: requestedPlace,
            previewPlace: GooglePlaceIdentity.fromUri(preview),
          );
          if (place != null) return place;
        }
      }
      final next = _landingLinks(
        html,
        uri,
      ).where((link) => !visited.contains(link.toString())).firstOrNull;
      if (next != null) {
        uri = next;
      } else if (consentDestination != null &&
          !visited.contains(consentDestination.toString())) {
        uri = consentDestination;
      } else {
        return null;
      }
    }
    return null;
  }

  static Future<Response<String>> _get(Dio dio, Uri uri, CancelToken cancel) =>
      dio.getUri<String>(
        uri,
        cancelToken: cancel,
        options: Options(
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/140.0.0.0 Safari/537.36',
          },
        ),
      );

  /// Only Maps navigation metadata is eligible; image centres and arbitrary
  /// numbers elsewhere in the page are never treated as a destination.
  static Iterable<Uri> _landingLinks(String html, Uri base) sync* {
    final desktop = RegExp(
      r'''data-desktop-link\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    final values = <String>[
      for (final match in desktop.allMatches(html)) match.group(1)!,
      for (final attributes in _metadata(html))
        if (_hasToken(attributes['rel'], 'canonical'))
          attributes['href'] ?? ''
        else if (attributes['property']?.toLowerCase() == 'og:url')
          attributes['content'] ?? '',
    ];
    for (final value in values) {
      final next = _metadataUri(value, base);
      if (next != null && next != base && LinkParser.isMapUri(next)) yield next;
    }
  }

  static Uri? _placePreviewLink(String html, Uri base) {
    if (!LinkParser.isGoogleMapsHost(base.host) || base.scheme != 'https') {
      return null;
    }
    for (final attributes in _metadata(html)) {
      if (!_hasToken(attributes['rel'], 'preload') ||
          attributes['as']?.toLowerCase() != 'fetch') {
        continue;
      }
      final next = _metadataUri(attributes['href'] ?? '', base);
      if (next != null &&
          next.origin == base.origin &&
          next.userInfo.isEmpty &&
          next.path == '/maps/preview/place') {
        return next;
      }
    }
    return null;
  }

  /// Google sometimes sends a JS shell for an identified POI. Follow only the
  /// place-detail preload that shell declares, then read its *place* record.
  /// This is an undocumented web format, isolated here to fail closed if it
  /// changes. The initial viewport (root[4]) is deliberately never read.
  static ResolvedMapLocation? _parsePlaceDetails(
    String body, {
    required GooglePlaceIdentity? requestedPlace,
    required GooglePlaceIdentity? previewPlace,
  }) {
    try {
      var json = body.trimLeft();
      if (json.startsWith(")]}'")) json = json.substring(4);
      final root = jsonDecode(json);
      if (root is! List || root.length <= 6) return null;
      final place = root[6];
      if (place is! List || place.length <= 78) return null;
      final coordinates = place[9];
      final featureId = place[10];
      final label = place[11];
      final placeId = place[78];
      if (coordinates is! List ||
          coordinates.length < 4 ||
          coordinates[2] is! num ||
          coordinates[3] is! num ||
          featureId is! String ||
          placeId is! String ||
          label is! String ||
          label.trim().isEmpty ||
          (requestedPlace == null && previewPlace == null)) {
        return null;
      }
      // Preserve the requested identity through redirects. A different place
      // returned by Google must never silently replace the requested stop.
      for (final identity in [requestedPlace, previewPlace].nonNulls) {
        if (!identity.matches(featureId: featureId, placeId: placeId)) {
          return null;
        }
      }
      final point = LinkParser.parseLatLngPair(
        '${coordinates[2]},${coordinates[3]}',
      );
      return point == null
          ? null
          : ResolvedMapLocation(point, label: label.trim());
    } on FormatException {
      return null;
    }
  }

  static Iterable<Map<String, String>> _metadata(String html) sync* {
    final tags = RegExp(r'<(?:link|meta)\b[^>]*>', caseSensitive: false);
    final attribute = RegExp(r'''([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
    for (final tag in tags.allMatches(html)) {
      yield {
        for (final match in attribute.allMatches(tag.group(0)!))
          match.group(1)!.toLowerCase(): match.group(2) ?? match.group(3)!,
      };
    }
  }

  static bool _hasToken(String? value, String token) =>
      value?.toLowerCase().split(RegExp(r'\s+')).contains(token) ?? false;

  static Uri? _metadataUri(String value, Uri base) {
    if (value.trim().isEmpty) return null;
    final decoded = value.replaceAllMapped(
      RegExp(
        r'&(?:amp|quot|apos|lt|gt|#\d+|#x[0-9a-f]+);',
        caseSensitive: false,
      ),
      (match) {
        final entity = match.group(0)!.toLowerCase();
        const named = {
          '&amp;': '&',
          '&quot;': '"',
          '&apos;': "'",
          '&lt;': '<',
          '&gt;': '>',
        };
        if (named.containsKey(entity)) return named[entity]!;
        final hex = entity.startsWith('&#x');
        final code = int.tryParse(
          entity.substring(hex ? 3 : 2, entity.length - 1),
          radix: hex ? 16 : 10,
        );
        return code != null && code > 0 && code <= 0x10ffff
            ? String.fromCharCode(code)
            : match.group(0)!;
      },
    );
    final uri = Uri.tryParse(decoded.trim());
    return uri == null ? null : base.resolveUri(uri);
  }

  @visibleForTesting
  static bool looksLikeShortMapLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'maps.app.goo.gl' ||
        (host == 'goo.gl' && uri.path.startsWith('/maps')) ||
        host == 'maps.apple' ||
        (host == 'maps.apple.com' && uri.pathSegments.firstOrNull == 'p') ||
        host == 'maps.google.com' && uri.pathSegments.contains('maps');
  }
}
