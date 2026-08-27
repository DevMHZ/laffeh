import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/utils/route_csv_utils.dart';

RoutePoint _stop({
  required String id,
  required String label,
  String? phone,
  String? address,
}) => RoutePoint(
  id: id,
  latitude: 33.5131,
  longitude: 36.2767,
  label: label,
  address: address,
  phone: phone,
  weight: 1,
  kind: RoutePointKind.stop,
);

void main() {
  group('export', () {
    test('writes a phone column, and an empty cell when there is none', () {
      final csv = RouteCsvUtils.encodePoints([
        _stop(id: 'a', label: 'مخبز الشام', phone: '+963944123456'),
        _stop(id: 'b', label: 'نقطة 2'),
      ]);

      expect(csv, contains('phone'));
      expect(csv, contains('+963944123456'));
      // The stop without a number must not export the word "null".
      expect(csv, isNot(contains('null')));
    });
  });

  group('import', () {
    test('carries the name and phone off a header row', () {
      final stops = RouteCsvUtils.decodeImportRows(
        'label,latitude,longitude,phone\n'
        'مخبز الشام,33.5131,36.2767,+963944123456\n',
      );

      expect(stops, hasLength(1));
      expect(stops.single.locator, '33.5131,36.2767');
      expect(stops.single.label, 'مخبز الشام');
      expect(stops.single.phone, '+963944123456');
    });

    test('reads the Arabic headers an office actually types', () {
      final stops = RouteCsvUtils.decodeImportRows(
        'الاسم,العنوان,رقم الهاتف\n'
        'صيدلية النور,شارع بغداد دمشق,0944123456\n',
      );

      expect(stops.single.label, 'صيدلية النور');
      expect(stops.single.locator, 'شارع بغداد دمشق');
      expect(stops.single.phone, '0944123456');
    });

    test('a blank phone cell imports as no phone, not an empty string', () {
      final stops = RouteCsvUtils.decodeImportRows(
        'label,latitude,longitude,phone\n'
        'نقطة 1,33.5,36.3,\n',
      );

      expect(stops.single.phone, isNull);
    });

    test('a headerless sheet still imports, just without the extras', () {
      final stops = RouteCsvUtils.decodeImportRows('33.5131,36.2767\n');

      expect(stops.single.locator, '33.5131,36.2767');
      expect(stops.single.label, isNull);
      expect(stops.single.phone, isNull);
    });

    test('rows with nothing to locate are dropped', () {
      final stops = RouteCsvUtils.decodeImportRows(
        'label,latitude,longitude,phone\n'
        ',,,\n'
        'نقطة 1,33.5,36.3,0944\n',
      );

      expect(stops, hasLength(1));
      expect(stops.single.label, 'نقطة 1');
    });
  });

  test('a route survives an export/import round trip with its contacts', () {
    final csv = RouteCsvUtils.encodePoints([
      _stop(
        id: 'a',
        label: 'مخبز الشام',
        phone: '+963944123456',
        address: 'شارع الباسل',
      ),
      _stop(id: 'b', label: 'صيدلية النور', phone: '0944999888'),
    ]);

    final stops = RouteCsvUtils.decodeImportRows(csv);

    expect(stops.map((s) => s.label), ['مخبز الشام', 'صيدلية النور']);
    expect(stops.map((s) => s.phone), ['+963944123456', '0944999888']);
    // Coordinates win over the address column, so the re-import lands on the
    // exact same spot instead of re-geocoding a street name.
    expect(stops.first.locator, '33.5131,36.2767');
  });
}
