import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/route_point.dart';
import '../pages/route_planner_actions.dart';
import '../cubit/route_planner_cubit.dart';
import 'stop_time_window_sheet.dart';

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
    // The row list grew (contact actions on top of the existing five), and a
    // stop with a phone now runs past the default 9/16-of-screen cap. Let the
    // sheet size to its content and scroll when even that isn't enough.
    isScrollControlled: true,
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
      onEditPhone: () async {
        Navigator.pop(sheetCtx);
        final entered = await AppDialog.input(
          context: context,
          title: point.hasPhone
              ? AppStrings.stopPhoneEdit
              : AppStrings.stopPhoneAdd,
          hint: AppStrings.stopPhoneHint,
          initialValue: point.phone ?? '',
          icon: Iconsax.call,
          tone: AppDialogTone.primary,
          keyboardType: TextInputType.phone,
        );
        // Null is "cancelled" and leaves the number alone; an emptied field
        // is a deliberate "remove it", which setPointPhone treats as a clear.
        if (entered == null) return;
        cubit.setPointPhone(point.id, entered);
      },
      onWhatsapp: point.hasPhone
          ? () {
              Navigator.pop(sheetCtx);
              RoutePlannerActions.messageStopOnWhatsapp(context, point.phone!);
            }
          : null,
      onCall: point.hasPhone
          ? () {
              Navigator.pop(sheetCtx);
              RoutePlannerActions.callStop(context, point.phone!);
            }
          : null,
      onMove: () {
        Navigator.pop(sheetCtx);
        cubit.beginMovePoint(point.id);
      },
      // The depot is where the trip starts, so it has no arrival time —
      // its clock is the departure control in the planning sheet instead.
      onSetTime: point.isDepot
          ? null
          : () async {
              Navigator.pop(sheetCtx);
              final choice = await showStopTimeWindowSheet(
                context,
                pointLabel: point.label,
                initial: point.timeWindow,
              );
              if (choice == null) return;
              if (choice.isCleared) {
                cubit.clearPointTimeWindow(point.id);
              } else {
                cubit.setPointTimeWindow(point.id, choice.window!);
              }
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
Future<void> confirmRemovePoint(BuildContext context, String pointId) async {
  final cubit = context.read<RoutePlannerCubit>();
  final confirmed = await AppDialog.confirm(
    context: context,
    title: AppStrings.removePointTitle,
    message: AppStrings.removePointBody,
    icon: Iconsax.trash,
    tone: AppDialogTone.danger,
    confirmLabel: AppStrings.remove,
    confirmIcon: Iconsax.trash,
    destructive: true,
  );
  if (confirmed != true) return;
  cubit.removePoint(pointId);
}

/// Shown when the user re-includes an excluded optional point on an already
/// optimized route. Offers to re-optimize (fold it in), delete the point, or
/// cancel (leave it excluded). Public so the map marker and the planning grid
/// share the exact same flow.
Future<void> showActivateStopDialog(
  BuildContext context,
  RoutePoint point,
) async {
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
  final VoidCallback onEditPhone;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onCall;
  final VoidCallback onMove;
  final VoidCallback? onToggleInclude;
  final VoidCallback? onSetTime;
  final VoidCallback onRemove;

  const _PointActionsSheet({
    required this.point,
    required this.onRename,
    required this.onEditPhone,
    required this.onWhatsapp,
    required this.onCall,
    required this.onMove,
    required this.onToggleInclude,
    required this.onSetTime,
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
        child: SingleChildScrollView(
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
                        // House for the departure, matching its map marker.
                        point.isDepot
                            ? Iconsax.home_2
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
                          if (point.hasPhone) ...[
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Iconsax.call,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                // LTR so a leading + and the digit groups read
                                // correctly inside an otherwise RTL sheet.
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    point.phone!,
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.divider),
              // Contact first: at a stop, reaching whoever is waiting beats
              // every other action on this sheet. Absent without a number.
              if (onWhatsapp != null)
                _ActionRow(
                  icon: Iconsax.message,
                  label: AppStrings.stopWhatsapp,
                  color: AppColors.primary,
                  onTap: onWhatsapp!,
                ),
              if (onCall != null)
                _ActionRow(
                  icon: Iconsax.call,
                  label: AppStrings.stopCall,
                  color: AppColors.info,
                  onTap: onCall!,
                ),
              _ActionRow(
                icon: Iconsax.edit,
                label: AppStrings.rename,
                color: AppColors.primary,
                onTap: onRename,
              ),
              _ActionRow(
                icon: Iconsax.call_add,
                label: point.hasPhone
                    ? AppStrings.stopPhoneEdit
                    : AppStrings.stopPhoneAdd,
                color: AppColors.accent,
                onTap: onEditPhone,
              ),
              _ActionRow(
                icon: Iconsax.gps,
                label: AppStrings.moveOnMap,
                color: AppColors.info,
                onTap: onMove,
              ),
              // Arrival time — the trailing value doubles as the current
              // state, so the row reads as "Arrival time · 14:00 – 15:30"
              // or "Arrival time · Any time".
              if (onSetTime != null)
                _ActionRow(
                  icon: Iconsax.clock,
                  label: AppStrings.arrivalTime,
                  color: point.hasTimeWindow
                      ? AppColors.primary
                      : AppColors.textMuted,
                  trailing: point.hasTimeWindow
                      ? AppStrings.arrivalWindowRange(
                          formatMinuteOfDay(
                            context,
                            point.timeWindow!.startMinuteOfDay,
                          ),
                          formatMinuteOfDay(
                            context,
                            point.timeWindow!.endMinuteOfDay,
                          ),
                        )
                      : AppStrings.anyTime,
                  onTap: onSetTime!,
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
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool destructive;

  /// Optional current value shown at the end of the row, so a setting-style
  /// action reads as "label · value" without a second line.
  final String? trailing;

  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.destructive = false,
    this.trailing,
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
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLg.copyWith(
                  color: destructive ? AppColors.danger : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AppTextStyles.bodySm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
