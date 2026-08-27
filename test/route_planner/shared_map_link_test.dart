import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/utils/link_parser.dart';
import 'package:laffeh/core/utils/map_link_resolver.dart';

/// The links that reach the app from an iOS share sheet, which is a different
/// set from what Android's WhatsApp import sends.
void main() {
  group('Apple Maps links', () {
    test('reads the coordinate parameter Maps shares on iOS 18+', () {
      final parsed = LinkParser.tryParseMapUrl(
        'https://maps.apple.com/place?coordinate=33.5131,36.2767'
        '&name=My%20Location&map=explore',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(33.5131, 1e-6));
      expect(parsed.longitude, closeTo(36.2767, 1e-6));
    });

    test('still reads the classic ll parameter', () {
      final parsed = LinkParser.tryParseMapUrl(
        'https://maps.apple.com/?ll=33.5131,36.2767',
      );
      expect(parsed?.latitude, closeTo(33.5131, 1e-6));
    });

    test('a short link on its own carries nothing to parse', () {
      expect(
        LinkParser.tryParseMapUrl('https://maps.apple/p/rGRa4_JBvoJPH7'),
        isNull,
      );
    });
  });

  group('short links needing a redirect', () {
    test('recognises Apple\'s bare maps.apple host', () {
      expect(
        MapLinkResolver.looksLikeShortMapLink(
          Uri.parse('https://maps.apple/p/rGRa4_JBvoJPH7'),
        ),
        isTrue,
      );
    });

    test('recognises the maps.apple.com/p form', () {
      expect(
        MapLinkResolver.looksLikeShortMapLink(
          Uri.parse('https://maps.apple.com/p/rGRa4_JBvoJPH7'),
        ),
        isTrue,
      );
    });

    test('leaves a maps.apple.com link that already has coordinates alone', () {
      expect(
        MapLinkResolver.looksLikeShortMapLink(
          Uri.parse('https://maps.apple.com/place?coordinate=33.5,36.2'),
        ),
        isFalse,
      );
    });

    test('still recognises Google short links', () {
      expect(
        MapLinkResolver.looksLikeShortMapLink(
          Uri.parse('https://maps.app.goo.gl/abc123'),
        ),
        isTrue,
      );
    });
  });

  group('Google Maps links', () {
    test('reads the @lat,lng form Safari shares from the Maps web page', () {
      final parsed = LinkParser.tryParseMapUrl(
        'https://www.google.com/maps/@33.5131,36.2767,17z?g_ep=Eg1tbF8yMDI2',
      );
      expect(parsed?.latitude, closeTo(33.5131, 1e-6));
      expect(parsed?.longitude, closeTo(36.2767, 1e-6));
    });
  });
}
