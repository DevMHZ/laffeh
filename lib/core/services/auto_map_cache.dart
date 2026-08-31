import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/offline_map_config.dart';
import '../di/service_locator.dart';
import '../network/network_info.dart';
import '../utils/area_grid.dart';
import '../utils/debug_log.dart';
import '../utils/distance_utils.dart';
import 'map_cache_service.dart';
import 'map_pack_controller.dart';

/// The offline map the driver never has to ask for.
///
/// Asking was the old design and it never really worked. A saved map is
/// only worth anything to someone who has *already* lost signal, and that
/// is precisely the moment they can no longer download one — so the app had
/// to raise the subject in advance, guess that today was the day it would
/// matter, and hope the answer was yes. Most of the time it was a banner in
/// the way.
///
/// So the square around the driver is simply kept, quietly, the way a
/// browser keeps a cache: [OfflineMapConfig.autoAreaEdgeKm] on a side,
/// re-centred when they drive out of it, and small enough that nobody would
/// have said no. Choosing a *bigger* map — another city, tomorrow's
/// district — is still a deliberate act, and still lives in the picker.
///
/// There is no switch for it either, and that is deliberate. A row in
/// Settings offering to turn it off is a row explaining that a background
/// download exists, which is the one way a quiet convenience turns into a
/// decision the driver has to have an opinion about. It behaves like a
/// browser cache instead: bounded, cheap, and nobody's business. Deleting
/// the app's storage clears it like anything else.
///
/// Everything here is best-effort. No caller waits on it, nothing it does
/// is reported to the driver, and every failure is silent: this is a
/// nicety layered over an app that works online, and it must never be the
/// reason something else did not happen.
class AutoMapCache {
  AutoMapCache._();

  static final MapPackController _pack = MapPackController.autoArea;

  /// When and where the last real check ran. In memory only — it exists to
  /// keep a stream of GPS fixes from turning into a stream of disk and DNS
  /// round-trips, and a fresh launch may reasonably check again.
  static DateTime? _checkedAt;
  static LatLng? _checkedFrom;

  /// Null in previews and tests, where the locator was never set up. The
  /// cache then simply cannot remember anything, which is the right
  /// degradation for something nobody is watching.
  static SharedPreferences? get _prefs =>
      sl.isRegistered<SharedPreferences>() ? sl<SharedPreferences>() : null;

  /// Makes sure there is map stored around [where], downloading a fresh
  /// square if there is not.
  ///
  /// Safe and cheap to call on every position fix — the gates below are
  /// ordered from free to expensive, so the common case (a driver who has
  /// not moved) costs two comparisons.
  static Future<void> ensureAround(LatLng where) async {
    // Nowhere to remember the last attempt means no throttle, and no
    // throttle means re-deciding this from scratch on every position fix —
    // which is how a quiet cache becomes a data leak. Also the honest
    // answer in a preview or a test, where there is no platform to store
    // tiles on either.
    if (_prefs == null) return;

    // Never compete with a download the driver started and is watching, or
    // with one of our own already in flight.
    if (_pack.isBusy ||
        MapPackController.area.isBusy ||
        MapPackController.route.isBusy) {
      return;
    }

    final now = DateTime.now();
    if (_checkedRecently(now, where)) return;
    _checkedAt = now;
    _checkedFrom = where;

    // Data floor, remembered across launches.
    if (!isDue(
      now: now,
      lastAttemptAt: _lastAttemptAt,
      lastAttemptCentre: _lastAttemptCentre,
      where: where,
    )) {
      return;
    }

    // Already standing on stored map? Read from the regions themselves, and
    // from *every* saved area rather than only our own: a driver who framed
    // and downloaded their city by hand must never be charged for a second
    // copy of it.
    final saved = await MapCacheService.savedAreas(includeAutomatic: true);
    if (saved.any(
      (area) => AreaGrid.containsWithMargin(
        area.bounds,
        where,
        marginFraction: OfflineMapConfig.autoAreaCoveredMargin,
      ),
    )) {
      DebugLog.map('AutoMapCache: already covered, nothing to download');
      return;
    }

    if (!await NetworkInfo().isConnected) return;

    final square = AreaGrid.squareAround(
      where,
      radiusKm: OfflineMapConfig.autoAreaHalfEdgeKm,
    );
    final boxes = AreaGrid.cover(
      square,
      cellKm: OfflineMapConfig.autoAreaCellKm,
    );
    if (boxes.isEmpty) return;

    // Stamped before the download, not after: a run that dies halfway has
    // still spent the driver's data, and must wait its turn like any other.
    await _stamp(now, where);

    DebugLog.map(
      'AutoMapCache ▶ ${OfflineMapConfig.autoAreaEdgeKm.toStringAsFixed(0)}km '
      'square around ${where.latitude.toStringAsFixed(4)},'
      '${where.longitude.toStringAsFixed(4)} in ${boxes.length} cells',
    );

    await _pack.download(
      packId: OfflineMapConfig.autoAreaPackId,
      boxes: boxes,
      packBounds: square,
    );

    DebugLog.map(
      'AutoMapCache ⏹ ${_pack.status.name} '
      '${_pack.storedMb.toStringAsFixed(1)} MB',
    );
  }

  /// The free gate: a fix that arrives seconds after the last one, from
  /// metres away, cannot have changed the answer.
  static bool _checkedRecently(DateTime now, LatLng where) {
    final at = _checkedAt;
    final from = _checkedFrom;
    if (at == null || from == null) return false;
    return now.difference(at) < OfflineMapConfig.autoAreaCheckInterval &&
        DistanceUtils.haversineKm(from, where) <
            OfflineMapConfig.autoAreaCheckMoveKm;
  }

  /// Whether the automatic square may spend data again.
  ///
  /// Three rules, in order of who they protect:
  ///
  ///   1. **Never within [OfflineMapConfig.autoAreaFloorInterval]**, however
  ///      far the driver has gone. This is what keeps a long trip from
  ///      buying a new square every twenty minutes.
  ///   2. After [OfflineMapConfig.autoAreaMinInterval], always — a stale
  ///      square is eventually worth replacing wherever the driver is.
  ///   3. In between, only if they have moved far enough that the stored
  ///      square is no longer really *around* them.
  ///
  /// Time alone would strand a driver who crossed a province an hour after
  /// launch; distance alone would let a failing download retry all
  /// afternoon from the same car park. Both are needed, and the floor above
  /// them is what makes the pair safe to spend money on.
  ///
  /// Pure and public so the rule can be read and tested on its own — it is
  /// the one thing here that decides whether someone's data gets spent.
  static bool isDue({
    required DateTime now,
    required DateTime? lastAttemptAt,
    required LatLng? lastAttemptCentre,
    required LatLng where,
  }) {
    if (lastAttemptAt == null || lastAttemptCentre == null) return true;

    final since = now.difference(lastAttemptAt);
    if (since < OfflineMapConfig.autoAreaFloorInterval) return false;
    if (since >= OfflineMapConfig.autoAreaMinInterval) return true;

    return DistanceUtils.haversineKm(lastAttemptCentre, where) >=
        OfflineMapConfig.autoAreaHalfEdgeKm *
            OfflineMapConfig.autoAreaRefreshFraction;
  }

  // ── What survives a restart ──────────────────────────────

  static DateTime? get _lastAttemptAt {
    final raw = _prefs?.getInt(OfflineMapConfig.autoAreaStampKey);
    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  static LatLng? get _lastAttemptCentre {
    final raw = _prefs?.getString(OfflineMapConfig.autoAreaCentreKey);
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  static Future<void> _stamp(DateTime at, LatLng centre) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setInt(
      OfflineMapConfig.autoAreaStampKey,
      at.millisecondsSinceEpoch,
    );
    await prefs.setString(
      OfflineMapConfig.autoAreaCentreKey,
      '${centre.latitude},${centre.longitude}',
    );
  }
}
