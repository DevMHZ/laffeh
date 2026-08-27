import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/config/planner_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/place_suggestion.dart';
import '../pages/route_planner_actions.dart';
import '../cubit/route_planner_cubit.dart';

/// What opens when the driver taps a name printed on the map.
///
/// The gesture that every map app has taught every driver: you see a place
/// on the map, you touch it, and the app tells you what it is and offers to
/// take you there. Before this, a place the map was already *displaying* by
/// name could only be added by typing that name back into a search box —
/// asking the driver to spell out something the app had just drawn for them.
///
/// Deliberately short. Two actions, because a place on a planned round is
/// either somewhere you are going or where you are starting from, and a
/// sheet of six choices over a map is a sheet nobody reads while driving.
Future<void> showMapPlaceSheet(
  BuildContext context,
  RoutePlannerCubit cubit,
  PlaceSuggestion place,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _MapPlaceSheet(
      place: place,
      distanceKm: () {
        final from = cubit.searchAnchor;
        return from == null
            ? null
            : DistanceUtils.haversineKm(from, place.latLng);
      }(),
      // A place already on the route is not somewhere to add again — the
      // planner rejects a duplicate anyway, and an action that silently
      // does nothing is worse than an action that isn't offered.
      alreadyAdded: cubit.state.points.any(
        (p) =>
            DistanceUtils.haversineKm(p.latLng, place.latLng) * 1000 <
            PlannerConfig.minSeparationMeters,
      ),
      onAddStop: () {
        Navigator.pop(sheetCtx);
        RoutePlannerActions.addPointConfirmed(
          context,
          cubit,
          place.latLng,
          address: place.fullLabel,
        );
        unawaited(cubit.rememberPlace(place));
      },
      onSetDeparture: () {
        Navigator.pop(sheetCtx);
        unawaited(cubit.setDeparture(place.latLng, address: place.fullLabel));
        unawaited(cubit.rememberPlace(place));
      },
    ),
  );
}

class _MapPlaceSheet extends StatelessWidget {
  final PlaceSuggestion place;
  final double? distanceKm;
  final bool alreadyAdded;
  final VoidCallback onAddStop;
  final VoidCallback onSetDeparture;

  const _MapPlaceSheet({
    required this.place,
    required this.distanceKm,
    required this.alreadyAdded,
    required this.onAddStop,
    required this.onSetDeparture,
  });

  IconData get _icon => switch (place.kind) {
    PlaceKind.street => Iconsax.routing_2,
    PlaceKind.city => Iconsax.buildings_2,
    PlaceKind.region => Iconsax.global,
    PlaceKind.area => Iconsax.buildings,
    PlaceKind.address => Iconsax.house,
    _ => Iconsax.location,
  };

  @override
  Widget build(BuildContext context) {
    // The category when the tile knew one, and the coordinates when it did
    // not — so the sheet always says *something* about where this is.
    final subtitle =
        place.context ??
        '${place.latLng.latitude.toStringAsFixed(5)}, '
            '${place.latLng.longitude.toStringAsFixed(5)}';

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
                      color: AppColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: AppTextStyles.titleMd,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (distanceKm != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      MetricFormat.distance(distanceKm!),
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.divider),
            if (alreadyAdded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.tick_circle,
                      size: 21,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        AppStrings.mapPlaceAlreadyAdded,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _ActionRow(
                icon: Iconsax.add_circle,
                label: AppStrings.mapPlaceAddStop,
                color: AppColors.primary,
                onTap: onAddStop,
              ),
            _ActionRow(
              icon: Iconsax.flag,
              label: AppStrings.mapPlaceSetDeparture,
              color: AppColors.info,
              onTap: onSetDeparture,
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
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
