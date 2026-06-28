import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';

/// Opens the per-point actions sheet: full label + address, then rename,
/// move on map, mark optional / active, and remove.
///
/// Shared by the map (tapping a marker) and the planning sheet (tapping a
/// point in the grid) so a point behaves identically wherever it's touched.
Future<void> showPointActions(BuildContext context, RoutePoint point) {
  final cubit = context.read<RoutePlannerCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _PointActionsSheet(
      point: point,
      onRename: () async {
        Navigator.pop(sheetCtx);
        final newLabel = await AppDialog.input(
          context: context,
          title: AppStrings.rename,
          hint: AppStrings.rename,
          initialValue: point.label,
          icon: Iconsax.edit,
          tone: AppDialogTone.primary,
        );
        if (newLabel != null && newLabel.trim().isNotEmpty) {
          cubit.renamePoint(point.id, newLabel.trim());
        }
      },
      onMove: () {
        Navigator.pop(sheetCtx);
        cubit.beginMovePoint(point.id);
      },
      // One toggle: the stop is either in the route or skipped.
      onToggleInclude: point.isDepot
          ? null
          : () {
              Navigator.pop(sheetCtx);
              if (point.isRoutable) {
                // Currently in the route → skip it (dimmed, left out).
                cubit.setPointIncluded(point.id, false);
              } else if (cubit.state.hasOptimizedRoute) {
                // Re-including on an existing route changes it → confirm.
                showActivateStopDialog(context, point);
              } else {
                cubit.setPointIncluded(point.id, true);
              }
            },
      onRemove: () {
        Navigator.pop(sheetCtx);
        confirmRemovePoint(context, point.id);
      },
    ),
  );
}

/// Confirmation dialog before deleting a point. Public so both the map's
/// long-press-to-delete and the actions sheet can share it.
Future<void> confirmRemovePoint(BuildContext context, String pointId) {
  final cubit = context.read<RoutePlannerCubit>();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.trash, color: AppColors.danger, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.removePointTitle,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppStrings.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    cubit.removePoint(pointId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppStrings.remove),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Shown when the user re-includes an excluded optional point on an already
/// optimized route. Offers to re-optimize (fold it in), delete the point, or
/// cancel (leave it excluded). Public so the map marker and the planning grid
/// share the exact same flow.
Future<void> showActivateStopDialog(BuildContext context, RoutePoint point) async {
  final cubit = context.read<RoutePlannerCubit>();
  final choice = await AppDialog.show<String>(
    context: context,
    title: AppStrings.activateStopTitle,
    message: AppStrings.activateStopMsg,
    icon: Iconsax.star_1,
    actions: [
      AppDialogAction.cancel(),
      AppDialogAction(
        label: AppStrings.remove,
        icon: Iconsax.trash,
        destructive: true,
        popWith: 'delete',
      ),
      AppDialogAction(
        label: AppStrings.reoptimizeNow,
        icon: Iconsax.routing,
        primary: true,
        popWith: 'reoptimize',
      ),
    ],
  );
  if (!context.mounted) return;
  if (choice == 'reoptimize') {
    await cubit.activateAndReoptimize(point.id);
  } else if (choice == 'delete') {
    cubit.removePoint(point.id);
  }
}

class _PointActionsSheet extends StatelessWidget {
  final RoutePoint point;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback? onToggleInclude;
  final VoidCallback onRemove;

  const _PointActionsSheet({
    required this.point,
    required this.onRename,
    required this.onMove,
    required this.onToggleInclude,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final skipped = point.isDeactivated;
    final accent = point.isDepot
        ? AppColors.primary
        : skipped
        ? AppColors.optionalOff
        : AppColors.accent;
    // Always show a location line: the geocoded address when we have it,
    // otherwise the raw coordinates — so tapping a point always reveals
    // "where" it is, in full.
    final location = point.address?.isNotEmpty == true
        ? point.address!
        : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      point.isDepot
                          ? Iconsax.flag
                          : skipped
                          ? Iconsax.eye_slash
                          : Iconsax.location,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.label,
                          style: AppTextStyles.titleMd,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          location,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            _ActionRow(
              icon: Iconsax.edit,
              label: AppStrings.rename,
              color: AppColors.primary,
              onTap: onRename,
            ),
            _ActionRow(
              icon: Iconsax.gps,
              label: AppStrings.moveOnMap,
              color: AppColors.info,
              onTap: onMove,
            ),
            // Single include/skip toggle (hidden for the depot, which is
            // always part of the route).
            if (onToggleInclude != null)
              _ActionRow(
                icon: skipped ? Iconsax.tick_circle : Iconsax.eye_slash,
                label: skipped ? AppStrings.includeStop : AppStrings.skipStop,
                color: skipped ? AppColors.primary : AppColors.optionalOff,
                onTap: onToggleInclude!,
              ),
            _ActionRow(
              icon: Iconsax.trash,
              label: AppStrings.remove,
              color: AppColors.danger,
              destructive: true,
              onTap: onRemove,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.bodyLg.copyWith(
                color: destructive ? AppColors.danger : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
