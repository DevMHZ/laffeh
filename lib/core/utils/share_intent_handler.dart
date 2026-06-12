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

  /// Stream of shared text or map URLs arriving while the app is running.
  static Stream<String> get stream => _controller.stream;

  /// Call once from `main()`. Checks for initial shares/deep links that
  /// launched the app, then subscribes to live updates.
  static void init() {
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
          final text = _extractText(files);
          if (text != null) _emit(text);
        })
        .catchError((_) {});

    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((
      List<SharedMediaFile> files,
    ) {
      final text = _extractText(files);
      if (text != null) _emit(text);
    });

    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) _emit(uri.toString());
        })
        .catchError((_) {});

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => _emit(uri.toString()),
      onError: (_) {},
    );
  }

  static String? _extractText(List<SharedMediaFile> files) {
    if (files.isEmpty) return null;
    final texts = files
        .where((f) => f.type == SharedMediaType.text)
        .map((f) => f.path)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (texts.isEmpty) return null;
    return texts.join('\n');
  }

  static void _emit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
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
