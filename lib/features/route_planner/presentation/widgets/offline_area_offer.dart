import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/map_cache_service.dart';
import '../../../../core/services/map_pack_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/offline_area_picker_page.dart';

/// The one time we bring up offline maps ourselves.
///
/// A driver cannot ask for a saved map at the moment they need it — by then
/// they have no signal. So the offer has to arrive while they still do, and
/// this is it: a single line on the planning sheet, shown only while
/// nothing is saved, that opens the same picker Settings does.
///
/// It is an offer, not a prompt. One dismissal is remembered for good: an
/// app that asks twice about spending mobile data has stopped asking and
/// started nagging. Settings keeps the door open afterwards.
class OfflineAreaOffer extends StatefulWidget {
  const OfflineAreaOffer({super.key});

  /// Key for the "don't offer again" flag.
  static const String dismissedKey = 'offline_area_offer_dismissed';

  @override
  State<OfflineAreaOffer> createState() => _OfflineAreaOfferState();
}

class _OfflineAreaOfferState extends State<OfflineAreaOffer> {
  final MapPackController _pack = MapPackController.area;

  /// Whether the driver has waved this away for good.
  bool _dismissed = false;

  /// True once anything at all is saved — the offer has nothing left to
  /// raise. Asked of the stored regions rather than of the download
  /// controller, which only ever knows about the last pack it touched.
  bool _hasSaved = false;

  /// Null only where the locator was never set up — a preview or a test.
  /// An optional banner has no business bringing the sheet down with it
  /// when its storage is missing, so the lookup is allowed to come back
  /// empty and the offer simply stops remembering.
  SharedPreferences? get _prefs =>
      sl.isRegistered<SharedPreferences>() ? sl<SharedPreferences>() : null;

  @override
  void initState() {
    super.initState();
    // Prefs are already in memory by this point (loaded at startup), so the
    // flag reads synchronously and the offer never flashes in and back out.
    _dismissed = _prefs?.getBool(OfflineAreaOffer.dismissedKey) ?? false;
    _refreshSaved();
  }

  Future<void> _refreshSaved() async {
    final saved = await MapCacheService.savedAreas();
    if (!mounted) return;
    setState(() => _hasSaved = saved.isNotEmpty);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    await _prefs?.setBool(OfflineAreaOffer.dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _pack,
      builder: (context, _) {
        // Nothing to offer once something is saved, or while it is being
        // saved — the picker itself is where a running download is watched.
        if (_hasSaved || _pack.isBusy) return const SizedBox.shrink();

        // One tap target for the whole row rather than a button beside the
        // text: the banner says one thing and does one thing, and the only
        // other choice — never mind — is the × that ends it for good.
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                await openOfflineAreaPicker(context);
                await _refreshSaved();
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Row(
                  children: [
                    Icon(Iconsax.map_1, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.offlineAreaOfferTitle,
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.offlineAreaOfferBody,
                            style: AppTextStyles.mutedSm,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.offlineAreaOfferAccept,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.offlineAreaOfferDismiss,
                      onPressed: _dismiss,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
