import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../domain/entities/route_finish.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/stop_time_window.dart';

/// The version of the `.laffa` format this build understands.
///
/// A file declaring a higher number is refused by name rather than parsed
/// optimistically — a driver told "this round needs a newer Laffa" can act
/// on that, where a round silently missing half its stops is a bad day.
const int kLaffaFormatVersion = 1;

/// Raised when a file is not a `.laffa` round we can open.
///
/// Carries a message written for the driver holding the phone, not for a
/// log: it is shown to them directly.
class LaffaFormatException implements Exception {
  final String message;
  const LaffaFormatException(this.message);

  @override
  String toString() => message;
}

/// A round exported by the Laffa console — the stops, in order, with what
/// the driver needs at the door.
///
/// See LAFFA_FILE_FORMAT.md in the backend repository for the wire format.
/// Deliberately carries no road geometry: the phone recomputes the path with
/// its own router, which may have newer map data than the console had.
class LaffaFile {
  final int version;
  final String? tripName;
  final int? vehicleId;
  final RouteFinish finish;
  final List<RoutePoint> points;

  /// Free text from the file, keyed by point id — phone numbers and remarks
  /// the console carried through from the original order.
  final Map<String, String> remarks;

  const LaffaFile({
    required this.version,
    required this.tripName,
    required this.vehicleId,
    required this.finish,
    required this.points,
    required this.remarks,
  });

  /// Parse [raw] file contents.
  ///
  /// Throws [LaffaFormatException] with something worth showing the driver
  /// for every rejection path.
  static LaffaFile parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const LaffaFormatException(
        'This file is damaged and could not be read.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const LaffaFormatException('This is not a Laffa route file.');
    }

    final version = decoded['laffa'];
    if (version is! int) {
      throw const LaffaFormatException('This is not a Laffa route file.');
    }
    if (version > kLaffaFormatVersion) {
      throw LaffaFormatException(
        'This round was made with a newer version of Laffa (format $version). '
        'Update the app to open it.',
      );
    }

    final rawStops = decoded['stops'];
    if (rawStops is! List || rawStops.isEmpty) {
      throw const LaffaFormatException('This round has no stops in it.');
    }

    final points = <RoutePoint>[];
    final remarks = <String, String>{};
    var sequence = 0;

    for (final entry in rawStops) {
      if (entry is! Map) continue;
      final lat = _asDouble(entry['lat']);
      final lon = _asDouble(entry['lon']);
      // A stop without coordinates cannot be driven to. Skip it rather than
      // failing the whole round — one bad row should not cost the other
      // forty-nine.
      if (lat == null || lon == null) continue;
      if (lat.abs() > 90 || lon.abs() > 180) continue;

      final kind = (entry['kind'] ?? 'delivery').toString();
      // The finish terminal is handled separately below; it is where the day
      // ends, not somewhere to deliver.
      if (kind == 'finish') continue;

      final isDepot = kind == 'depot' && sequence == 0;
      final id = 'laffa_${sequence}_${DateTime.now().microsecondsSinceEpoch}';

      points.add(
        RoutePoint(
          id: id,
          latitude: lat,
          longitude: lon,
          label: _asText(entry['label']) ?? 'Stop ${points.length}',
          address: _asText(entry['address']),
          phone: _asText(entry['phone']),
          weight: _asInt(entry['weight']) ?? 1,
          kind: isDepot ? RoutePointKind.depot : RoutePointKind.stop,
          timeWindow: _windowFrom(entry['window']),
        ),
      );

      final note = _asText(entry['remarks']);
      if (note != null) remarks[id] = note;
      sequence++;
    }

    if (points.length < 2) {
      throw const LaffaFormatException(
        'This round needs a start and at least one stop.',
      );
    }

    final trip = decoded['trip'];
    return LaffaFile(
      version: version,
      tripName: trip is Map ? _asText(trip['name']) : null,
      vehicleId: trip is Map ? _asInt(trip['vehicle_id']) : null,
      finish: _finishFrom(decoded['finish']),
      points: points,
      remarks: remarks,
    );
  }

  // ── field readers ──────────────────────────────────────────────────────
  //
  // Every one of these tolerates a missing or wrongly-typed value. A file
  // that has travelled through an email client and a file manager is not
  // something to trust the shape of.

  static RouteFinish _finishFrom(Object? raw) {
    if (raw is! Map) return const RouteFinish.depot();
    switch ((raw['mode'] ?? 'depot').toString()) {
      case 'open':
        return const RouteFinish.open();
      case 'custom':
        final lat = _asDouble(raw['lat']);
        final lon = _asDouble(raw['lon']);
        if (lat == null || lon == null) return const RouteFinish.depot();
        return RouteFinish.at(LatLng(lat, lon), label: _asText(raw['label']));
      default:
        return const RouteFinish.depot();
    }
  }

  static StopTimeWindow? _windowFrom(Object? raw) {
    if (raw is! Map) return null;
    final start = _asInt(raw['start']);
    final end = _asInt(raw['end']);
    if (start == null || end == null) return null;
    // Minutes from midnight, the frame the file documents. A window is
    // allowed to wrap past midnight, so end < start is legal — only an
    // out-of-range value or a zero-length window is rejected.
    if (start < 0 || start >= StopTimeWindow.minutesPerDay) return null;
    if (end < 0 || end >= StopTimeWindow.minutesPerDay) return null;
    if (end == start) return null;
    return StopTimeWindow(startMinuteOfDay: start, endMinuteOfDay: end);
  }

  static double? _asDouble(Object? v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  static int? _asInt(Object? v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  /// Trimmed text, or null for anything empty.
  ///
  /// Values here came from a file someone was emailed. They are displayed
  /// and never used to build a URL or a shell argument without escaping at
  /// the point of use.
  static String? _asText(Object? v) {
    if (v == null) return null;
    final text = v.toString().trim();
    return text.isEmpty ? null : text;
  }
}
