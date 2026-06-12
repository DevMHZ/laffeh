import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'optimize_route_button.dart';
import 'route_point_tile.dart';

class RoutePointsSheet extends StatelessWidget {
  final VoidCallback? onPasteAddresses;
  final VoidCallback? onImportCsv;
  final VoidCallback? onExportCsv;
  final VoidCallback? onAddPoint;

  const RoutePointsSheet({
    super.key,
    this.onPasteAddresses,
    this.onImportCsv,
    this.onExportCsv,
    this.onAddPoint,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.status != b.status ||
          a.errorMessage != b.errorMessage,
      builder: (context, state) {
        final cubit = context.read<RoutePlannerCubit>();

        return AppSheetContainer(
          title: AppStrings.routePointsTitle,
          subtitle: state.hasPoints
              ? '${AppStrings.pointsCount(state.points.length)} • ${AppStrings.dragToReorder}'
              : AppStrings.panToAddPoint,
          actions: [
            _AddPointChip(onAddPoint: onAddPoint),
            if (state.hasPoints)
              IconButton(
                tooltip: AppStrings.clearAll,
                onPressed: () => _confirmClearAll(context, cubit),
                icon: const Icon(
                  Iconsax.trash,
                  color: AppColors.danger,
                  size: 22,
                ),
              ),
          ],
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.errorMessage != null &&
                  state.status != RoutePlannerStatus.optimizedFailure) ...[
                _MessageBanner(
                  icon: Iconsax.info_circle,
                  color: AppColors.warning,
                  message: state.errorMessage!,
                ),
                const SizedBox(height: 10),
              ],
              if (!state.hasPoints) ...[
                const SizedBox(height: 4),
                _EmptyState(
                  onAddPoint: onAddPoint,
                  onPasteAddresses: onPasteAddresses,
                  onImportCsv: onImportCsv,
                  onExportCsv: onExportCsv,
                ),
              ] else ...[
                const SizedBox(height: 6),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: state.points.length,
                  onReorder: cubit.reorderPoint,
                  proxyDecorator: (child, _, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (_, child) {
                        final t = Curves.easeOutCubic.transform(
                          animation.value,
                        );
                        return Transform.scale(
                          scale: 1 + (0.025 * t),
                          child: Material(
                            color: Colors.transparent,
                            elevation: 10 * t,
                            shadowColor: AppColors.shadow,
                            borderRadius: BorderRadius.circular(18),
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final p = state.points[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(p.id),
                      index: index,
                      child: RoutePointTile(
                        point: p,
                        index: index,
                        onRename: () => _renamePrompt(context, p),
                        onRemove: () => cubit.removePoint(p.id),
                        onSetAsDeparture: () => cubit.setAsDeparture(p.id),
                      ),
                    );
                  },
                ),
              ],
              if (state.errorMessage != null &&
                  state.status == RoutePlannerStatus.optimizedFailure) ...[
                const SizedBox(height: 4),
                _MessageBanner(
                  icon: Iconsax.info_circle,
                  color: AppColors.danger,
                  message: state.errorMessage!,
                ),
              ],
              const SizedBox(height: 14),
              _ReadinessBanner(pointsCount: state.points.length),
              const SizedBox(height: 10),
              OptimizeRouteButton(
                onPressed: cubit.optimize,
                enabled: state.canOptimize,
                loading: state.isOptimizing,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renamePrompt(BuildContext context, RoutePoint p) async {
    final cubit = context.read<RoutePlannerCubit>();
    final newLabel = await AppDialog.input(
      context: context,
      title: AppStrings.rename,
      hint: AppStrings.rename,
      initialValue: p.label,
      icon: Iconsax.edit,
      tone: AppDialogTone.primary,
    );
    if (newLabel != null && newLabel.isNotEmpty) {
      cubit.renamePoint(p.id, newLabel);
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    RoutePlannerCubit cubit,
  ) async {
    final ok = await AppDialog.confirm(
      context: context,
      title: AppStrings.clearAll,
      message: AppStrings.clearRouteConfirm,
      confirmLabel: AppStrings.clearAll,
      confirmIcon: Iconsax.trash,
      icon: Iconsax.warning_2,
      tone: AppDialogTone.danger,
      destructive: true,
    );
    if (ok == true) cubit.clearAll();
  }
}

class _AddPointChip extends StatelessWidget {
  final VoidCallback? onAddPoint;

  const _AddPointChip({required this.onAddPoint});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onAddPoint != null ? AppColors.accent : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          onAddPoint?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.add,
                size: 18,
                color: onAddPoint != null ? AppColors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                AppStrings.addPointHere,
                style: AppTextStyles.white14w600.copyWith(
                  color: onAddPoint != null ? AppColors.white : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  final int pointsCount;

  const _ReadinessBanner({required this.pointsCount});

  @override
  Widget build(BuildContext context) {
    final ready = pointsCount >= 2;
    final color = ready
        ? AppColors.success
        : pointsCount == 0
        ? AppColors.primary
        : AppColors.warning;
    final message = ready
        ? AppStrings.readyToOptimize
        : pointsCount == 0
        ? AppStrings.setDepartureFirst
        : AppStrings.addOneStopToOptimize;
    final icon = ready
        ? Iconsax.tick_circle
        : pointsCount == 0
        ? Iconsax.flag
        : Iconsax.location_add;

    return _MessageBanner(icon: icon, color: color, message: message);
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _MessageBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onAddPoint;
  final VoidCallback? onPasteAddresses;
  final VoidCallback? onImportCsv;
  final VoidCallback? onExportCsv;

  const _EmptyState({
    this.onAddPoint,
    this.onPasteAddresses,
    this.onImportCsv,
    this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Iconsax.location_add,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(AppStrings.startCreatingRoute, style: AppTextStyles.titleLg),
          const SizedBox(height: 2),
          Text(
            AppStrings.noPointsYet,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAddPoint?.call();
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.add_circle, color: AppColors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.addPointHere,
                        style: AppTextStyles.button,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _HintRow(
            icon: Iconsax.flag,
            color: AppColors.primary,
            label: AppStrings.addDepartureHint,
          ),
          const SizedBox(height: 4),
          _HintRow(
            icon: Iconsax.location_tick,
            color: AppColors.accent,
            label: AppStrings.addStopsHint,
          ),
          const SizedBox(height: 4),
          _HintRow(
            icon: Iconsax.routing_2,
            color: AppColors.info,
            label: AppStrings.optimizeHint,
          ),
          if (_showQuickActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: AppStrings.importCsv,
                    icon: Iconsax.document_download,
                    height: 44,
                    radius: 12,
                    variant: AppButtonVariant.ghost,
                    onPressed: onImportCsv,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: AppStrings.exportCsv,
                    icon: Iconsax.document_upload,
                    height: 44,
                    radius: 12,
                    variant: AppButtonVariant.ghost,
                    onPressed: onExportCsv,
                  ),
                ),
              ],
            ),
            if (onPasteAddresses != null) ...[
              const SizedBox(height: 6),
              AppButton(
                label: AppStrings.pasteListAction,
                icon: Iconsax.document_copy,
                height: 44,
                radius: 12,
                variant: AppButtonVariant.secondary,
                onPressed: onPasteAddresses,
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool get _showQuickActions =>
      onPasteAddresses != null || onImportCsv != null || onExportCsv != null;
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _HintRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
