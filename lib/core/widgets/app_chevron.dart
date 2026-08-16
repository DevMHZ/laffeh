import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The "opens something" chevron on a tappable row.
///
/// It points the way the reader moves *forward*: right in English and
/// French, left in Arabic. Both directions used to be wrong, and for the
/// same reason — the icon was hard-coded as `chevron_left_rounded`, which
/// Flutter then mirrored again under RTL. That produced a left-pointing
/// arrow in English and a right-pointing one in Arabic: backwards in every
/// language the app ships.
///
/// The direction is resolved from [Directionality] and the glyph is chosen
/// explicitly, so what the code says is what the screen shows. Leaving it to
/// the icon font's own mirroring is what hid the bug in the first place.
class AppChevron extends StatelessWidget {
  final double size;
  final Color? color;

  const AppChevron({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: size,
      color: color ?? AppColors.textMuted,
      // The glyph is already the right way round; mirroring it again would
      // undo the choice above.
      textDirection: TextDirection.ltr,
    );
  }
}
