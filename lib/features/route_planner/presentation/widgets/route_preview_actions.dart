import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../utils/auto_preview_controller.dart';

class AutoPreviewScope extends InheritedNotifier<AutoPreviewController> {
  const AutoPreviewScope({
    super.key,
    required AutoPreviewController controller,
    required super.child,
  }) : super(notifier: controller);

  static AutoPreviewController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AutoPreviewScope>()?.notifier;
}

/// Playback has its own surface; the external app is a separate text action.
class RoutePreviewActions extends StatelessWidget {
  final VoidCallback onPreview;
  final VoidCallback? onOpenGoogleMaps;

  const RoutePreviewActions({
    super.key,
    required this.onPreview,
    this.onOpenGoogleMaps,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AutoPreviewScope.maybeOf(context);
    final seconds = controller?.secondsRemaining;
    final counting = seconds != null;
    final radius = BorderRadius.circular(20);
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _PreviewEmblem(seconds: seconds),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  counting
                      ? AppStrings.routePreviewTitle
                      : AppStrings.playRoutePreview,
                  style: AppTextStyles.titleSm,
                ),
                const SizedBox(height: 5),
                Text(
                  counting
                      ? AppStrings.previewStartsIn(seconds)
                      : AppStrings.previewPlaybackHint,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (counting) ...[
            const SizedBox(width: 8),
            Semantics(
              label: AppStrings.cancelAutoPreview,
              child: TextButton(
                // A parent touch cancels before pointer-up. Replacing this
                // subtree must never turn that same tap into manual Play.
                key: const ValueKey('cancel-auto-preview'),
                onPressed: controller!.cancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.surface,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppStrings.cancel),
              ),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Color.alphaBlend(
            AppColors.primary.withValues(alpha: 0.07),
            AppColors.surface,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: counting
              ? content
              : Semantics(
                  button: true,
                  child: InkWell(
                    key: const ValueKey('play-route-preview'),
                    borderRadius: radius,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onPreview();
                    },
                    child: content,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: onOpenGoogleMaps,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: AppTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w500,
            ),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.map_1, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppStrings.openInGoogleMaps,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewEmblem extends StatelessWidget {
  final int? seconds;
  const _PreviewEmblem({this.seconds});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: const SizedBox.expand(),
          ),
          if (seconds != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(seconds: 5),
              builder: (_, progress, __) => SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  color: AppColors.primary,
                ),
              ),
            ),
          if (seconds != null)
            Text(
              '$seconds',
              style: AppTextStyles.titleLg.copyWith(color: AppColors.primary),
            )
          else
            Icon(Icons.play_arrow_rounded, size: 32, color: AppColors.primary),
        ],
      ),
    ),
  );
}
