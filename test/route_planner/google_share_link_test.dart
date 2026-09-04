/// Sharing a pin from Google Maps.
///
/// Reported from an Android phone in Cergy, France: "No addresses found.
/// Check the text and try again", with the point never added. Reproduced by
/// following the redirect ourselves — Google answers a browser-shaped
/// request from the EU with a consent interstitial:
///
///   https://consent.google.com/m?continue=https://www.google.com/maps/...
///
/// The resolver followed the redirect, landed on consent.google.com, saw a
/// host containing "google", found no coordinates, and gave up — while the
/// address the driver shared sat unread in `continue`.
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/utils/link_parser.dart';

void main() {
  group('the EU consent interstitial', () {
    test('the real destination is read out of continue=', () {
      final consent = Uri.encodeComponent(
        'https://www.google.com/maps/place/Cergy/@49.0369,2.0631,15z',
      );
      final parsed = LinkParser.tryParseMapUrl(
        'https://consent.google.com/m?continue=$consent&gl=FR&hl=fr&m=1',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(49.0369, 0.0001));
      expect(parsed.longitude, closeTo(2.0631, 0.0001));
    });

    test('an unencoded continue= is handled too', () {
      // Google does not always percent-encode it.
      final parsed = LinkParser.tryParseMapUrl(
        'https://consent.google.com/m?continue=https://www.google.com/maps/'
        'search/49.043893,+2.030417&gl=FR',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(49.043893, 0.0001));
    });

    test('a consent page with nothing to unwrap fails quietly', () {
      expect(
        LinkParser.tryParseMapUrl('https://consent.google.com/m?gl=FR'),
        isNull,
      );
    });

    test('it cannot loop back onto itself', () {
      // A continue= pointing at consent again must not recurse forever.
      final inner = Uri.encodeComponent('https://consent.google.com/m?gl=FR');
      expect(
        LinkParser.tryParseMapUrl(
          'https://consent.google.com/m?continue=$inner',
        ),
        isNull,
      );
    });
  });

  group('coordinates inside a data= blob', () {
    test('!3d!4d is how a shared place carries its position', () {
      // Sharing a *place* gives this and often no @lat,lng at all — the @
      // form describes the map view, not the pin.
      final parsed = LinkParser.tryParseMapUrl(
        'https://www.google.com/maps/place/Parc+de+l%27Horloge/'
        'data=!4m6!3m5!1s0x47e6f0a1b2c3d4e5!8m2!3d49.0369!4d2.0631!16s',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(49.0369, 0.0001));
      expect(parsed.longitude, closeTo(2.0631, 0.0001));
    });

    test('negative coordinates survive', () {
      final parsed = LinkParser.tryParseMapUrl(
        'https://www.google.com/maps/place/X/data=!8m2!3d-33.8688!4d-151.2093',
      );
      expect(parsed!.latitude, closeTo(-33.8688, 0.0001));
      expect(parsed.longitude, closeTo(-151.2093, 0.0001));
    });

    test('consent wrapping a data= blob still resolves', () {
      // The reported case end to end: EU consent hop, then a place URL whose
      // only coordinates are in the data= blob.
      final inner = Uri.encodeComponent(
        'https://www.google.com/maps/place/Parc/data=!8m2!3d49.0369!4d2.0631',
      );
      final parsed = LinkParser.tryParseMapUrl(
        'https://consent.google.com/m?continue=$inner&gl=FR',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(49.0369, 0.0001));
    });
  });

  group('what already worked keeps working', () {
    test('@lat,lng', () {
      final p = LinkParser.tryParseMapUrl(
        'https://www.google.com/maps/place/X/@33.5131,36.2767,15z',
      );
      expect(p!.latitude, closeTo(33.5131, 0.0001));
    });

    test('?q=lat,lng', () {
      final p = LinkParser.tryParseMapUrl(
        'https://maps.google.com/?q=33.5131,36.2767',
      );
      expect(p!.longitude, closeTo(36.2767, 0.0001));
    });

    test('a link with no coordinates anywhere still returns null', () {
      expect(
        LinkParser.tryParseMapUrl('https://www.google.com/maps/place/Cergy'),
        isNull,
      );
    });
  });
}
