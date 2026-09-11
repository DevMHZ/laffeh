import 'package:latlong2/latlong.dart';

import '../widgets/map_geometry.dart';
import '../../../../core/utils/polyline_utils.dart';

/// One native-map update owns both the vehicle and the line meeting it.
/// Camera position is deliberately absent: panning must never move the
/// vehicle's geographic location or the completed-route boundary.
class RouteMotionFrame {
  static Map<String, dynamic> build({
    required List<LatLng> path,
    required double progress,
    required String image,
    required double imageScale,
    required double rotation,
    double? nextStop,
    LatLng? fallbackPosition,
  }) {
    final p = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final anchor =
        PolylineUtils.interpolateByLength(path, p) ?? fallbackPosition;
    if (anchor == null) return MapGeometry.emptyGeoJson;
    final features = <Map<String, dynamic>>[];
    void line(String role, List<LatLng> points) {
      if (points.length < 2) return;
      features.add({
        'type': 'Feature',
        'properties': {'role': role},
        'geometry': {
          'type': 'LineString',
          'coordinates': points
              .map((point) => [point.longitude, point.latitude])
              .toList(),
        },
      });
    }

    // Explicitly use the same anchor object for every joining endpoint,
    // including duplicate vertices, a scrub backwards and the trip ends.
    final done = MapGeometry.subPath(path, 0, p);
    if (done.isNotEmpty) done[done.length - 1] = anchor;
    if (nextStop == null) {
      line('trail', done);
    } else {
      line('done', done);
      final current = MapGeometry.subPath(path, p, nextStop.clamp(p, 1.0));
      if (current.isNotEmpty) current[0] = anchor;
      line('trail', current);
    }
    features.add({
      'type': 'Feature',
      'properties': {
        'role': 'vehicle',
        'image': image,
        'scale': imageScale,
        'rotation': rotation,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [anchor.longitude, anchor.latitude],
      },
    });
    return {'type': 'FeatureCollection', 'features': features};
  }
}

/// Serializes native writes and coalesces queued frames. A clear on exit is
/// queued through the same writer, so an old in-flight frame cannot put a
/// vehicle back after the preview has ended.
class LatestFrameWriter<T extends Object> {
  final Future<void> Function(T) write;
  final void Function(Object, StackTrace)? onError;
  T? _pending;
  bool _busy = false;
  bool _disposed = false;

  LatestFrameWriter(this.write, {this.onError});

  void submit(T frame) {
    if (_disposed) return;
    _pending = frame;
    if (!_busy) _drain();
  }

  Future<void> _drain() async {
    _busy = true;
    try {
      while (!_disposed && _pending != null) {
        final frame = _pending!;
        _pending = null;
        try {
          await write(frame);
        } catch (error, stack) {
          onError?.call(error, stack);
        }
      }
    } finally {
      _busy = false;
    }
  }

  /// Drop obsolete queued work when a user changes camera mode or exits.
  /// The in-flight native operation may finish, but cannot replay old targets.
  void discardPending() => _pending = null;

  void dispose() {
    _disposed = true;
    _pending = null;
  }
}
