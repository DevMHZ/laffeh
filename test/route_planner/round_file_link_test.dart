/// A round file tapped in Mail or Files.
///
/// Found on the simulator: iOS copies a tapped `.laffa` into
/// `Documents/Inbox/` and reopens the app with a `file://` URL, which
/// arrives on the *deep link* channel, not the share stream. The handler
/// only skipped `sharemedia-` links, so the file URL fell through to the
/// text path — the round never opened, and the full local path was sent to
/// Photon and Nominatim as a search query. Broken, and a leak.
library;

import 'package:flutter_test/flutter_test.dart';

/// The classifier as the handler applies it.
String? roundFilePath(Uri uri) {
  final decoded = Uri.decodeFull(uri.path);
  if (!decoded.toLowerCase().split('?').first.endsWith('.laffa')) return null;
  return uri.scheme.toLowerCase() == 'file' ? decoded : uri.toString();
}

void main() {
  group('a tapped round file is not a search query', () {
    test('the iOS Inbox path is recognised', () {
      expect(
        roundFilePath(Uri.parse('file:///var/mobile/.../Documents/Inbox/Ali.laffa')),
        endsWith('/Documents/Inbox/Ali.laffa'),
      );
    });

    test('a percent-encoded Arabic name decodes before the suffix is read', () {
      // A round for a driver called أحمد arrives URL-encoded; without
      // decoding, the name does not end in ".laffa" and the file is missed.
      final encoded = Uri.encodeFull('/Documents/Inbox/أحمد.laffa');
      final path = roundFilePath(Uri.parse('file://$encoded'));
      expect(path, isNotNull);
      expect(path, endsWith('أحمد.laffa'));
    });

    test('an Android content:// hand-off keeps its URI form', () {
      // Not a filesystem path — the platform resolves it, so it must be
      // passed through whole rather than reduced to uri.path.
      final uri = Uri.parse('content://com.android.providers/doc/Ali.laffa');
      expect(roundFilePath(uri), 'content://com.android.providers/doc/Ali.laffa');
    });

    test('a query string after the name does not hide it', () {
      expect(
        roundFilePath(Uri.parse('file:///tmp/Ali.laffa?token=x')),
        isNotNull,
      );
    });

    test('case is not significant', () {
      expect(roundFilePath(Uri.parse('file:///tmp/ALI.LAFFA')), isNotNull);
    });
  });

  group('everything else still goes to the planner as text', () {
    test('a shared Google Maps link is not a round file', () {
      expect(
        roundFilePath(Uri.parse('https://maps.app.goo.gl/abc123')),
        isNull,
      );
    });

    test('a deep link is not a round file', () {
      expect(roundFilePath(Uri.parse('laffeh://open?stop=1')), isNull);
    });

    test('a file that is not a round is not treated as one', () {
      expect(roundFilePath(Uri.parse('file:///tmp/photo.jpg')), isNull);
      expect(roundFilePath(Uri.parse('file:///tmp/stops.csv')), isNull);
    });
  });
}
