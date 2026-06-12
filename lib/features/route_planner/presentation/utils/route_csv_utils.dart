import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/route_point.dart';

class RouteCsvUtils {
  RouteCsvUtils._();

  static const _headers = [
    'sequence',
    'label',
    'kind',
    'latitude',
    'longitude',
    'address',
    'weight',
  ];

  static String encodePoints(List<RoutePoint> points) {
    final rows = <List<dynamic>>[
      _headers,
      ...points.asMap().entries.map((entry) {
        final p = entry.value;
        return [
          p.sequence ?? entry.key,
          p.label,
          p.isDepot ? 'depot' : 'stop',
          p.latitude,
          p.longitude,
          p.address ?? '',
          p.weight,
        ];
      }),
    ];
    return const CsvEncoder().convert(rows);
  }

  /// Converts a CSV into importable lines accepted by
  /// `RoutePlannerCubit.addPointsFromText`.
  ///
  /// Supported formats:
  /// - Header CSV with `latitude`/`longitude` (or `lat`/`lng`/`lon`).
  /// - Header CSV with `address` when coordinates are absent.
  /// - Headerless rows where the first two columns are coordinates.
  /// - Headerless rows where the first column is an address.
  static List<String> decodeImportLines(String source) {
    final rows = const CsvDecoder().convert(source);
    if (rows.isEmpty) return const [];

    final header = _headerMap(rows.first);
    final hasHeader = header.isNotEmpty;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    final lines = <String>[];
    for (final row in dataRows) {
      final line = hasHeader
          ? _lineFromHeaderRow(row, header)
          : _lineFromRow(row);
      if (line != null && line.trim().isNotEmpty) lines.add(line.trim());
    }
    return lines;
  }

  static List<RoutePoint> stripReturnDuplicate(List<RoutePoint> points) {
    if (points.length < 2) return points;
    final first = points.first;
    final last = points.last;
    if (first.latitude == last.latitude && first.longitude == last.longitude) {
      return points.sublist(0, points.length - 1);
    }
    return points;
  }

  static Map<String, int> _headerMap(List<dynamic> row) {
    final map = <String, int>{};
    for (var i = 0; i < row.length; i++) {
      final key = row[i].toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      map[key] = i;
    }

    final known = {
      'lat',
      'latitude',
      'lng',
      'lon',
      'longitude',
      'address',
      'label',
      'name',
      'sequence',
      'kind',
      'weight',
    };
    if (!map.keys.any(known.contains)) return const {};
    return map;
  }

  static String? _lineFromHeaderRow(
    List<dynamic> row,
    Map<String, int> header,
  ) {
    final lat = _value(row, header['latitude'] ?? header['lat']);
    final lng = _value(
      row,
      header['longitude'] ?? header['lng'] ?? header['lon'],
    );
    final parsed = _parsePair(lat, lng);
    if (parsed != null) return '${parsed.latitude},${parsed.longitude}';

    final address = _value(
      row,
      header['address'] ?? header['label'] ?? header['name'],
    );
    return address?.trim().isNotEmpty == true ? address!.trim() : null;
  }

  static String? _lineFromRow(List<dynamic> row) {
    if (row.isEmpty) return null;
    if (row.length >= 2) {
      final parsed = _parsePair(row[0].toString(), row[1].toString());
      if (parsed != null) return '${parsed.latitude},${parsed.longitude}';
    }
    final first = row.first.toString().trim();
    return first.isEmpty ? null : first;
  }

  static String? _value(List<dynamic> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return row[index].toString();
  }

  static LatLng? _parsePair(String? latRaw, String? lngRaw) {
    if (latRaw == null || lngRaw == null) return null;
    final lat = double.tryParse(latRaw.trim());
    final lng = double.tryParse(lngRaw.trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }
}
