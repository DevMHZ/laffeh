import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../../core/utils/distance_utils.dart';

/// Arc-length geometry prepared once for a route's moving vehicle and trail.
///
/// Frame sampling only searches the cached distances and interpolates between
/// two vertices. Sub-paths copy their visible vertices without recalculating
/// the entire route's distances or bearings on every display frame.
class RouteMotionPath {
  RouteMotionPath(List<LatLng> path) : _path = List.unmodifiable(path) {
    _cumulative = List<double>.filled(_path.length, 0);
    _lengths = List<double>.filled(math.max(0, _path.length - 1), 0);
    _bearings = List<double>.filled(_lengths.length, 0);
    for (var i = 0; i < _lengths.length; i++) {
      final start = _path[i];
      final end = _path[i + 1];
      final length = DistanceUtils.haversineKm(start, end);
      _lengths[i] = length;
      _cumulative[i + 1] = _cumulative[i] + length;
      _bearings[i] = _bearing(start, end);
    }
  }

  final List<LatLng> _path;
  late final List<double> _cumulative;
  late final List<double> _lengths;
  late final List<double> _bearings;

  double get _total => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// Position and incoming segment bearing at an arc-length fraction.
  ///
  /// Choosing the first segment whose end reaches the target preserves the
  /// existing heading at exact corners, including repeated route vertices.
  ({LatLng point, double bearing})? sampleAt(double progress) {
    if (_path.isEmpty) return null;
    if (_path.length == 1 || _total <= 0) {
      return (point: _path.first, bearing: 0);
    }

    final distance = _total * progress.clamp(0.0, 1.0);
    final segment = _boundary(distance, inclusive: true) - 1;
    final length = _lengths[segment];
    final fraction = length == 0
        ? 0.0
        : (distance - _cumulative[segment]) / length;
    final start = _path[segment];
    final end = _path[segment + 1];
    return (
      point: LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      ),
      bearing: _bearings[segment],
    );
  }

  /// Ordered vertices between two arc-length fractions, with exact endpoints.
  /// Empty, zero-length and backwards ranges do not produce a line.
  List<LatLng> subPath(double start, double end) {
    if (_path.length < 2 || _total <= 0) return const [];
    final from = start.clamp(0.0, 1.0);
    final to = end.clamp(0.0, 1.0);
    if (to <= from) return const [];

    final firstVertex = _boundary(_total * from, inclusive: false);
    final endVertex = _boundary(_total * to, inclusive: true);
    return [
      sampleAt(from)!.point,
      for (var i = firstVertex; i < endVertex; i++) _path[i],
      sampleAt(to)!.point,
    ];
  }

  /// Finds a segment endpoint at or beyond [distance], or strictly beyond it.
  /// Searching endpoints (index >= 1) also handles an initial duplicate vertex.
  int _boundary(double distance, {required bool inclusive}) {
    var low = 1;
    var high = _cumulative.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      final before = inclusive
          ? _cumulative[middle] < distance
          : _cumulative[middle] <= distance;
      if (before) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  static double _bearing(LatLng start, LatLng end) {
    const radiansPerDegree = 0.017453292519943295;
    const degreesPerRadian = 57.29577951308232;
    final lat1 = start.latitude * radiansPerDegree;
    final lat2 = end.latitude * radiansPerDegree;
    final longitudeDelta = (end.longitude - start.longitude) * radiansPerDegree;
    final y = math.sin(longitudeDelta) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(longitudeDelta);
    return (math.atan2(y, x) * degreesPerRadian + 360) % 360;
  }
}
