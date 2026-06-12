import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Visual tone for a [AppDialog] header icon. Picks the bubble +
/// icon color for you so call sites don't have to.
enum AppDialogTone { primary, success, warning, danger, info }

extension on AppDialogTone {
  Color get accent {
    switch (this) {
      case AppDialogTone.primary:
        return AppColors.primary;
      case AppDialogTone.success:
        return AppColors.success;
      case AppDialogTone.warning:
        return AppColors.warning;
      case AppDialogTone.danger:
        return AppColors.danger;
      case AppDialogTone.info:
        return AppColors.info;
    }
  }
}

/// One [AppDialog] action. Place primary action LAST in the list —
/// it gets filled / coloured; the others are quiet text buttons.
class AppDialogAction {
  final String label;
  final IconData? icon;
  final bool primary;
  final bool destructive;
  final VoidCallback? onPressed;

  /// Optional value to pop with when the action is tapped. If null,
  /// the dialog just calls [onPressed] and stays open (the callback
  /// is responsible for popping).
  final Object? popWith;

  const AppDialogAction({
    required this.label,
    this.icon,
    this.primary = false,
    this.destructive = false,
    this.onPressed,
    this.popWith,
  });

  /// Cancel button — convention is a quiet text button on the right
  /// (RTL leading) that pops with `null`.
  factory AppDialogAction.cancel({String? label}) =>
      AppDialogAction(label: label ?? AppStrings.cancel, popWith: null);
}

/// Unified, brand-styled dialog used everywhere in the app.
///
/// One widget, three usage patterns:
///
///   * `AppDialog.confirm(...)`  → message + 2 buttons.
///   * `AppDialog.input(...)`    → header + text field + 2 buttons.
///   * `AppDialog.show(...)`     → full power: custom content, N actions.
class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final AppDialogTone tone;
  final Widget? content;
  final List<AppDialogAction> actions;

  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.icon,
    this.tone = AppDialogTone.primary,
    this.content,
  });

  // ── Helpers ────────────────────────────────────────────

  /// Generic show — return value matches the chosen action's
  /// `popWith` (or null on cancel / barrier dismiss).
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    IconData? icon,
    AppDialogTone tone = AppDialogTone.primary,
    Widget? content,
    required List<AppDialogAction> actions,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return Opacity(
          opacity: curved.value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * curved.value),
            child: child,
          ),
        );
      },
      pageBuilder: (_, __, ___) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppDialog(
            title: title,
            message: message,
            icon: icon,
            tone: tone,
            content: content,
            actions: actions,
          ),
        ),
      ),
    );
  }

  /// Yes/no style confirmation. Pops `true` on confirm, `null` on cancel.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    IconData? confirmIcon,
    IconData? icon,
    AppDialogTone tone = AppDialogTone.primary,
    bool destructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      icon: icon,
      tone: tone,
      actions: [
        AppDialogAction.cancel(label: cancelLabel),
        AppDialogAction(
          label: confirmLabel ?? AppStrings.save,
          icon: confirmIcon,
          primary: true,
          destructive: destructive,
          popWith: true,
        ),
      ],
    );
  }

  /// Text-input dialog. Pops the trimmed text on confirm, `null` on cancel.
  static Future<String?> input({
    required BuildContext context,
    required String title,
    String? message,
    String? hint,
    String initialValue = '',
    String? confirmLabel,
    String? cancelLabel,
    IconData? confirmIcon = Iconsax.save_2,
    IconData? icon,
    AppDialogTone tone = AppDialogTone.primary,
  }) {
    final controller = TextEditingController(text: initialValue);
    return show<String>(
      context: context,
      title: title,
      icon: icon,
      tone: tone,
      message: message,
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        style: AppTextStyles.bodyLg,
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        AppDialogAction.cancel(label: cancelLabel),
        AppDialogAction(
          label: confirmLabel ?? AppStrings.save,
          icon: confirmIcon,
          primary: true,
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 36,
                offset: Offset(0, 18),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tone.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: tone.accent, size: 28),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(title, textAlign: TextAlign.center, style: AppTextStyles.h3),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
              if (content != null) ...[const SizedBox(height: 16), content!],
              const SizedBox(height: 20),
              _Actions(actions: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final List<AppDialogAction> actions;
  const _Actions({required this.actions});

  @override
  Widget build(BuildContext context) {
    // 1 button → full-width primary.
    // 2 buttons → quiet on the start side, primary on the end (RTL: primary on left).
    // 3 buttons → stack: top is primary, two secondary share a row underneath.
    if (actions.length == 1) {
      return _ButtonWidget(action: actions.first, fullWidth: true);
    }

    if (actions.length == 2) {
      return Row(
        children: [
          Expanded(child: _ButtonWidget(action: actions[0])),
          const SizedBox(width: 10),
          Expanded(child: _ButtonWidget(action: actions[1])),
        ],
      );
    }

    // 3+ → primary on top, rest below in a row.
    final primary = actions.firstWhere(
      (a) => a.primary,
      orElse: () => actions.last,
    );
    final rest = actions.where((a) => a != primary).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ButtonWidget(action: primary, fullWidth: true),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < rest.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _ButtonWidget(action: rest[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _ButtonWidget extends StatelessWidget {
  final AppDialogAction action;
  final bool fullWidth;
  const _ButtonWidget({required this.action, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    final isPrimary = action.primary;
    final destructive = action.destructive;

    final Color bg;
    final Color fg;
    final Color borderColor;
    if (isPrimary) {
      bg = destructive ? AppColors.danger : AppColors.primary;
      fg = AppColors.white;
      borderColor = Colors.transparent;
    } else {
      bg = AppColors.surfaceAlt;
      fg = destructive ? AppColors.danger : AppColors.textPrimary;
      borderColor = AppColors.border;
    }

    void onTap() {
      HapticFeedback.selectionClick();
      if (action.onPressed != null) {
        action.onPressed!();
      } else {
        Navigator.of(context).pop(action.popWith);
      }
    }

    final child = Container(
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleMd.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: fullWidth
            ? SizedBox(width: double.infinity, child: child)
            : child,
      ),
    );
  }
}
