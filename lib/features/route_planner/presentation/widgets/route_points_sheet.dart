import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'optimize_route_button.dart';
import 'route_point_tile.dart';

class RoutePointsSheet extends StatelessWidget {
  const RoutePointsSheet({super.key});

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
              ? '${state.points.length} نقطة • اسحب لإعادة الترتيب'
              : AppStrings.tapToAddPoint,
          actions: [
            if (state.hasPoints)
              IconButton(
                tooltip: AppStrings.clearAll,
                onPressed: cubit.clearAll,
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
              if (!state.hasPoints)
                const _EmptyState()
              else
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    itemCount: state.points.length,
                    onReorder: cubit.reorderPoint,
                    proxyDecorator: (child, _, __) =>
                        Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, index) {
                      final p = state.points[index];
                      return Padding(
                        key: ValueKey(p.id),
                        padding: EdgeInsets.zero,
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
                ),
              if (state.errorMessage != null &&
                  state.status == RoutePlannerStatus.optimizedFailure) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.info_circle,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: AppTextStyles.danger13w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppColors.primarySoft, AppColors.surface],
                radius: 0.85,
              ),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Iconsax.location_add,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text('ابدأ بإنشاء مسارك', style: AppTextStyles.titleLg),
          const SizedBox(height: 4),
          Text(
            AppStrings.noPointsYet,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _HintRow(
            icon: Iconsax.flag,
            color: AppColors.primary,
            label: '1. اضغط على الخريطة لتحديد نقطة الانطلاق',
          ),
          const SizedBox(height: 6),
          _HintRow(
            icon: Iconsax.location_tick,
            color: AppColors.accent,
            label: '2. أضف باقي الوجهات بنفس الطريقة',
          ),
          const SizedBox(height: 6),
          _HintRow(
            icon: Iconsax.routing_2,
            color: AppColors.info,
            label: "اضغط (تحسين المسار) — الذكاء الاصطناعي بيتكفّل بالباقي",
          ),
        ],
      ),
    );
  }
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
            color: color.withOpacity(0.12),
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
