import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/map_pack_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The live face of a map-pack download, shared by the trip corridor and
/// the area pack in Settings.
///
/// A bare progress bar was not enough. A pack is dozens of megabytes over
/// however much signal the driver has, and a bar with no number on it
/// gives no way to tell "slow" from "stuck" — which is the whole question
/// someone staring at a download is asking. So it answers three things at
/// once, in the order a driver reads them:
///
///   * **percent**, large, because it is the one glanceable number;
///   * **megabytes landed against the estimate**, because percent alone
///     hides whether this will cost 5 MB or 50;
///   * **which part of how many**, because between two boxes the megabyte
///     counter genuinely does stand still, and the part number is what
///     proves the download has not died.
///
/// Cancelling is part of the same story: it reports itself the instant it
/// is pressed rather than when the box in flight finally unwinds.
class MapPackProgressView extends StatelessWidget {
  final MapPackController pack;

  /// Estimate shown as the denominator. Passed in rather than read off the
  /// controller so the figure is the same one the driver was quoted on the
  /// button before they committed.
  final double estimatedMb;

  /// Thickness of the bar — the compact trip tile wants a thinner one than
  /// the Settings block.
  final double barHeight;

  const MapPackProgressView({
    super.key,
    required this.pack,
    required this.estimatedMb,
    this.barHeight = 5,
  });

  @override
  Widget build(BuildContext context) {
    final cancelling = pack.isCancelling;
    // Before the first box reports, there is genuinely nothing to show; an
    // indeterminate bar reads as "working", where 0% reads as "stuck".
    final started = pack.progress > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                cancelling
                    ? AppStrings.offlineMapCancelling
                    : started
                    ? AppStrings.offlineMapDownloading
                    : AppStrings.offlineMapPreparing,
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (started && !cancelling)
              Text(
                AppStrings.percent(pack.percent),
                style: AppTextStyles.titleMd.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w800,
                  // Locks the digits to one width so the number stops
                  // twitching sideways as it counts up.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            // Progress arrives in jumps as boxes land; animating between
            // them turns a lurching bar into a moving one.
            tween: Tween(begin: 0, end: pack.progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            builder: (context, value, _) => LinearProgressIndicator(
              value: started && !cancelling ? value : null,
              minHeight: barHeight,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                cancelling ? AppColors.textMuted : AppColors.info,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _detail(),
                style: AppTextStyles.mutedSm,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              // Pressed twice, the second press must not read as ignored —
              // the button greys out instead, while the line above says
              // what is happening. Repeating "stopping…" in both places
              // would just say it twice.
              onPressed: cancelling ? null : pack.cancel,
              child: Text(
                AppStrings.offlineMapCancel,
                style: TextStyle(
                  color: cancelling ? AppColors.textMuted : AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The line under the bar: size so far against the estimate, plus which
  /// part is in flight once there is more than one.
  String _detail() {
    final size = AppStrings.offlineMapDownloadedOf(pack.storedMb, estimatedMb);
    if (pack.boxCount <= 1) return size;
    final part = AppStrings.offlineMapPartOf(
      // The box in flight is the one after those finished, capped so the
      // last box never reads "13 of 12".
      (pack.doneBoxes + 1).clamp(1, pack.boxCount),
      pack.boxCount,
    );
    return '$size · $part';
  }
}
