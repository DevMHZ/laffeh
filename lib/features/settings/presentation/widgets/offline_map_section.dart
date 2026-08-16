import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_chevron.dart';
import '../../../../core/services/map_cache_service.dart';
import '../../../../core/services/map_pack_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/offline_area_picker_page.dart';

/// Offline map row in Settings: a saved patch of map, with no trip involved.
///
/// The trip corridor in the route summary only helps someone who has
/// already planned one. A driver who opens the app in a basement, or drives
/// out of coverage before planning anything, needs map under them
/// regardless — that is what this saves, and why it lives in Settings
/// rather than anywhere in the planning flow.
///
/// Deliberately thin: everything about choosing and downloading lives in
/// [openOfflineAreaPicker], which the offer on the map opens too, so both
/// routes into the feature behave identically. All this row owes the
/// driver is whether a map is saved and how big it is.
class OfflineMapSection extends StatefulWidget {
  const OfflineMapSection({super.key});

  @override
  State<OfflineMapSection> createState() => _OfflineMapSectionState();
}

class _OfflineMapSectionState extends State<OfflineMapSection> {
  final MapPackController _pack = MapPackController.area;

  /// What is stored right now. Read from the saved regions rather than from
  /// the download controller: the controller knows only about the pack it
  /// last touched, and with several areas saved that is not the answer to
  /// "how much map do I have?".
  List<SavedMapArea> _saved = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final saved = await MapCacheService.savedAreas();
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pack,
      builder: (context, _) {
        final downloading = _pack.status == MapPackStatus.downloading;
        final totalMb =
            _saved.fold<int>(0, (sum, a) => sum + a.bytes) / 1048576;

        final (String value, Color tint) = downloading
            ? (AppStrings.percent(_pack.percent), AppColors.info)
            : _saved.isNotEmpty
            ? (AppStrings.megabytes(totalMb), AppColors.success)
            : (AppStrings.offlineAreaNotSaved, AppColors.textMuted);

        return InkWell(
          // Areas may have been added or deleted on the picker, so the row
          // re-reads what is stored when it comes back.
          onTap: () async {
            await openOfflineAreaPicker(context);
            await _reload();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Iconsax.map, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.offlineAreaTitle,
                        style: AppTextStyles.titleMd,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        downloading
                            ? AppStrings.offlineMapDownloading
                            : _saved.isNotEmpty
                            ? AppStrings.offlineAreaSavedCount(_saved.length)
                            : AppStrings.offlineAreaHint,
                        style: AppTextStyles.mutedSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  value,
                  style: AppTextStyles.mutedSm.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const AppChevron(),
              ],
            ),
          ),
        );
      },
    );
  }
}
