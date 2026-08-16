import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../config/offline_map_config.dart';
import '../utils/distance_utils.dart';
import '../utils/tile_math.dart';
import 'map_cache_service.dart';

enum MapPackStatus {
  /// Nothing stored for this pack yet.
  idle,

  /// Checking what is already on disk.
  checking,

  /// A download is running.
  downloading,

  /// The whole pack is on disk.
  ready,

  /// Some boxes landed, some didn't — the map has holes but is still worth
  /// keeping, and re-running the download only fetches what's missing.
  partial,

  /// The driver stopped it. Distinct from [partial] because there is
  /// nothing to apologise for and nothing to retry-warn about — whatever
  /// landed is kept, and the button simply offers to carry on.
  cancelled,

  /// Nothing usable was downloaded.
  failed,
}

/// Live state of one offline map download.
///
/// Lives outside the widget tree on purpose: a download outlasts the sheet
/// or settings page that started it, so navigating away and back has to
/// find the progress still running rather than a reset bar.
///
/// There are two instances, because the two packs are independent and
/// either can be stored without the other: [area] is the map around the
/// driver, downloaded with no route in sight, and [route] is the corridor
/// along a planned trip. Clearing a plan deletes the corridor and leaves
/// the area map exactly where it was.
class MapPackController extends ChangeNotifier {
  MapPackController._({
    required String kind,
    required double minZoom,
    required double maxZoom,
  }) : _kind = kind,
       _minZoom = minZoom,
       _maxZoom = maxZoom;

  /// The route-independent "map around me" pack.
  static final MapPackController area = MapPackController._(
    kind: OfflineMapConfig.kindArea,
    minZoom: OfflineMapConfig.areaMinZoom,
    maxZoom: OfflineMapConfig.areaMaxZoom,
  );

  /// The corridor along the planned trip.
  static final MapPackController route = MapPackController._(
    kind: OfflineMapConfig.kindCorridor,
    minZoom: OfflineMapConfig.corridorMinZoom,
    maxZoom: OfflineMapConfig.corridorMaxZoom,
  );

  final String _kind;
  final double _minZoom;
  final double _maxZoom;

  MapPackStatus _status = MapPackStatus.idle;
  double _progress = 0;
  int _bytes = 0;
  int _doneBoxes = 0;
  bool _cancelling = false;
  List<CoordinateBounds> _boxes = const [];
  String? _packId;
  MapPackCancelToken? _token;

  MapPackStatus get status => _status;
  double get progress => _progress;
  int get bytes => _bytes;

  /// Which pack [status] is actually describing, or null before anything is
  /// bound. Callers that can be looking at a *different* pack — the area
  /// picker, where the driver may have panned somewhere else entirely since
  /// the last download — have to check this before believing the status.
  String? get packId => _packId;

  /// Whole percent, which is what the UI actually shows — kept here so the
  /// two screens that display it can't round it differently.
  int get percent => (_progress * 100).clamp(0, 100).round();

  /// Boxes finished so far. Paired with [boxCount] it is the honest answer
  /// to "is this thing still moving?" during a long corridor download,
  /// where megabytes only tick over once a whole box lands.
  int get doneBoxes => _doneBoxes;

  /// True between the driver pressing cancel and the download unwinding.
  bool get isCancelling => _cancelling;

  /// MB stored for this pack right now.
  double get storedMb => _bytes / 1048576;

  /// Number of boxes the bound pack needs — drives the size estimate shown
  /// before the user commits.
  int get boxCount => _boxes.length;

  bool get isBusy =>
      _status == MapPackStatus.downloading || _status == MapPackStatus.checking;

  /// Rough MB the pending download would cost, for the pre-download hint.
  double get estimatedMb =>
      TileMath.estimatedMb(_boxes, minZoom: _minZoom, maxZoom: _maxZoom);

  /// Points this controller at [packId] / [boxes] and reports whether the
  /// pack is already stored. Call whenever what would be downloaded changes.
  Future<void> bind({
    required String packId,
    required List<CoordinateBounds> boxes,
  }) async {
    // A download in flight for this very pack must not be reset by the UI
    // rebuilding underneath it.
    if (_packId == packId && isBusy) {
      _boxes = boxes;
      return;
    }

    _packId = packId;
    _boxes = boxes;
    _status = MapPackStatus.checking;
    _progress = 0;
    notifyListeners();

    final bytes = await MapCacheService.cachedBytesForPack(packId);
    if (_packId != packId) return; // superseded while awaiting

    _bytes = bytes;
    _status = bytes > 0 ? MapPackStatus.ready : MapPackStatus.idle;
    _progress = bytes > 0 ? 1 : 0;
    notifyListeners();
  }

  /// Downloads [boxes] as pack [packId]. Safe to call twice — the second
  /// call is ignored while the first is running.
  Future<void> download({
    required String packId,
    required List<CoordinateBounds> boxes,
    CoordinateBounds? packBounds,
  }) async {
    if (isBusy) return;

    _packId = packId;
    _boxes = boxes;
    _status = MapPackStatus.downloading;
    _progress = 0;
    _doneBoxes = 0;
    _bytes = 0;
    _cancelling = false;
    _token = MapPackCancelToken();
    notifyListeners();

    final result = await MapCacheService.prefetchBoxes(
      packId: packId,
      kind: _kind,
      boxes: boxes,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      packBounds: packBounds,
      cancelToken: _token,
      onProgress: (p) {
        if (_packId != packId) return;
        _progress = p.fraction;
        _bytes = p.bytes;
        _doneBoxes = p.completedChunks;
        notifyListeners();
      },
    );

    if (_packId != packId) return;

    _bytes = result.bytes;
    _doneBoxes = result.downloadedChunks;
    _progress = result.isComplete ? 1 : _progress;
    _status = result.isComplete
        ? MapPackStatus.ready
        : result.cancelled
        ? MapPackStatus.cancelled
        : result.downloadedChunks > 0
        ? MapPackStatus.partial
        : MapPackStatus.failed;
    _cancelling = false;
    _token = null;
    notifyListeners();
  }

  /// Stops the current download.
  ///
  /// Surfaces the intent immediately — the box in flight still has to
  /// unwind, and a button that goes quiet in the meantime is exactly what
  /// makes a download feel broken.
  void cancel() {
    if (_token == null || _cancelling) return;
    _cancelling = true;
    notifyListeners();
    _token?.cancel();
  }

  /// Removes the stored pack this controller is bound to.
  Future<void> delete() async {
    final packId = _packId;
    if (packId == null) return;

    _token?.cancel();
    await MapCacheService.deletePack(packId);
    if (_packId != packId) return;

    _bytes = 0;
    _progress = 0;
    _doneBoxes = 0;
    _status = MapPackStatus.idle;
    notifyListeners();
  }

  /// Puts the controller into a given visual state without touching the
  /// platform, so the download UI can be rendered and reviewed without a
  /// real download behind it.
  @visibleForTesting
  void debugSetProgress({
    required MapPackStatus status,
    double progress = 0,
    int bytes = 0,
    int doneBoxes = 0,
    int boxCount = 1,
    bool cancelling = false,
  }) {
    _status = status;
    _progress = progress;
    _bytes = bytes;
    _doneBoxes = doneBoxes;
    _cancelling = cancelling;
    _boxes = List.filled(
      boxCount,
      const CoordinateBounds(
        southWest: LatLng(0, 0),
        northEast: LatLng(0, 0),
      ),
    );
    notifyListeners();
  }

  /// Forgets the bound pack without touching what is on disk — used when
  /// the planner is cleared.
  void reset() {
    _token?.cancel();
    _packId = null;
    _status = MapPackStatus.idle;
    _progress = 0;
    _doneBoxes = 0;
    _bytes = 0;
    _boxes = const [];
    notifyListeners();
  }
}
