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
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';

part 'route_summary_sheet_widgets.dart';

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
              // One full-width row per stop (not a 3-up grid) so the optimised
              // order reads cleanly top-to-bottom.
              Column(
                children: [
                  for (var i = 0; i < order.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _orderCell(order[i], i + 1, order.length),
                  ],
                ],
              ),
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

  /// One full-width row for a single stop in the optimised sequence — order
  /// number badge, label, and (when known) address. Laid out one per line for
  /// clear order reading.
  Widget _orderCell(RoutePoint p, int index, int total) {
    final i = index - 1;
    final isReturn = i == total - 1 && p.isDepot && i != 0;
    final color = p.isDeactivated
        ? AppColors.optionalOff
        : p.isDepot && !isReturn
        ? AppColors.primary
        : isReturn
        ? AppColors.accent
        : p.optional
        ? AppColors.optional
        : AppColors.info;
    final icon = p.isDepot && !isReturn
        ? Iconsax.flag
        : isReturn
        ? Iconsax.home_2
        : p.optional
        ? Iconsax.star_1
        : Iconsax.location;
    return _SummaryGridCell(
      key: ValueKey(p.id),
      point: p,
      index: index,
      color: color,
      icon: icon,
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
