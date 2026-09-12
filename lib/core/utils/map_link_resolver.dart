import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'link_parser.dart';

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
    for (var hop = 0; hop < 10; hop++) {
      if (!LinkParser.isMapUri(uri) || !visited.add(uri.toString())) {
        return null;
      }
      final parsed = LinkParser.tryParseMapUrl(uri.toString());
      if (parsed != null) {
        return ResolvedMapLocation(parsed, label: LinkParser.placeLabel(uri));
      }
      // Follow the destination Google exposes in its consent wrapper. There
      // is no consent action or account session involved in resolving a URL.
      if (uri.host.startsWith('consent.google.')) {
        final onward = uri.queryParameters['continue'];
        if (onward == null) return null;
        uri = Uri.parse(onward);
        continue;
      }
      final response = await dio.getUri<String>(
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
      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        if (location == null || location.isEmpty) return null;
        uri = uri.resolve(location);
        continue;
      }
      if (status != 200) return null;
      final next = _landingLink(response.data ?? '', uri);
      if (next == null) return null;
      uri = next;
    }
    return null;
  }

  /// Only navigation metadata on Maps pages is eligible. Never guess a
  /// coordinate from arbitrary page numbers or a static image's camera centre.
  static Uri? _landingLink(String html, Uri base) {
    for (final pattern in [
      RegExp(
        r'''data-desktop-link\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<link\b[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["']''',
        caseSensitive: false,
      ),
    ]) {
      final value = pattern.firstMatch(html)?.group(1);
      if (value == null) continue;
      final next = base.resolve(
        value.replaceAll('&amp;', '&').replaceAll('&#38;', '&'),
      );
      if (next != base && LinkParser.isMapUri(next)) return next;
    }
    return null;
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
