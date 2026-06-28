import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Brand logo widget.
///
/// The PNG asset is a horizontal lockup painted on the brand navy
/// background. We just clip it to rounded corners and let it sit on
/// any surface — works on both light and dark hosts.
///
/// Variants:
///   * [AfdalLogo.full]    — hero size (splash, settings).
///   * [AfdalLogo.compact] — small chip for top bars.
///   * [AfdalLogo.bare]    — no clipping (icons, tiny tiles).
class AfdalLogo extends StatelessWidget {
  final double height;
  final double radius;
  final bool dropShadow;

  const AfdalLogo._({
    required this.height,
    required this.radius,
    required this.dropShadow,
  });

  factory AfdalLogo.full({double height = 64}) =>
      AfdalLogo._(height: height, radius: 18, dropShadow: true);

  factory AfdalLogo.compact({double height = 32}) =>
      AfdalLogo._(height: height, radius: 9, dropShadow: false);

  factory AfdalLogo.bare({double height = 64}) =>
      AfdalLogo._(height: height, radius: 0, dropShadow: false);

  @override
  Widget build(BuildContext context) {
    // The source PNG is 3368×1368; decoding it at full size for a 32–64 px
    // lockup wastes ~18 MB of image-cache RAM. Decode it at the display height
    // (× device pixel ratio) so it lands in the cache already downscaled.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = Image.asset(
      'assets/afdalLogo.png',
      height: height,
      cacheHeight: (height * dpr).ceil(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );

    if (dropShadow) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: child,
      );
    }

    return child;
  }
}
