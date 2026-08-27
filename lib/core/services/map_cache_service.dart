import 'dart:async';

import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../config/env_config.dart';
import '../config/offline_map_config.dart';
import '../utils/debug_log.dart';
import '../utils/distance_utils.dart';
import '../utils/route_corridor.dart';

/// Progress of a pack download, as a fraction plus the counts behind it.
class MapPackProgress {
  /// 0..1 across the whole pack, not just the box being fetched.
  final double fraction;
  final int completedChunks;
  final int totalChunks;
  final int bytes;

  const MapPackProgress({
    required this.fraction,
    required this.completedChunks,
    required this.totalChunks,
    required this.bytes,
  });
}

/// Outcome of a pack download.
class MapPackResult {
  final int downloadedChunks;
  final int failedChunks;
  final int bytes;
  final bool cancelled;

  const MapPackResult({
    required this.downloadedChunks,
    required this.failedChunks,
    required this.bytes,
    this.cancelled = false,
  });

  /// True when the pack is usable — every box landed.
  bool get isComplete =>
      !cancelled && failedChunks == 0 && downloadedChunks > 0;
}

/// One area the driver has saved for offline use.
class SavedMapArea {
  final String packId;
  final CoordinateBounds bounds;
  final int bytes;

  const SavedMapArea({
    required this.packId,
    required this.bounds,
    required this.bytes,
  });

  double get storedMb => bytes / 1048576;

  ll.LatLng get centre => ll.LatLng(
    (bounds.southWest.latitude + bounds.northEast.latitude) / 2,
    (bounds.southWest.longitude + bounds.northEast.longitude) / 2,
  );
}

/// Cancels an in-flight download between boxes.
///
/// Boxes already downloaded are kept: a partly-downloaded pack is a
/// partly-useful map, not garbage, and re-running the download skips
/// nothing but costs only what's missing anyway.
class MapPackCancelToken {
  bool _cancelled = false;

  /// Set by the download loop to the current box's "stop waiting" hook.
  ///
  /// Without it a cancel would only be noticed between boxes — up to three
  /// minutes of a button that looks broken while the driver's data keeps
  /// being spent on tiles they just asked us not to fetch.
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }
}

/// Owns everything about map tiles that survive going offline.
///
/// Two mechanisms, deliberately kept apart (see [OfflineMapConfig]):
/// [init] configures the *storage ceiling* for downloaded packs, and
/// [prefetchBoxes] / [prefetchRoute] download explicit *offline regions* —
/// the first for any rectangle the driver framed, whether or not a trip
/// exists, the second along a planned route.
///
/// Every method is defensive: the whole class is a nicety layered on top of
/// a working online app, so a missing platform channel (tests, desktop) or a
/// refusing tile host degrades to "no offline map", never to a crash.
class MapCacheService {
  MapCacheService._();

  /// Ceiling on how long one box may take before it is written off and the
  /// download moves on. Long enough for a dense city box on a slow
  /// connection, short enough that a stalled download can't hang the UI.
  static const Duration _boxTimeout = Duration(minutes: 3);

  /// Raises the downloaded-region tile ceiling and caps download concurrency.
  ///
  /// Safe to call before `runApp`; it only talks to the plugin's global
  /// channel, which needs no map widget to exist.
  static Future<void> init() async {
    try {
      await setOfflineTileCountLimit(OfflineMapConfig.offlineRegionTileLimit);
      await setOfflineMaxConcurrentRequests(
        maxRequests: OfflineMapConfig.maxConcurrentRequests,
        maxRequestsPerHost: OfflineMapConfig.maxRequestsPerHost,
      );
      DebugLog.map(
        'MapCache init: region tile limit='
        '${OfflineMapConfig.offlineRegionTileLimit} '
        'concurrency=${OfflineMapConfig.maxConcurrentRequests}',
      );
    } catch (e) {
      // No platform channel (unit tests, unsupported platform) — the app
      // stays fully functional online.
      DebugLog.map('MapCache init skipped: $e');
    }
  }

  /// Downloads the map along [polyline] so the trip can be driven with no
  /// network, tagging every box with [routeId] so it can be removed later.
  static Future<MapPackResult> prefetchRoute({
    required String routeId,
    required List<ll.LatLng> polyline,
    void Function(MapPackProgress)? onProgress,
    MapPackCancelToken? cancelToken,
  }) {
    return prefetchBoxes(
      packId: routeId,
      kind: OfflineMapConfig.kindCorridor,
      boxes: RouteCorridor.chunk(polyline),
      minZoom: OfflineMapConfig.corridorMinZoom,
      maxZoom: OfflineMapConfig.corridorMaxZoom,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// Downloads [boxes] as one pack tagged [packId] / [kind].
  ///
  /// Any pack previously stored under the same [packId] is deleted first,
  /// so re-downloading replaces it rather than stacking a second copy on
  /// top. Both the area and the corridor go through here — they differ only
  /// in how their boxes were computed.
  static Future<MapPackResult> prefetchBoxes({
    required String packId,
    required String kind,
    required List<CoordinateBounds> boxes,
    required double minZoom,
    required double maxZoom,
    CoordinateBounds? packBounds,
    void Function(MapPackProgress)? onProgress,
    MapPackCancelToken? cancelToken,
  }) async {
    if (boxes.isEmpty) {
      return const MapPackResult(
        downloadedChunks: 0,
        failedChunks: 0,
        bytes: 0,
      );
    }

    await deletePack(packId);

    DebugLog.map('MapCache prefetch $kind=$packId boxes=${boxes.length}');

    var done = 0;
    var failed = 0;
    var bytes = 0;

    for (var i = 0; i < boxes.length; i++) {
      if (cancelToken?.isCancelled ?? false) {
        DebugLog.map('MapCache prefetch cancelled after $done/${boxes.length}');
        return MapPackResult(
          downloadedChunks: done,
          failedChunks: failed,
          bytes: bytes,
          cancelled: true,
        );
      }

      // Progress spans the whole pack: each box contributes its own
      // fraction of one slot, so the bar advances smoothly rather than in
      // whole-box jumps.
      var boxFraction = 0.0;
      void report() {
        onProgress?.call(
          MapPackProgress(
            fraction: ((i + boxFraction) / boxes.length).clamp(0.0, 1.0),
            completedChunks: done,
            totalChunks: boxes.length,
            bytes: bytes,
          ),
        );
      }

      report();

      // `downloadOfflineRegion` resolves as soon as native has *created*
      // the region — the tiles then stream in behind it. Waiting on the
      // returned future alone would fire every box at once and report
      // success before a single tile landed, so the terminal event on the
      // progress channel is what we actually await.
      final finished = Completer<bool>();
      void settle(bool ok) {
        if (!finished.isCompleted) finished.complete(ok);
      }

      // Stop waiting on this box the instant the driver cancels, rather
      // than at the next box boundary.
      cancelToken?._onCancel = () => settle(false);

      try {
        final region = await downloadOfflineRegion(
          OfflineRegionDefinition(
            bounds: _toLatLngBounds(boxes[i]),
            mapStyleUrl: EnvConfig.mapStyleUrl,
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
          metadata: <String, dynamic>{
            OfflineMapConfig.metaPackId: packId,
            OfflineMapConfig.metaKind: kind,
            // Every box carries the whole pack's rectangle, so the pack can
            // be listed and drawn even if some of its boxes failed.
            if (packBounds != null)
              OfflineMapConfig.metaBounds: _encodeBounds(packBounds),
            'index': i,
          },
          onEvent: (event) {
            if (event is InProgress) {
              // Native reports 0..100.
              boxFraction = (event.progress / 100).clamp(0.0, 1.0);
              report();
            } else if (event is Success) {
              settle(true);
            } else {
              // The only other terminal event is the plugin's error type,
              // matched structurally to avoid colliding with dart:core's
              // `Error` in this file's namespace.
              settle(false);
            }
          },
        );

        final ok = await finished.future.timeout(
          _boxTimeout,
          onTimeout: () => false,
        );

        // A cancelled box is half a box: native keeps streaming its tiles
        // until the region is deleted, so leaving it would go on spending
        // the data the driver just stopped.
        if (cancelToken?.isCancelled ?? false) {
          await _deleteRegion(region.id);
          bytes = await _bytesForPack(packId);
          DebugLog.map('MapCache prefetch cancelled during box $i');
          return MapPackResult(
            downloadedChunks: done,
            failedChunks: failed,
            bytes: bytes,
            cancelled: true,
          );
        }

        if (ok) {
          done++;
        } else {
          failed++;
          DebugLog.map('MapCache box $i did not complete');
        }
      } catch (e) {
        // One refused box does not sink the pack — the rest of the map is
        // still worth having.
        failed++;
        DebugLog.map('MapCache box $i failed: $e');
      } finally {
        cancelToken?._onCancel = null;
      }

      bytes = await _bytesForPack(packId);
      boxFraction = 1.0;
      report();
    }

    DebugLog.map(
      'MapCache prefetch done $kind=$packId ok=$done failed=$failed '
      'bytes=$bytes',
    );

    return MapPackResult(
      downloadedChunks: done,
      failedChunks: failed,
      bytes: bytes,
    );
  }

  /// Every offline region tagged with [packId].
  static Future<List<OfflineRegion>> regionsForPack(String packId) async {
    try {
      final all = await getListOfRegions();
      return all
          .where((r) => r.metadata[OfflineMapConfig.metaPackId] == packId)
          .toList(growable: false);
    } catch (e) {
      DebugLog.map('MapCache regionsForPack failed: $e');
      return const [];
    }
  }

  /// Bytes currently stored for [packId], or 0 when nothing is downloaded.
  static Future<int> cachedBytesForPack(String packId) => _bytesForPack(packId);

  /// Whether [packId] has anything stored at all. Used to show the
  /// "downloaded" state without waiting on a size computation.
  static Future<bool> hasPack(String packId) async =>
      (await regionsForPack(packId)).isNotEmpty;

  /// Every area the driver has saved, newest boxes first grouped into packs.
  ///
  /// Read back from the stored regions rather than from a list we keep
  /// ourselves: the regions *are* the saved maps, so a pack cannot appear
  /// here without tiles behind it, nor tiles occupy the disk without
  /// appearing here.
  ///
  /// A pack whose bounds cannot be read is skipped rather than guessed at —
  /// it would be a region this version did not write, and drawing it in the
  /// wrong place is worse than not drawing it.
  static Future<List<SavedMapArea>> savedAreas() async {
    try {
      final all = await getListOfRegions();
      final byPack = <String, List<OfflineRegion>>{};

      for (final region in all) {
        if (region.metadata[OfflineMapConfig.metaKind] !=
            OfflineMapConfig.kindArea) {
          continue;
        }
        final packId = region.metadata[OfflineMapConfig.metaPackId];
        if (packId is! String) continue;
        byPack.putIfAbsent(packId, () => []).add(region);
      }

      final out = <SavedMapArea>[];
      for (final entry in byPack.entries) {
        final encoded =
            entry.value
                    .map((r) => r.metadata[OfflineMapConfig.metaBounds])
                    .firstWhere((b) => b is String, orElse: () => null)
                as String?;
        final bounds = encoded == null ? null : _decodeBounds(encoded);
        if (bounds == null) continue;

        out.add(
          SavedMapArea(
            packId: entry.key,
            bounds: bounds,
            bytes: await _sumBytes(entry.value),
          ),
        );
      }
      return out;
    } catch (e) {
      DebugLog.map('MapCache savedAreas failed: $e');
      return const [];
    }
  }

  /// `south,west,north,east` — a compact form that survives the platform
  /// channel's string-keyed metadata without a JSON dependency.
  static String _encodeBounds(CoordinateBounds b) =>
      '${b.southWest.latitude},${b.southWest.longitude},'
      '${b.northEast.latitude},${b.northEast.longitude}';

  static CoordinateBounds? _decodeBounds(String raw) {
    final parts = raw.split(',');
    if (parts.length != 4) return null;
    final values = [for (final p in parts) double.tryParse(p)];
    if (values.any((v) => v == null)) return null;
    return CoordinateBounds(
      southWest: ll.LatLng(values[0]!, values[1]!),
      northEast: ll.LatLng(values[2]!, values[3]!),
    );
  }

  /// Deletes the pack stored for [packId]. A no-op when there is none.
  static Future<void> deletePack(String packId) async {
    final regions = await regionsForPack(packId);
    if (regions.isEmpty) return;
    for (final region in regions) {
      await _deleteRegion(region.id);
    }
    DebugLog.map('MapCache deleted ${regions.length} regions for $packId');
  }

  static Future<void> _deleteRegion(int id) async {
    try {
      await deleteOfflineRegion(id);
    } catch (e) {
      DebugLog.map('MapCache delete region $id failed: $e');
    }
  }

  /// Total bytes held by every downloaded pack — the number to show in
  /// settings next to a "clear" control.
  static Future<int> totalCachedBytes() async {
    try {
      final all = await getListOfRegions();
      return _sumBytes(all);
    } catch (e) {
      DebugLog.map('MapCache totalCachedBytes failed: $e');
      return 0;
    }
  }

  /// Drops every downloaded region and the ambient cache with it.
  static Future<void> clearAll() async {
    try {
      await resetOfflineDatabase();
      DebugLog.map('MapCache cleared');
    } catch (e) {
      DebugLog.map('MapCache clear failed: $e');
    }
  }

  static Future<int> _bytesForPack(String packId) async {
    final regions = await regionsForPack(packId);
    return _sumBytes(regions);
  }

  static Future<int> _sumBytes(List<OfflineRegion> regions) async {
    var total = 0;
    for (final region in regions) {
      try {
        final status = await getOfflineRegionStatus(region.id);
        total += status.completedResourceSize;
      } catch (_) {
        // A region whose status can't be read just doesn't count towards
        // the total; it is not worth failing the whole tally over.
      }
    }
    return total;
  }

  static LatLngBounds _toLatLngBounds(CoordinateBounds b) => LatLngBounds(
    southwest: LatLng(b.southWest.latitude, b.southWest.longitude),
    northeast: LatLng(b.northEast.latitude, b.northEast.longitude),
  );
}
