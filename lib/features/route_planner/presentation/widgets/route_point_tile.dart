import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/route_point.dart';

/// Compact card representation of a [RoutePoint] used inside
/// the bottom sheet list.
class RoutePointTile extends StatelessWidget {
  final RoutePoint point;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback? onRename;
  final VoidCallback? onSetAsDeparture;

  /// True for the last item in the post-optimization view, so we
  /// can render it as the "return" point in a special style.
  final bool isReturnPoint;

  const RoutePointTile({
    super.key,
    required this.point,
    required this.index,
    this.onRemove,
    this.onRename,
    this.onSetAsDeparture,
    this.isReturnPoint = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool depot = point.isDepot && !isReturnPoint;
    final color = depot
        ? AppColors.primary
        : isReturnPoint
            ? AppColors.accent
            : AppColors.info;

    final badge = depot
        ? Iconsax.flag
        : isReturnPoint
            ? Iconsax.home_2
            : Iconsax.location;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Leading(color: color, icon: badge, index: index + 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        point.label,
                        style: AppTextStyles.titleSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (depot) ...[
                      const SizedBox(width: 6),
                      _MiniBadge(label: 'انطلاق', color: AppColors.primary),
                    ] else if (isReturnPoint) ...[
                      const SizedBox(width: 6),
                      _MiniBadge(label: 'عودة', color: AppColors.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  point.address ??
                      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                  style: AppTextStyles.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onRename != null || onRemove != null || onSetAsDeparture != null)
            _OverflowMenu(
              canSetAsDeparture: !depot && onSetAsDeparture != null,
              onRename: onRename,
              onRemove: onRemove,
              onSetAsDeparture: onSetAsDeparture,
            ),
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int index;
  const _Leading({required this.color, required this.icon, required this.index});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 20),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySm.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final bool canSetAsDeparture;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;
  final VoidCallback? onSetAsDeparture;

  const _OverflowMenu({
    required this.canSetAsDeparture,
    this.onRename,
    this.onRemove,
    this.onSetAsDeparture,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Action>(
      icon: const Icon(Iconsax.more, color: AppColors.textMuted, size: 20),
      onSelected: (value) {
        switch (value) {
          case _Action.rename:
            onRename?.call();
            break;
          case _Action.remove:
            onRemove?.call();
            break;
          case _Action.setDeparture:
            onSetAsDeparture?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        if (onRename != null)
          const PopupMenuItem(
            value: _Action.rename,
            child: Row(
              children: [
                Icon(Iconsax.edit, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text(AppStrings.rename),
              ],
            ),
          ),
        if (canSetAsDeparture)
          const PopupMenuItem(
            value: _Action.setDeparture,
            child: Row(
              children: [
                Icon(Iconsax.flag, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text(AppStrings.setAsDeparture),
              ],
            ),
          ),
        if (onRemove != null)
          const PopupMenuItem(
            value: _Action.remove,
            child: Row(
              children: [
                Icon(Iconsax.trash, size: 18, color: AppColors.danger),
                SizedBox(width: 10),
                Text(AppStrings.remove,
                    style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
      ],
    );
  }
}

enum _Action { rename, remove, setDeparture }
