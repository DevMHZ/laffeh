import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/utils/link_parser.dart';
import 'package:laffeh/core/utils/map_link_resolver.dart';

const _placeId = 'ChIJ3S-JXmauEmsRUcIaWtf4MzE';
const _featureId = '0x6b12ae665e892fdd:0x3133f8d75a1ac251';
const _url =
    'https://www.google.com/maps/search/?api=1&query=Sydney+Opera+House'
    '&query_place_id=$_placeId';
const _preview =
    'https://www.google.com/maps/preview/place?pb=!1m14!1s$_featureId';

// Reduced from Google's declared place preload, fetched 2026-09-21. Keep
// only the identity/name/pin fields we consume, not reviews or other content.
String _details({
  String featureId = _featureId,
  String placeId = _placeId,
  Object? latitude = -33.8567844,
  Object? longitude = 151.2152967,
  String label = 'Sydney Opera House',
}) {
  final record = List<Object?>.filled(79, null);
  record[9] = [null, null, latitude, longitude];
  record[10] = featureId;
  record[11] = label;
  record[78] = placeId;
  return ")]}'\n${jsonEncode([
    null, null, null, null,
    // The camera is deliberately far away from the actual POI.
    [
      [2515996, 4.4025, 51.9881],
    ],
    null, record,
  ])}";
}

class _Pages implements HttpClientAdapter {
  final Map<String, ResponseBody> pages;
  final requests = <String>[];
  _Pages(this.pages);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    expect(options.followRedirects, isFalse);
    return pages[options.uri.toString()] ?? ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

String _shell({String preview = _preview}) =>
    '<link href="$_url" rel="canonical">'
    '<link AS="fetch" href="$preview" REL="preload">';

void main() {
  late _Pages pages;
  late Dio dio;
  void setup(Map<String, ResponseBody> responses) {
    pages = _Pages(responses);
    dio = Dio()..httpClientAdapter = pages;
    addTearDown(dio.close);
  }

  test(
    'official Place ID resolves its pin and name, never the viewport',
    () async {
      setup({
        _url: ResponseBody.fromString(_shell(), 200),
        _preview: ResponseBody.fromString(_details(), 200),
      });
      final result = await MapLinkResolver.resolveMapLine(_url, client: dio);
      expect(result?.label, 'Sydney Opera House');
      expect(result?.latLng.latitude, -33.8567844);
      expect(result?.latLng.longitude, 151.2152967);
      expect(pages.requests, [_url, _preview]);
    },
  );

  test('CID and feature-ID links resolve the same record', () async {
    for (final suffix in [
      'cid=3545450935484072529',
      'ftid=$_featureId',
      'q=place_id:$_placeId',
    ]) {
      final url = 'https://www.google.com/maps?$suffix';
      setup({
        url: ResponseBody.fromString(_shell(), 200),
        _preview: ResponseBody.fromString(_details(), 200),
      });
      final result = await MapLinkResolver.resolveMapLine(url, client: dio);
      expect(result?.latLng.longitude, 151.2152967, reason: suffix);
    }
  });

  test(
    'unsigned 64-bit CID is compared without floating-point rounding',
    () async {
      const cidUrl = 'https://www.google.com/maps?cid=16658737175056085733';
      const preview =
          'https://www.google.com/maps/preview/place?pb=!1s0x0:0xe72fb932edcff2e5';
      setup({
        cidUrl: ResponseBody.fromString(_shell(preview: preview), 200),
        preview: ResponseBody.fromString(
          _details(
            featureId: '0x151f171eced21bbd:0xe72fb932edcff2e5',
            placeId: 'ChIJvRvSzh4XHxUR5fLP7TK5L-c',
            latitude: 33.8820065,
            longitude: 35.9745453,
            label: 'Coral Niha',
          ),
          200,
        ),
      });
      final result = await MapLinkResolver.resolveMapLine(cidUrl, client: dio);
      expect(result?.label, 'Coral Niha');
      expect(result?.latLng.longitude, 35.9745453);
    },
  );

  test('short share can lead to an ID-only business page', () async {
    const short = 'https://maps.app.goo.gl/place';
    setup({
      short: ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [_url],
        },
      ),
      _url: ResponseBody.fromString(_shell(), 200),
      _preview: ResponseBody.fromString(_details(), 200),
    });
    final result = await MapLinkResolver.resolveMapLine(
      'Opera\n$short',
      client: dio,
    );
    expect(result?.label, 'Sydney Opera House');
    expect(pages.requests, [short, _url, _preview]);
  });

  test(
    'ID-only shares follow the EU consent GET redirect without looping',
    () async {
      final consent =
          'https://consent.google.com/m?continue=${Uri.encodeComponent(_url)}';
      const onward = '$_url&ucbcb=1';
      setup({
        _url: ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': [consent],
          },
        ),
        consent: ResponseBody.fromString(
          '',
          303,
          headers: {
            'location': [onward],
          },
        ),
        onward: ResponseBody.fromString(_shell(), 200),
        _preview: ResponseBody.fromString(_details(), 200),
      });
      expect(
        (await MapLinkResolver.resolveMapLine(_url, client: dio))?.label,
        'Sydney Opera House',
      );
      expect(pages.requests, [_url, consent, onward, _preview]);
    },
  );

  test(
    'a shared consent wrapper preserves the requested place identity',
    () async {
      final consent =
          'https://consent.google.com/m?continue=${Uri.encodeComponent(_url)}';
      const onward = '$_url&ucbcb=1';
      setup({
        consent: ResponseBody.fromString(
          '',
          303,
          headers: {
            'location': [onward],
          },
        ),
        onward: ResponseBody.fromString(_shell(), 200),
        _preview: ResponseBody.fromString(
          _details(placeId: 'ChIJOtherPlace'),
          200,
        ),
      });
      expect(
        await MapLinkResolver.resolveMapLine(consent, client: dio),
        isNull,
      );
    },
  );

  test('an identity takes priority over query coordinates and camera centres', () {
    for (final url in [
      '$_url&query=33,35',
      'https://www.google.com/maps?query=33,35&query_place_id=$_placeId',
      'https://www.google.com/maps/place/Other/data=!3d33!4d35?query_place_id=$_placeId',
      'https://www.google.com/maps/@33,35,16z?cid=3545450935484072529',
      'https://www.google.com/maps?ll=33,35&ftid=$_featureId',
      'https://www.google.com/maps/place/Opera/@33,35,16z/data=!1s$_featureId',
    ]) {
      expect(LinkParser.tryParseMapUrl(url), isNull, reason: url);
    }
    expect(
      LinkParser.tryParseMapUrl(
        'https://www.google.com/maps/@33,35,16z',
      )?.latitude,
      33,
    );
  });

  test('requested and preload identities must both match the result', () async {
    for (final details in [
      _details(placeId: 'ChIJOtherPlace'),
      _details(featureId: '0x111:0x222'),
      _details(featureId: 'invalid:0x3133f8d75a1ac251'),
    ]) {
      setup({
        _url: ResponseBody.fromString(_shell(), 200),
        _preview: ResponseBody.fromString(details, 200),
      });
      expect(await MapLinkResolver.resolveMapLine(_url, client: dio), isNull);
    }
  });

  test('a canonical redirect cannot discard the original identity', () async {
    const canonical = 'https://www.google.com/maps/place/Other+Business';
    setup({
      _url: ResponseBody.fromString(
        '<link href="$canonical" rel="canonical">',
        200,
      ),
      canonical: ResponseBody.fromString(_shell(), 200),
      _preview: ResponseBody.fromString(
        _details(placeId: 'ChIJOtherPlace'),
        200,
      ),
    });
    expect(await MapLinkResolver.resolveMapLine(_url, client: dio), isNull);
  });

  test(
    'name-only place may use the identity explicitly supplied in preload',
    () async {
      const url = 'https://www.google.com/maps/place/Sydney+Opera+House';
      setup({
        url: ResponseBody.fromString(_shell(), 200),
        _preview: ResponseBody.fromString(_details(), 200),
      });
      expect(
        (await MapLinkResolver.resolveMapLine(url, client: dio))?.label,
        'Sydney Opera House',
      );
    },
  );

  test(
    'malformed, missing, mismatched and invalid records fail closed',
    () async {
      for (final body in [
        'not JSON',
        '[]',
        '[null,null,null,null,[[-33,151]],null,[]]',
        _details(latitude: '33'),
        _details(latitude: 91),
        _details(longitude: 181),
        _details(label: ''),
      ]) {
        setup({
          _url: ResponseBody.fromString(_shell(), 200),
          _preview: ResponseBody.fromString(body, 200),
        });
        expect(await MapLinkResolver.resolveMapLine(_url, client: dio), isNull);
      }
    },
  );

  test('preload must be a same-origin Google place fetch', () async {
    for (final tag in [
      '<link rel="preload" as="fetch" href="https://example.com/maps/preview/place">',
      '<link rel="preload" as="fetch" href="https://maps.google.com/maps/preview/place">',
      '<link rel="preload" as="fetch" href="http://www.google.com/maps/preview/place">',
      '<link rel="preload" as="fetch" href="https://www.google.com/maps/search?q=33,35">',
      '<link rel="preload" as="image" href="$_preview">',
      '<link rel="prefetch" as="fetch" href="$_preview">',
      '<meta property="og:image" content="https://www.google.com/maps?center=33,35">',
    ]) {
      setup({_url: ResponseBody.fromString(tag, 200)});
      expect(await MapLinkResolver.resolveMapLine(_url, client: dio), isNull);
      expect(pages.requests, [_url]);
    }
  });

  test('preview redirects are never followed', () async {
    setup({
      _url: ResponseBody.fromString(_shell(), 200),
      _preview: ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://example.com'],
        },
      ),
    });
    expect(await MapLinkResolver.resolveMapLine(_url, client: dio), isNull);
    expect(pages.requests, [_url, _preview]);
  });

  test(
    'canonical and Open Graph URLs support either attribute order and entities',
    () async {
      const short = 'https://maps.app.goo.gl/place';
      for (final tag in [
        '<link href="https://maps.google.com/?q=33,35&amp;name=Caf&#233;" REL="canonical">',
        '<META content="https://maps.google.com/?q=33,35&#x26;name=Caf&#233;" property="og:url">',
      ]) {
        setup({short: ResponseBody.fromString(tag, 200)});
        final result = await MapLinkResolver.resolveMapLine(short, client: dio);
        expect(result?.latLng.latitude, 33);
        expect(result?.label, 'Café');
      }
    },
  );

  test(
    'malformed percent encoding does not throw during direct parsing',
    () async {
      const url = 'https://www.google.com/maps/place/%FF?cid=123';
      setup({url: ResponseBody.fromString('', 404)});
      expect(LinkParser.tryParseMapUrl(url), isNull);
      expect(await MapLinkResolver.resolveMapLine(url, client: dio), isNull);
    },
  );

  test('a URL repeated by text and URL providers is imported once', () {
    expect(LinkParser.extractMapUrls('Sydney\n$_url\n$_url'), [_url]);
  });
}
