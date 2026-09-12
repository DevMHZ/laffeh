import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/utils/link_parser.dart';
import 'package:laffeh/core/utils/map_link_resolver.dart';

// Real public business URL from coraloil.com/locations/, with Google's
// September 2026 landing-page response reduced to its navigation metadata.
const short = 'https://maps.app.goo.gl/EiShnE2YnJaHXNY19';
const place =
    'https://www.google.com/maps/place/coral+-+Gas+Station/'
    '@33.8862936,35.5038002,65m/data=!3m1!1e3!4m6!3m5!1s0x151f171eced21bbd:'
    '0xe72fb932edcff2e5!8m2!3d33.886273!4d35.5038449!16s%2Fg%2F1tn8nxh4';

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

void main() {
  test('a business pin takes priority over the map camera centre', () {
    final point = LinkParser.tryParseMapUrl(place)!;
    expect(point.latitude, 33.886273);
    expect(point.longitude, 35.5038449);
    expect(LinkParser.placeLabel(Uri.parse(place)), 'coral - Gas Station');
  });

  test('encoded place coordinates, integer values and validity checks', () {
    expect(
      LinkParser.tryParseMapUrl(
        'https://www.google.fr/maps/place/Cafe/data=%213d33%214d35',
      )?.latitude,
      33,
    );
    expect(
      LinkParser.tryParseMapUrl(
        'https://www.google.com/maps/place/Cafe/data=!3d91!4d35',
      ),
      isNull,
    );
    expect(LinkParser.parseLatLngPair('NaN,35'), isNull);
    expect(
      LinkParser.tryParseMapUrl('https://fakegoogle.com/maps?q=33,35'),
      isNull,
    );
  });

  test('a share caption does not prevent extracting the map link', () {
    expect(LinkParser.extractMapUrls('Restaurant\n($short)\n'), [short]);
    expect(LinkParser.extractMapUrls('Cafe $place'), [place]);
    expect(LinkParser.tryParseMapUrl('Go here: $place')?.longitude, 35.5038449);
  });

  test(
    'follows a 200 landing page, redirect and EU consent to the POI',
    () async {
      final desktop = '$short?_imcp=1&test=1';
      final consent =
          'https://consent.google.com/m?continue=${Uri.encodeComponent(place)}';
      final pages = _Pages({
        short: ResponseBody.fromString(
          '<div data-desktop-link="$short?_imcp=1&amp;test=1"></div>',
          200,
        ),
        desktop: ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': [consent],
          },
        ),
      });
      final dio = Dio()..httpClientAdapter = pages;
      final result = await MapLinkResolver.resolveMapLine(short, client: dio);
      expect(result?.latLng.latitude, 33.886273);
      expect(result?.latLng.longitude, 35.5038449);
      expect(pages.requests, [short, desktop]);
      dio.close();
    },
  );

  test(
    'a direct POI and a pasted caption resolve without network access',
    () async {
      final pages = _Pages({});
      final dio = Dio()..httpClientAdapter = pages;
      final result = await MapLinkResolver.resolveMapLine(
        'Restaurant $place',
        client: dio,
      );
      expect(result?.label, 'coral - Gas Station');
      expect(result?.latLng.longitude, 35.5038449);
      expect(pages.requests, isEmpty);
      dio.close();
    },
  );

  test('Apple short redirects still resolve', () async {
    const apple = 'https://maps.apple/p/example';
    final pages = _Pages({
      apple: ResponseBody.fromString(
        '',
        301,
        headers: {
          'location': [
            'https://maps.apple.com/place?coordinate=33.8,35.5&name=Cafe',
          ],
        },
      ),
    });
    final dio = Dio()..httpClientAdapter = pages;
    final result = await MapLinkResolver.resolveMapLine(apple, client: dio);
    expect(result?.latLng.latitude, 33.8);
    expect(result?.label, 'Cafe');
    dio.close();
  });

  test('redirect loops, failures and off-provider links fail safely', () async {
    for (final response in [
      ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [short],
        },
      ),
      ResponseBody.fromString(
        '<div data-desktop-link="https://other.example/place"></div>',
        200,
      ),
      ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['http://127.0.0.1/place'],
        },
      ),
      ResponseBody.fromString('', 503),
      ResponseBody.fromString(
        '<meta content="33.8,35.5" property="og:image">',
        200,
      ),
    ]) {
      final pages = _Pages({short: response});
      final dio = Dio()..httpClientAdapter = pages;
      expect(await MapLinkResolver.parseMapLine(short, client: dio), isNull);
      expect(pages.requests, [short]);
      dio.close();
    }
  });
}
