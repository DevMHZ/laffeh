import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../../../core/config/map_config.dart';

/// The map chrome's backdrop blur, or nothing.
///
/// A BackdropFilter samples its backdrop in a rectangular layer. On older
/// Android GPUs the surrounding ClipOval does not reliably constrain that
/// layer, and a shaded square appears around every round control. Gated on
/// [MapConfig.blurMapChrome], which is off on Android; the fill in front is
/// 92-94% opaque, so what is lost is a few percent of each pixel.
Widget maybeBlurChrome({required double sigma, required Widget child}) {
  if (!MapConfig.blurMapChrome) return child;
  return BackdropFilter.grouped(
    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
