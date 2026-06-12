import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../saved_routes/presentation/pages/saved_routes_page.dart';
import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'route_metrics_card.dart';
import 'route_point_tile.dart';

class RouteSummarySheet extends StatelessWidget {
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback? onExportCsv;

  const RouteSummarySheet({super.key, this.onOpenGoogleMaps, this.onExportCsv});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.optimizedRoute != b.optimizedRoute ||
          a.displaySegment != b.displaySegment,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();

        final order = route.orderedPoints;

        return AppSheetContainer(
          title: AppStrings.bestRouteTitle,
          subtitle: AppStrings.routeReadyHint,
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetricsGrid(route: route),
              const SizedBox(height: 14),
              _RouteSegmentSelector(
                current: state.displaySegment,
                onChanged: cubit.showSegment,
              ),
              const SizedBox(height: 16),
              _StartNavigationButton(onPressed: cubit.startNavigation),
              const SizedBox(height: 10),
              AppButton(
                label: AppStrings.startSimulation,
                icon: Iconsax.play_circle,
                variant: AppButtonVariant.secondary,
                height: 54,
                radius: 16,
                onPressed: cubit.startSimulation,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: AppStrings.openInGoogleMaps,
                icon: Iconsax.map_1,
                variant: AppButtonVariant.outlined,
                height: 54,
                radius: 16,
                onPressed: onOpenGoogleMaps,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: AppStrings.saveRouteAction,
                      icon: Iconsax.save_2,
                      variant: AppButtonVariant.secondary,
                      height: 50,
                      radius: 14,
                      onPressed: () => _saveRoute(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: AppStrings.exportCsv,
                      icon: Iconsax.document_upload,
                      variant: AppButtonVariant.ghost,
                      height: 50,
                      radius: 14,
                      onPressed: onExportCsv,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppButton(
                label: AppStrings.startNewRoute,
                icon: Iconsax.refresh,
                variant: AppButtonVariant.outlined,
                height: 50,
                radius: 14,
                onPressed: () => _handleStartNew(context),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.routeOrder,
                      style: AppTextStyles.titleMd,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppStrings.pointsCount(order.length),
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...order.asMap().entries.map((e) {
                final isReturn = e.key == order.length - 1 && e.value.isDepot;
                return RoutePointTile(
                  point: e.value,
                  index: e.key,
                  isReturnPoint: isReturn,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleStartNew(BuildContext context) async {
    final cubit = context.read<RoutePlannerCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showSaveBeforeClearDialog(context);
    if (choice == null) return; // user cancelled
    if (!context.mounted) return;

    if (choice == SaveBeforeClearChoice.save) {
      final defaultName =
          '${AppStrings.defaultRouteName} • ${_shortDate(DateTime.now())}';
      final name = await showSaveRouteDialog(context, initialName: defaultName);
      if (name == null) return; // user cancelled save → keep current route
      if (!context.mounted) return;

      try {
        final saved = await cubit.saveCurrentRouteToHistory(name);
        if (saved == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(AppStrings.errSaveRoute)),
          );
          return; // don't clear — let the user retry
        }
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.routeSavedMsg)),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.routeSaveFailed(e))),
        );
        return; // don't clear on failure
      }
    }

    cubit.clearAll();
  }

  Future<void> _saveRoute(BuildContext context) async {
    final cubit = context.read<RoutePlannerCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final defaultName =
        '${AppStrings.defaultRouteName} • ${_shortDate(DateTime.now())}';

    final name = await showSaveRouteDialog(context, initialName: defaultName);
    if (name == null) return;
    if (!context.mounted) return;

    try {
      final saved = await cubit.saveCurrentRouteToHistory(name);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved == null ? AppStrings.errSaveRoute : AppStrings.routeSavedMsg,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.routeSaveFailed(e))),
      );
    }
  }

  String _shortDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _RouteSegmentSelector extends StatelessWidget {
  final RouteSegment current;
  final ValueChanged<RouteSegment> onChanged;

  const _RouteSegmentSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        segment: RouteSegment.full,
        label: AppStrings.showFull,
        icon: Iconsax.routing_2,
        color: AppColors.primary,
      ),
      (
        segment: RouteSegment.go,
        label: AppStrings.showGo,
        icon: Iconsax.routing,
        color: AppColors.accent,
      ),
      (
        segment: RouteSegment.returnLeg,
        label: AppStrings.showReturn,
        icon: Iconsax.refresh,
        color: AppColors.warning,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.map((option) {
          final selected = option.segment == current;
          final color = option.color;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(option.segment);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: AppColors.shadowSoft,
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      option.icon,
                      size: 17,
                      color: selected ? color : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSm.copyWith(
                          color: selected ? color : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final OptimizedRoute route;
  const _MetricsGrid({required this.route});

  @override
  Widget build(BuildContext context) {
    final m = route.metrics;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        RouteMetricsCard(
          icon: Iconsax.timer_1,
          label: AppStrings.estimatedTime,
          value: m.estimatedDurationMinutes == null
              ? null
              : MetricFormat.duration(m.estimatedDurationMinutes!),
          color: AppColors.primary,
        ),
        RouteMetricsCard(
          icon: Iconsax.routing,
          label: AppStrings.totalDistance,
          value: m.totalDistanceKm == null
              ? null
              : MetricFormat.distance(m.totalDistanceKm!),
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _StartNavigationButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartNavigationButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final arrowIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [AppColors.accent, AppColors.accentDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.play,
                  color: AppColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.startNavigation,
                      style: AppTextStyles.titleLg.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.navigationSubtitle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(arrowIcon, color: AppColors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
