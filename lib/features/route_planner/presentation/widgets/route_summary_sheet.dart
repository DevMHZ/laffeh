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
import 'route_point_tile.dart';

class RouteSummarySheet extends StatelessWidget {
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback? onExportCsv;

  const RouteSummarySheet({super.key, this.onOpenGoogleMaps, this.onExportCsv});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) => a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();

        final order = route.orderedPoints;

        return AppSheetContainer(
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Compact inline metrics ──────────────────────────────
              _InlineMetrics(route: route),
              const SizedBox(height: 12),

              // ── Primary: start the trip ─────────────────────────────
              _StartNavigationButton(onPressed: cubit.startNavigation),
              const SizedBox(height: 8),

              // ── Secondary: preview / open in external maps ──────────
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: AppStrings.previewRoute,
                      icon: Iconsax.play_circle,
                      variant: AppButtonVariant.secondary,
                      height: 50,
                      radius: 14,
                      onPressed: cubit.startSimulation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: AppStrings.googleMapsShort,
                      icon: Iconsax.map_1,
                      variant: AppButtonVariant.secondary,
                      height: 50,
                      radius: 14,
                      onPressed: onOpenGoogleMaps,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Tertiary: save / export ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Iconsax.save_2,
                      label: AppStrings.save,
                      onTap: () => _saveRoute(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionTile(
                      icon: Iconsax.document_upload,
                      label: 'CSV',
                      onTap: onExportCsv,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Route sequence ──────────────────────────────────────
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
              const SizedBox(height: 8),
              ...order.asMap().entries.map((e) {
                final isReturn =
                    e.key == order.length - 1 && e.value.isDepot;
                return RoutePointTile(
                  point: e.value,
                  index: e.key,
                  isReturnPoint: isReturn,
                );
              }),
              const SizedBox(height: 14),

              // ── Destructive escape hatch ────────────────────────────
              _StartFreshButton(
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
    if (choice == null) return;
    if (!context.mounted) return;

    if (choice == SaveBeforeClearChoice.save) {
      final defaultName =
          '${AppStrings.defaultRouteName} • ${_shortDate(DateTime.now())}';
      final name = await showSaveRouteDialog(context, initialName: defaultName);
      if (name == null) return;
      if (!context.mounted) return;

      try {
        final saved = await cubit.saveCurrentRouteToHistory(name);
        if (saved == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(AppStrings.errSaveRoute)),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.routeSavedMsg)),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.routeSaveFailed(e))),
        );
        return;
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
            saved == null
                ? AppStrings.errSaveRoute
                : AppStrings.routeSavedMsg,
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

// ─────────────────────────────────────────────────────────────────────────────
// Compact metrics row — replaces the old GridView card layout.
// One thin bar with icon + value + label for each metric, separated by a line.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineMetrics extends StatelessWidget {
  final OptimizedRoute route;
  const _InlineMetrics({required this.route});

  @override
  Widget build(BuildContext context) {
    final m = route.metrics;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              icon: Iconsax.timer_1,
              label: AppStrings.estimatedTime,
              value: m.estimatedDurationMinutes == null
                  ? AppStrings.unavailable
                  : MetricFormat.duration(m.estimatedDurationMinutes!),
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(
            child: _MetricItem(
              icon: Iconsax.routing,
              label: AppStrings.totalDistance,
              value: m.totalDistanceKm == null
                  ? AppStrings.unavailable
                  : MetricFormat.distance(m.totalDistanceKm!),
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppTextStyles.titleMd),
            Text(label, style: AppTextStyles.mutedSm),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StartFreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartFreshButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.trash, color: AppColors.danger, size: 19),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  AppStrings.startFresh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon + label tile for tertiary actions (Save / CSV).
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: AppColors.textPrimary),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mutedSm.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
