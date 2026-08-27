import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../constants/app_constants.dart';
import '../services/map_cache_service.dart';
import '../services/map_pack_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_chevron.dart';
import 'offline_area_picker_page.dart';

/// Offline map row: a saved patch of map, with no trip involved.
///
/// The trip corridor only helps someone who has already planned a route. A
/// driver who opens the app in a basement, or drives out of coverage before
/// planning anything, needs map under them regardless — that is what this
/// saves.
///
/// Shown in two places, both reading the same saved regions: Settings, and
/// the offline sheet behind the map's own offline button.
///
/// Deliberately thin: everything about choosing and downloading lives in
/// [openOfflineAreaPicker], which the offer on the map opens too, so both
/// routes into the feature behave identically. All this row owes the
/// driver is whether a map is saved and how big it is.
class OfflineAreaSection extends StatefulWidget {
  const OfflineAreaSection({super.key});

  @override
  State<OfflineAreaSection> createState() => _OfflineAreaSectionState();
}

class _OfflineAreaSectionState extends State<OfflineAreaSection> {
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
