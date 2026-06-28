import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'link_parser.dart';

/// Resolves a pasted line into coordinates: first tries to parse it as a
/// map URL directly, then expands a short link (maps.app.goo.gl, goo.gl…)
/// by following its redirect before re-parsing.
class MapLinkResolver {
  MapLinkResolver._();

  static Future<LatLng?> parseMapLine(String line) async {
    final parsed = LinkParser.tryParseMapUrl(line);
    if (parsed != null) return parsed;

    final uri = Uri.tryParse(line.trim());
    if (uri == null || !_looksLikeShortMapLink(uri)) return null;

    final expanded = await _expandShortMapLink(uri);
    if (expanded == null) return null;
    return LinkParser.tryParseMapUrl(expanded.toString());
  }

  static bool _looksLikeShortMapLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'maps.app.goo.gl' ||
        host == 'goo.gl' ||
        host == 'maps.google.com' && uri.pathSegments.contains('maps');
  }

  static Future<Uri?> _expandShortMapLink(Uri uri) async {
    try {
      final dio = Dio(
        BaseOptions(
          followRedirects: true,
          maxRedirects: 6,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final response = await dio.getUri<String>(uri);
      final realUri = response.realUri;
      if (realUri.toString() != uri.toString()) return realUri;
      final location = response.headers.value('location');
      if (location == null || location.trim().isEmpty) return null;
      return uri.resolve(location.trim());
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
