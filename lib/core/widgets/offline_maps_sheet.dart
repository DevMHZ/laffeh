import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'offline_area_section.dart';
import 'trip_map_pack_tile.dart';

/// Everything about maps that keep working without a signal, in one sheet.
///
/// The two packs used to live apart — a saved area in Settings, the trip
/// corridor at the bottom of the route summary — so a driver about to lose
/// coverage had to know which of the two screens held which. They are the
/// same decision ("will the map still be there?"), so they are now the same
/// sheet, opened from the map itself by [OfflineMapsFab].
///
/// [polyline] is the driven geometry of the current plan, or null when
/// nothing is planned yet; the trip tile downloads a corridor only when it
/// has one.
Future<void> showOfflineMapsSheet(
  BuildContext context, {
  List<LatLng>? polyline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _OfflineMapsSheet(polyline: polyline),
  );
}

class _OfflineMapsSheet extends StatelessWidget {
  final List<LatLng>? polyline;

  const _OfflineMapsSheet({this.polyline});

  @override
  Widget build(BuildContext context) {
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
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.map,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.offlineMapsSheetTitle,
                            style: AppTextStyles.titleMd,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            AppStrings.offlineMapsSheetBody,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.divider),
              // The area first: it is the one that works with no trip
              // planned, which is the state this sheet is usually opened in.
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: OfflineAreaSection(),
              ),
              Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: TripMapPackTile(polyline: polyline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
