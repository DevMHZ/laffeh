import 'package:flutter/material.dart';
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
  const RouteSummarySheet({super.key});

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
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetricsGrid(route: route),
              const SizedBox(height: 18),
              _StartSimulationButton(onPressed: cubit.startSimulation),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text('ترتيب اللفة', style: AppTextStyles.titleMd),
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
                      '${order.length} نقطة',
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
              const SizedBox(height: 14),
              AppButton(
                label: AppStrings.startNewRoute,
                icon: Iconsax.refresh,
                variant: AppButtonVariant.outlined,
                onPressed: () => _handleStartNew(context),
              ),
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
            const SnackBar(content: Text('تعذر حفظ المسار')),
          );
          return; // don't clear — let the user retry
        }
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.routeSavedMsg)),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('تعذر حفظ المسار: $e')));
        return; // don't clear on failure
      }
    }

    cubit.clearAll();
  }

  String _shortDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
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

class _StartSimulationButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartSimulationButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.accent.withOpacity(0.30),
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
                  color: Colors.white.withOpacity(0.18),
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
                      AppStrings.startSimulation,
                      style: AppTextStyles.titleLg.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'شاهد مسارك من البداية للنهاية',
                      style: AppTextStyles.bodySm.copyWith(
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Iconsax.arrow_left, color: AppColors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
