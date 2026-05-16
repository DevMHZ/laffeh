import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/saved_route.dart';

/// Card representation of a saved route in the history list.
class SavedRouteCard extends StatelessWidget {
  final SavedRoute route;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const SavedRouteCard({
    super.key,
    required this.route,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = intl.DateFormat('yyyy/MM/dd • HH:mm', 'en');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: busy ? null : onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.routing_2,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            route.name,
                            style: AppTextStyles.titleLg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(route.savedAt),
                            style: AppTextStyles.mutedSm,
                          ),
                        ],
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    else
                      _OverflowMenu(
                        onRename: onRename,
                        onDelete: onDelete,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Stat(
                      icon: Iconsax.location,
                      label: '${route.stopsCount} نقطة',
                    ),
                    const SizedBox(width: 10),
                    _Stat(
                      icon: Iconsax.routing,
                      label: route.metrics.totalDistanceKm == null
                          ? '--'
                          : MetricFormat.distance(
                              route.metrics.totalDistanceKm!),
                    ),
                    const SizedBox(width: 10),
                    _Stat(
                      icon: Iconsax.timer_1,
                      label: route.metrics.estimatedDurationMinutes == null
                          ? '--'
                          : MetricFormat.duration(
                              route.metrics.estimatedDurationMinutes!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySm),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _OverflowMenu({required this.onRename, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      icon: const Icon(Iconsax.more,
          size: 20, color: AppColors.textSecondary),
      onSelected: (a) {
        switch (a) {
          case _MenuAction.rename:
            onRename();
            break;
          case _MenuAction.delete:
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _MenuAction.rename,
          child: Row(
            children: [
              Icon(Iconsax.edit, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text(AppStrings.rename),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.delete,
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

enum _MenuAction { rename, delete }
