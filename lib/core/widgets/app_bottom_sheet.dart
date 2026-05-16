import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Inner layout for our bottom sheets.
///
/// Intentionally does NOT paint a background or round its corners —
/// the parent `DraggableScrollableSheet` already provides a `Material`
/// surface for that. Double-wrapping caused the "empty void" glitch
/// the user saw when content was shorter than the dragged height.
///
/// Slots:
///   * Drag handle (always shown — tactile affordance that the sheet
///     is draggable).
///   * Optional title + subtitle row with trailing actions.
///   * The body (`child`).
class AppSheetContainer extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsets contentPadding;
  final bool showDragHandle;

  const AppSheetContainer({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
    this.contentPadding = const EdgeInsets.fromLTRB(20, 6, 20, 18),
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
        if (title != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title!, style: AppTextStyles.h3),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.muted,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
        ],
        Padding(
          padding: contentPadding,
          child: child,
        ),
      ],
    );
  }
}
