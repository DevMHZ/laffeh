import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Listens for incoming shared text and map links (e.g. from WhatsApp)
/// and exposes them as text so the route planner can consume them.
class ShareIntentHandler {
  ShareIntentHandler._();

  static StreamSubscription<List<SharedMediaFile>>? _sub;
  static StreamSubscription<Uri>? _linkSub;
  static final AppLinks _appLinks = AppLinks();
  static final List<String> _pending = [];
  static final StreamController<String> _controller =
      StreamController<String>.broadcast(onListen: _flushPending);
  static String? _lastEmitted;
  static DateTime? _lastEmittedAt;

  /// How long an identical payload counts as a repeat of the previous one.
  /// Comfortably longer than the few milliseconds the double report takes,
  /// and far shorter than the app-switching a real second share needs.
  static const Duration _repeatWindow = Duration(seconds: 5);

  /// Stream of shared text or map URLs arriving while the app is running.
  static Stream<String> get stream => _controller.stream;

  /// Paths of `.laffa` round files opened from Mail, Files or a file
  /// manager. Kept separate from [stream]: a round is a whole plan to load,
  /// not a line of text to geocode.
  static Stream<String> get fileStream => _fileController.stream;

  static final List<String> _pendingFiles = [];
  static final StreamController<String> _fileController =
      StreamController<String>.broadcast(onListen: _flushPendingFiles);

  static void _flushPendingFiles() {
    if (_pendingFiles.isEmpty) return;
    final queued = List<String>.from(_pendingFiles);
    _pendingFiles.clear();
    for (final path in queued) {
      _fileController.add(path);
    }
  }

  static void _emitFile(String path) {
    if (_fileController.hasListener) {
      _fileController.add(path);
    } else {
      // The planner may not be mounted yet when a file *launches* the app.
      _pendingFiles.add(path);
    }
  }

  /// Round files among a share payload, by extension.
  ///
  /// Extension rather than MIME type on purpose: mail clients routinely
  /// hand an unknown type over as application/octet-stream, so the name is
  /// the only reliable signal we get.
  static List<String> _extractRoundFiles(List<SharedMediaFile> files) => files
      .map((f) => f.path)
      .where((path) => path.toLowerCase().split('?').first.endsWith('.laffa'))
      .toList();

  /// Call once from `main()`. Checks for initial shares/deep links that
  /// launched the app, then subscribes to live updates.
  ///
  /// Shares arrive on both platforms: Android through the SEND intent filters,
  /// iOS through the Share Extension target in `ios/Share Extension`. Deep
  /// links (`laffeh://`) are wired on both too.
  static void init() {
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
          for (final path in _extractRoundFiles(files)) {
            _emitFile(path);
          }
          final text = _extractText(files);
          if (text != null) _emit(text);
        })
        .catchError((_) {});

    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((
      List<SharedMediaFile> files,
    ) {
      for (final path in _extractRoundFiles(files)) {
        _emitFile(path);
      }
      final text = _extractText(files);
      if (text != null) _emit(text);
    });

    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) _emitLink(uri);
        })
        .catchError((_) {});

    _linkSub = _appLinks.uriLinkStream.listen(_emitLink, onError: (_) {});
  }

  /// Deep links only.
  ///
  /// On iOS the Share Extension reopens the app with a private
  /// `ShareMedia-<bundle id>://share` URL, which app_links reports as an
  /// ordinary incoming link. Left alone it would reach the planner as a line
  /// of text and end up geocoded as if it were an address — while the real
  /// payload arrives separately, on the share stream. So drop it here.
  static void _emitLink(Uri uri) {
    if (uri.scheme.toLowerCase().startsWith('sharemedia-')) return;
    _emit(uri.toString());
  }

  static String? _extractText(List<SharedMediaFile> files) {
    if (files.isEmpty) return null;
    // Android hands a shared map link over as plain text; the iOS Share
    // Extension tags the same link `url`, because Apple Maps and Google Maps
    // put a `public.url` attachment on the share sheet. Both are a string in
    // `path` — `MapLinkResolver` does not care which.
    final texts = files
        .where(
          (f) =>
              f.type == SharedMediaType.text || f.type == SharedMediaType.url,
        )
        .map((f) => f.path)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (texts.isEmpty) return null;
    return texts.join('\n');
  }

  /// A share that *launches* the app on iOS is reported twice: once through
  /// `getInitialMedia`, then again on the live stream a few milliseconds
  /// later, both carrying the same text. Each one adds a stop, so the repeat
  /// has to be dropped. Matching on the text within a short window rather
  /// than a "seen it once" flag, because the two arrive in either order and
  /// the very same link shared again later is a legitimate second stop.
  static void _emit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final last = _lastEmittedAt;
    if (trimmed == _lastEmitted &&
        last != null &&
        now.difference(last) < _repeatWindow) {
      return;
    }
    _lastEmitted = trimmed;
    _lastEmittedAt = now;

    if (_controller.hasListener) {
      _controller.add(trimmed);
    } else {
      _pending.add(trimmed);
    }
  }

  static void _flushPending() {
    if (_pending.isEmpty) return;
    final items = List<String>.from(_pending);
    _pending.clear();
    for (final item in items) {
      _controller.add(item);
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _linkSub?.cancel();
    _linkSub = null;
  }
}
