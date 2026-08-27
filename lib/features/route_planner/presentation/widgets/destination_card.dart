import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
// `show` because intl also exports a TextDirection, which would shadow
// the Flutter one this file uses for the RTL arrow.
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';

/// What the driver sees when they have asked for exactly one place: a
/// navigator's trip card, not a plan.
///
/// There is nothing to order, nothing to optimize and nothing to step
/// through, so none of that is on screen. Time, distance, arrival, and one
/// button that starts driving.
///
/// The single line about a second stop is the whole multi-stop pitch, and it
/// is deliberately an action rather than an advertisement: it sits where a
/// driver would look after deciding this trip has more than one errand in it,
/// it says what the app will do for them, and pressing it turns this card
/// into the planner. Discovery by use, not by banner.
class DestinationCard extends StatelessWidget {
  final RoutePoint destination;

  /// The routed trip, once it exists. Null while it is still being fetched
  /// or when the fetch failed — [routing] tells the two apart.
  final OptimizedRoute? route;

  /// True while the route is being fetched in the background.
  final bool routing;

  /// When the driver sets off. Null — the usual case — means now, which is
  /// what a navigator assumes; a departure the driver actually set is what
  /// the arrival clock has to be measured from.
  final DateTime? departureAt;

  /// Where the trip starts, when the driver named it themselves. Null means
  /// the default — wherever they are right now.
  final RoutePoint? departureFrom;

  final VoidCallback onGo;
  final VoidCallback onAddAnotherStop;
  final VoidCallback onChangeDestination;
  final VoidCallback onChangeDeparture;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.route,
    required this.routing,
    this.departureAt,
    this.departureFrom,
    required this.onGo,
    required this.onAddAnotherStop,
    required this.onChangeDestination,
    required this.onChangeDeparture,
  });

  @override
  Widget build(BuildContext context) {
    // The address leads. Until the reverse lookup lands the point's own name
    // stands in — and for a lone destination that name is already "the
    // destination", so there is no second line to add underneath it.
    final address = destination.address?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    final title = hasAddress ? address : destination.label;

    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: AppColors.shadow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Handle(),
              const SizedBox(height: 10),
              // The trip starts where the driver is — an assumption right
              // almost every time, and wrong often enough that it has to be
              // visible and one tap from being replaced.
              _DepartureRow(from: departureFrom, onTap: onChangeDeparture),
              const SizedBox(height: 6),
              _TitleRow(title: title, onChange: onChangeDestination),
              const SizedBox(height: 12),
              _TripLine(
                route: route,
                routing: routing,
                departureAt: departureAt,
              ),
              const SizedBox(height: 14),
              _GoButton(onTap: onGo),
              const SizedBox(height: 10),
              _AddAnotherStopRow(onTap: onAddAnotherStop),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

/// "From · my current location", quiet and tappable.
///
/// Subordinate to the destination on purpose: it is a default that is
/// usually right, so it must be readable at a glance and never compete with
/// where the driver is actually going.
class _DepartureRow extends StatelessWidget {
  final RoutePoint? from;
  final VoidCallback onTap;

  const _DepartureRow({required this.from, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final custom = from;
    final named = custom?.address?.trim();
    final label = custom == null
        ? AppStrings.currentLocationLabel
        : (named != null && named.isNotEmpty)
        ? named
        : AppStrings.departure;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Icon(
                custom == null ? Icons.my_location_rounded : Iconsax.flag,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 9),
              Text('${AppStrings.fromLabel} · ', style: AppTextStyles.mutedSm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Iconsax.edit_2, size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final String title;
  final VoidCallback onChange;

  const _TitleRow({required this.title, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Iconsax.location, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMd,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: AppStrings.changeDestination,
          onPressed: () {
            HapticFeedback.selectionClick();
            onChange();
          },
          icon: Icon(
            Iconsax.close_circle,
            size: 22,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Time · distance · arrival — the three numbers a navigator leads with.
///
/// Before the route lands there is nothing honest to show, so the row says
/// what it is doing instead of rendering placeholder dashes that look like a
/// broken trip.
class _TripLine extends StatelessWidget {
  final OptimizedRoute? route;
  final bool routing;
  final DateTime? departureAt;

  const _TripLine({
    required this.route,
    required this.routing,
    required this.departureAt,
  });

  @override
  Widget build(BuildContext context) {
    final r = route;
    if (r == null) {
      return Row(
        children: [
          if (routing) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
          ] else ...[
            Icon(Iconsax.routing, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              routing
                  ? AppStrings.findingRoute
                  : AppStrings.routeUnavailableTapGo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mutedSm,
            ),
          ),
        ],
      );
    }

    final minutes = r.metrics.estimatedDurationMinutes;
    final km = r.metrics.totalDistanceKm;
    final eta = minutes == null
        ? null
        : DateFormat('HH:mm').format(
            (departureAt ?? DateTime.now()).add(
              Duration(minutes: minutes.round()),
            ),
          );

    return Row(
      children: [
        if (minutes != null) ...[
          Text(
            MetricFormat.duration(minutes),
            style: AppTextStyles.titleLg.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: 10),
        ],
        if (km != null)
          Flexible(
            child: Text(
              MetricFormat.distance(km),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (eta != null) ...[
          const Spacer(),
          Icon(Iconsax.clock, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text('${AppStrings.arrivalLabel} $eta', style: AppTextStyles.mutedSm),
        ],
      ],
    );
  }
}

/// The one action. Same accent gradient the planner's "start driving" uses —
/// a driver who graduates to multi-stop should recognise the button that
/// starts a trip.
class _GoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final arrow = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [AppColors.accent, AppColors.accentDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.navigation_rounded,
                  color: AppColors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.goNow,
                  style: AppTextStyles.button.copyWith(color: AppColors.white),
                ),
                const SizedBox(width: 8),
                Icon(arrow, color: AppColors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bridge into the business. Quiet by design — it must never compete
/// with Go — but it states the offer plainly, because a driver who never
/// learns Laffeh orders stops for them has no reason to prefer it to any
/// other navigator.
class _AddAnotherStopRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAnotherStopRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Iconsax.add_circle, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.addAnotherStop,
                      style: AppTextStyles.titleSm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.addAnotherStopSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mutedSm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
