import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/route_point.dart';

/// One row of an import, before it has been turned into a [RoutePoint].
///
/// [locator] is whatever tells us *where* the stop is — a `lat,lng` pair, a
/// map link, or a plain address for geocoding. The rest is what a CSV can
/// carry that a bare line of shared text cannot.
class ImportedStop {
  final String locator;
  final String? label;
  final String? phone;

  const ImportedStop({required this.locator, this.label, this.phone});
}

class RouteCsvUtils {
  RouteCsvUtils._();

  static const _headers = [
    'sequence',
    'label',
    'kind',
    'optional',
    'active',
    'latitude',
    'longitude',
    'address',
    'phone',
    'weight',
    // Arrival window as 24-hour wall clock, so the export stays readable
    // (and re-importable) without knowing when the trip departs.
    'arrive_from',
    'arrive_to',
  ];

  static String _clock(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String encodePoints(List<RoutePoint> points) {
    final rows = <List<dynamic>>[
      _headers,
      ...points.asMap().entries.map((entry) {
        final p = entry.value;
        return [
          p.sequence ?? entry.key,
          p.label,
          p.isDepot
              ? 'depot'
              : p.optional
              ? 'optional'
              : 'stop',
          p.optional ? 'yes' : 'no',
          p.active ? 'yes' : 'no',
          p.latitude,
          p.longitude,
          // Empty fields are written as an empty cell, never "null".
          p.address ?? '',
          // Quoted by the encoder when needed, so a leading + survives and
          // spreadsheets don't eat the number as a formula or an integer.
          p.phone ?? '',
          p.weight,
          p.timeWindow == null ? '' : _clock(p.timeWindow!.startMinuteOfDay),
          p.timeWindow == null ? '' : _clock(p.timeWindow!.endMinuteOfDay),
        ];
      }),
    ];
    // addBom embeds a UTF-8 BOM so Excel / Numbers render Arabic
    // correctly instead of mojibake (#5). \r\n line endings keep Excel
    // happy too.
    return const CsvEncoder(addBom: true).convert(rows);
  }

  /// Converts a CSV into [ImportedStop]s.
  ///
  /// Supported formats:
  /// - Header CSV with `latitude`/`longitude` (or `lat`/`lng`/`lon`).
  /// - Header CSV with `address` when coordinates are absent.
  /// - Headerless rows where the first two columns are coordinates.
  /// - Headerless rows where the first column is an address.
  ///
  /// A header row also carries `label`/`name` and `phone` through, so a stop
  /// keeps the name and contact the office typed instead of coming back as
  /// "نقطة 4" with nobody to ring.
  static List<ImportedStop> decodeImportRows(String source) {
    // Strip a leading UTF-8 BOM (present on files we exported, and on
    // many spreadsheets) so the first header cell parses cleanly.
    final clean = source.startsWith('\u{FEFF}') ? source.substring(1) : source;
    final rows = const CsvDecoder().convert(clean);
    if (rows.isEmpty) return const [];

    final header = _headerMap(rows.first);
    final hasHeader = header.isNotEmpty;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    final stops = <ImportedStop>[];
    for (final row in dataRows) {
      final locator = hasHeader
          ? _locatorFromHeaderRow(row, header)
          : _locatorFromRow(row);
      if (locator == null || locator.trim().isEmpty) continue;

      stops.add(
        ImportedStop(
          locator: locator.trim(),
          label: hasHeader ? _text(row, _labelIndex(header)) : null,
          phone: hasHeader ? _text(row, _phoneIndex(header)) : null,
        ),
      );
    }
    return stops;
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
      'phone',
      'mobile',
      'tel',
      'sequence',
      'kind',
      'weight',
      // Arabic headers, because the office builds these sheets by hand.
      'الاسم',
      'العنوان',
      'الهاتف',
      'رقم',
      'رقم الهاتف',
      'الجوال',
      'الموبايل',
    };
    if (!map.keys.any(known.contains)) return const {};
    return map;
  }

  /// The name column under any of the names a sheet might use for it.
  static int? _labelIndex(Map<String, int> header) =>
      header['label'] ?? header['name'] ?? header['الاسم'];

  /// The phone column under any of the names a sheet might use for it.
  static int? _phoneIndex(Map<String, int> header) =>
      header['phone'] ??
      header['mobile'] ??
      header['tel'] ??
      header['الهاتف'] ??
      header['رقم الهاتف'] ??
      header['رقم'] ??
      header['الجوال'] ??
      header['الموبايل'];

  /// A cell's trimmed text, or null when it is missing or blank.
  static String? _text(List<dynamic> row, int? index) {
    final raw = _value(row, index)?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  static String? _locatorFromHeaderRow(
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

    // No coordinates — fall back to something geocodable. The address
    // column first; a label is a last resort, and only because a sheet that
    // has nothing else often puts the shop name there.
    return _text(row, header['address'] ?? header['العنوان']) ??
        _text(row, _labelIndex(header));
  }

  static String? _locatorFromRow(List<dynamic> row) {
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
