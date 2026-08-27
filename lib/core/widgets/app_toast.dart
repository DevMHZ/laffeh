import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// What a toast is reporting, which is all a caller has to decide.
enum ToastTone { success, info, failure }

/// A brief message, delivered at the **top** of the screen.
///
/// Material's SnackBar lands at the bottom, and the bottom of this app is
/// where the work happens: the planning sheet, the navigator card, "optimize
/// route". A confirmation that covers the button the driver is reaching for
/// is worse than no confirmation — they cannot read it (their thumb is on it)
/// and cannot act around it. So messages come down from the top, over the map
/// where nothing is ever tapped, and leave on their own.
///
/// Deliberately not interactive: anything that needs a decision is a dialog
/// or a sheet, not a message that disappears.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  /// Shows [message] at the top of the screen, replacing any toast still up.
  static void show(
    BuildContext context,
    String message, {
    ToastTone tone = ToastTone.success,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _dismiss();
    final controller = _ToastController();
    final entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        tone: tone,
        controller: controller,
        // The overlay sits above every Directionality in the app's tree, so
        // the toast has to be told which way its own text runs.
        direction: Directionality.of(context),
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _feel(tone);

    _timer = Timer(duration, () async {
      await controller.hide();
      _dismiss();
    });
  }

  /// What the message feels like in the hand.
  ///
  /// A stop landing on the route is the small good moment of using this app,
  /// and it happens while the driver is looking at the map rather than at
  /// the words — so it is worth feeling. Two taps a breath apart read as a
  /// soft confirming "tick" where a single buzz reads as a notification;
  /// the system click rides along with it and stays quiet on a phone that is
  /// on silent, which in a cab it usually is.
  static void _feel(ToastTone tone) {
    switch (tone) {
      case ToastTone.success:
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);
        Future<void>.delayed(
          const Duration(milliseconds: 80),
          HapticFeedback.lightImpact,
        );
      case ToastTone.info:
        HapticFeedback.selectionClick();
      case ToastTone.failure:
        HapticFeedback.mediumImpact();
    }
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _current;
    _current = null;
    // The overlay it lived in can be gone already — a route popped while the
    // toast was still up — and removing a detached entry throws.
    if (entry != null && entry.mounted) entry.remove();
  }
}

/// Lets the timer ask the mounted toast to play its exit before removal.
class _ToastController {
  Future<void> Function()? _hide;

  Future<void> hide() async => _hide?.call();
}

class _ToastView extends StatefulWidget {
  final String message;
  final ToastTone tone;
  final _ToastController controller;
  final TextDirection direction;

  const _ToastView({
    required this.message,
    required this.tone,
    required this.controller,
    required this.direction,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    widget.controller._hide = () async {
      if (!mounted) return;
      await _anim.reverse();
    };
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  (Color, IconData) get _look => switch (widget.tone) {
    ToastTone.success => (AppColors.primary, Iconsax.tick_circle),
    ToastTone.info => (AppColors.info, Iconsax.info_circle),
    ToastTone.failure => (AppColors.danger, Iconsax.close_circle),
  };

  @override
  Widget build(BuildContext context) {
    final (accent, icon) = _look;
    final curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    // Positioned has to be the outermost widget here: it is parent data for
    // the overlay's own Stack, and anything wrapped around it is laid out as
    // an ordinary full-size child instead.
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 14,
      right: 14,
      child: Directionality(
        textDirection: widget.direction,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: curve,
            builder: (context, child) => Opacity(
              opacity: _anim.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -26 * (1 - curve.value)),
                child: child,
              ),
            ),
            // The root overlay is outside every Material in the app, and a
            // Text with no Material above it inherits Flutter's debug style —
            // yellow underline and all. This is the ancestor it needs.
            child: Material(
              type: MaterialType.transparency,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 11, 18, 11),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 22,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 16, color: accent),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleSm.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
