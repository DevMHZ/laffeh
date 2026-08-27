import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../config/offline_map_config.dart';
import '../constants/app_constants.dart';
import '../network/network_info.dart';
import '../services/map_cache_service.dart';
import '../services/map_pack_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/distance_utils.dart';
import '../utils/route_corridor.dart';
import 'map_pack_progress_view.dart';

/// The trip's offline map — the corridor along the planned route.
///
/// Downloading is an explicit choice rather than something the app does
/// behind the driver's back: a corridor runs to tens of megabytes, and
/// spending a driver's mobile data unasked is not ours to do. The estimate
/// is shown up front for the same reason.
///
/// One widget for the two places it is offered, because they are the same
/// pack and must never disagree about it:
///
///   * the **route summary sheet**, which has the plan in hand and passes
///     its [polyline] — the place the download is actually worth starting,
///     but a poor place to leave a heavy card, so it sits low and quiet;
///   * the **offline sheet** behind the map's own button, which passes the
///     planned geometry when there is a plan and nothing when there is not.
///     With nothing it still reports what is stored and can delete it.
///
/// The map *around* the driver is a different pack, downloaded with no route
/// in sight — see `OfflineAreaSection`.
class TripMapPackTile extends StatefulWidget {
  /// Driven geometry to save. Null on screens with no plan in hand, which
  /// then read the stored pack rather than binding a new one.
  final List<LatLng>? polyline;

  const TripMapPackTile({super.key, this.polyline});

  @override
  State<TripMapPackTile> createState() => _TripMapPackTileState();
}

class _TripMapPackTileState extends State<TripMapPackTile> {
  final MapPackController _pack = MapPackController.route;

  /// The size quoted when the driver pressed download, held so the figure
  /// under the bar stays the one they agreed to.
  double? _quotedMb;

  /// What is on disk for the trip pack when no screen has bound it — the
  /// offline sheet opened with no plan. Null until the disk has answered.
  int? _storedBytes;

  /// Whether the shared controller is describing *this* pack. It is the
  /// only instance that ever holds a corridor, but it holds nothing at all
  /// until a plan binds one.
  bool get _bound => _pack.packId == OfflineMapConfig.tripPackId;

  /// The corridor this screen would download, chunked once per plan rather
  /// than per rebuild — chunking walks the whole polyline. Null on a screen
  /// that has no plan.
  List<CoordinateBounds>? _boxes;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TripMapPackTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Identity, not equality: the sheet hands over the route's own list, so
    // a plain rebuild must not re-run the disk check underneath a download.
    if (!identical(oldWidget.polyline, widget.polyline)) _sync();
  }

  void _sync() {
    final line = widget.polyline;
    _boxes = line == null ? null : RouteCorridor.chunk(line);

    final boxes = _boxes;
    if (boxes != null) {
      _pack.bind(packId: OfflineMapConfig.tripPackId, boxes: boxes);
    } else {
      _readStored();
    }
  }

  Future<void> _readStored() async {
    final bytes = await MapCacheService.cachedBytesForPack(
      OfflineMapConfig.tripPackId,
    );
    if (!mounted) return;
    setState(() => _storedBytes = bytes);
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await NetworkInfo().isConnected) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.offlineMapNeedsConnection)),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _quotedMb = _pack.estimatedMb);

    final boxes = _boxes;
    if (boxes != null) {
      await _pack.download(packId: OfflineMapConfig.tripPackId, boxes: boxes);
    } else {
      // No geometry of our own: act on the corridor the planner bound.
      await _pack.downloadBound();
    }
  }

  Future<void> _delete() async {
    if (_bound) {
      await _pack.delete();
      return;
    }
    // Nothing is bound, so the controller has no pack to delete — the tiles
    // are still on disk and still ours to remove.
    await MapCacheService.deletePack(OfflineMapConfig.tripPackId);
    await _readStored();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pack,
      builder: (context, _) {
        // With nothing bound, the only truth available is what is on disk —
        // and until it answers, the honest state is "still looking".
        final status = _bound
            ? _pack.status
            : _storedBytes == null
            ? MapPackStatus.checking
            : _storedBytes! > 0
            ? MapPackStatus.ready
            : MapPackStatus.idle;
        final storedMb = _bound
            ? _pack.storedMb
            : (_storedBytes ?? 0) / 1048576;
        final downloading = status == MapPackStatus.downloading;

        // Idle with no geometry behind it is not an offer — it is a note
        // about where the offer lives.
        final canDownload = _boxes != null || _pack.hasBoxes;

        final (IconData icon, Color tint) = switch (status) {
          MapPackStatus.ready => (Iconsax.tick_circle, AppColors.success),
          MapPackStatus.partial => (Iconsax.warning_2, AppColors.warning),
          MapPackStatus.failed => (Iconsax.warning_2, AppColors.danger),
          _ => (Iconsax.map, AppColors.info),
        };

        final subtitle = switch (status) {
          MapPackStatus.downloading => AppStrings.offlineMapDownloading,
          MapPackStatus.ready =>
            '${AppStrings.offlineMapReady} · '
                '${AppStrings.megabytes(storedMb)}',
          MapPackStatus.partial => AppStrings.offlineMapPartial,
          MapPackStatus.cancelled => AppStrings.offlineMapCancelled,
          MapPackStatus.failed => AppStrings.offlineMapFailed,
          _ when !canDownload => AppStrings.offlineMapNoTrip,
          _ =>
            '${AppStrings.offlineMapIdleHint} '
                '${AppStrings.approxMegabytes(_pack.estimatedMb)}',
        };

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.offlineMapTitle,
                        style: AppTextStyles.titleMd,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.mutedSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _packAction(status, downloading, canDownload),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 10),
              MapPackProgressView(
                pack: _pack,
                estimatedMb: _quotedMb ?? _pack.estimatedMb,
                barHeight: 4,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _packAction(MapPackStatus status, bool downloading, bool canDownload) {
    if (status == MapPackStatus.checking) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // While downloading, cancel lives inside the progress block below —
    // repeating it here would put two of them on one tile.
    if (downloading) return const SizedBox.shrink();
    if (status == MapPackStatus.ready) {
      return IconButton(
        tooltip: AppStrings.offlineMapDelete,
        onPressed: _delete,
        visualDensity: VisualDensity.compact,
        icon: Icon(Iconsax.trash, size: 19, color: AppColors.danger),
      );
    }
    // Nothing to download and nothing stored: the subtitle already says
    // where the download lives, and a dead button would say it worse.
    if (!canDownload) return const SizedBox.shrink();
    // A half-finished pack keeps its tiles, so the offer is to carry on
    // rather than to start over.
    return TextButton(
      onPressed: _download,
      child: Text(switch (status) {
        MapPackStatus.partial => AppStrings.offlineMapRetry,
        MapPackStatus.cancelled => AppStrings.offlineMapResume,
        _ => AppStrings.offlineMapDownload,
      }, style: TextStyle(color: AppColors.primary)),
    );
  }
}
