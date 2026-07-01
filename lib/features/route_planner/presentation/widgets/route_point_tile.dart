import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/route_point.dart';

/// Compact card representation of a [RoutePoint] used inside
/// the bottom sheet list.
///
/// Ordering is owned by the optimizer, so there is no drag handle and
/// no "set as departure" — points are managed through the overflow menu
/// (rename, move on map, mark optional, activate/deactivate, delete).
class RoutePointTile extends StatelessWidget {
  final RoutePoint point;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback? onRename;

  /// Toggle this point between mandatory and optional (#8).
  final VoidCallback? onToggleOptional;

  /// Activate / deactivate an optional point (#8).
  final VoidCallback? onToggleActive;

  /// Enter "move on map" mode for this point (#9).
  final VoidCallback? onMoveOnMap;

  /// True for the last item in the post-optimization view, so we
  /// can render it as the "return" point in a special style.
  final bool isReturnPoint;

  const RoutePointTile({
    super.key,
    required this.point,
    required this.index,
    this.onRemove,
    this.onRename,
    this.onToggleOptional,
    this.onToggleActive,
    this.onMoveOnMap,
    this.isReturnPoint = false,
  });

  bool get _hasMenu =>
      onRename != null ||
      onRemove != null ||
      onToggleOptional != null ||
      onToggleActive != null ||
      onMoveOnMap != null;

  @override
  Widget build(BuildContext context) {
    final bool depot = point.isDepot && !isReturnPoint;
    final bool dimmed = point.isDeactivated;

    final color = depot
        ? AppColors.primary
        : isReturnPoint
        ? AppColors.accent
        : point.optional
        ? AppColors.optional
        : AppColors.info;

    final badge = depot
        ? Iconsax.flag
        : isReturnPoint
        ? Iconsax.home_2
        : point.optional
        ? Iconsax.star_1
        : Iconsax.location;

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: point.optional && !dimmed
              ? AppColors.optional.withValues(alpha: 0.35)
              : AppColors.white.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          _Leading(
            color: dimmed ? AppColors.optionalOff : color,
            icon: badge,
            index: index + 1,
          ),
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
                      _MiniBadge(
                        label: AppStrings.departureBadge,
                        color: AppColors.primary,
                      ),
                    ] else if (isReturnPoint) ...[
                      const SizedBox(width: 6),
                      _MiniBadge(
                        label: AppStrings.returnBadge,
                        color: AppColors.accent,
                      ),
                    ] else if (point.optional) ...[
                      const SizedBox(width: 6),
                      _MiniBadge(
                        label: dimmed
                            ? AppStrings.deactivatedBadge
                            : AppStrings.optionalBadge,
                        color: dimmed ? AppColors.optionalOff : AppColors.optional,
                      ),
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
          if (_hasMenu)
            _OverflowMenu(
              point: point,
              onRename: onRename,
              onRemove: onRemove,
              onToggleOptional: onToggleOptional,
              onToggleActive: onToggleActive,
              onMoveOnMap: onMoveOnMap,
            ),
        ],
      ),
    );

    // Deactivated optional points read as "parked": faded but still
    // present and re-activatable.
    return Opacity(opacity: dimmed ? 0.55 : 1.0, child: tile);
  }
}

class _Leading extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int index;
  const _Leading({
    required this.color,
    required this.icon,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
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
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.white,
                fontSize: 10,
              ),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySm.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final RoutePoint point;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleOptional;
  final VoidCallback? onToggleActive;
  final VoidCallback? onMoveOnMap;

  const _OverflowMenu({
    required this.point,
    this.onRename,
    this.onRemove,
    this.onToggleOptional,
    this.onToggleActive,
    this.onMoveOnMap,
  });

  @override
  Widget build(BuildContext context) {
    // The depot can't be made optional / deactivated.
    final canToggleOptional = !point.isDepot && onToggleOptional != null;
    final canToggleActive =
        !point.isDepot && point.optional && onToggleActive != null;

    return PopupMenuButton<_Action>(
      icon: Icon(Iconsax.more, color: AppColors.textMuted, size: 20),
      onSelected: (value) {
        switch (value) {
          case _Action.rename:
            onRename?.call();
          case _Action.move:
            onMoveOnMap?.call();
          case _Action.optional:
            onToggleOptional?.call();
          case _Action.active:
            onToggleActive?.call();
          case _Action.remove:
            onRemove?.call();
        }
      },
      itemBuilder: (_) => [
        if (onRename != null)
          _menuItem(
            _Action.rename,
            Iconsax.edit,
            AppStrings.rename,
            AppColors.textSecondary,
          ),
        if (onMoveOnMap != null)
          _menuItem(
            _Action.move,
            Iconsax.gps,
            AppStrings.moveOnMap,
            AppColors.info,
          ),
        if (canToggleOptional)
          _menuItem(
            _Action.optional,
            point.optional ? Iconsax.tick_square : Iconsax.star_1,
            point.optional ? AppStrings.markRequired : AppStrings.markOptional,
            AppColors.optional,
          ),
        if (canToggleActive)
          _menuItem(
            _Action.active,
            point.active ? Iconsax.pause_circle : Iconsax.play_circle,
            point.active ? AppStrings.deactivate : AppStrings.activate,
            point.active ? AppColors.optionalOff : AppColors.primary,
          ),
        if (onRemove != null)
          _menuItem(
            _Action.remove,
            Iconsax.trash,
            AppStrings.remove,
            AppColors.danger,
          ),
      ],
    );
  }

  PopupMenuItem<_Action> _menuItem(
    _Action value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: value == _Action.remove
                ? TextStyle(color: AppColors.danger)
                : null,
          ),
        ],
      ),
    );
  }
}

enum _Action { rename, move, optional, active, remove }
