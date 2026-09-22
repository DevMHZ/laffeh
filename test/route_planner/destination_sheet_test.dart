import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/destination_card.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/sheet_extent.dart';

const _destination = RoutePoint(
  id: 'destination',
  latitude: 35.826,
  longitude: 10.638,
  label: 'Destination',
  address: 'نهج فلسطين، سوسة',
  weight: 1,
  kind: RoutePointKind.stop,
);

const _route = OptimizedRoute(
  orderedPoints: [_destination],
  fullPolyline: [],
  goPolyline: [],
  returnPolyline: [],
  hasRoadGeometry: true,
  metrics: RouteMetrics(totalDistanceKm: 3.7, estimatedDurationMinutes: 4),
);

Widget _screen({
  required ValueNotifier<double> extent,
  RoutePoint destination = _destination,
  bool routing = false,
  bool starting = false,
  bool showCard = true,
  double textScale = 1,
  VoidCallback? onGo,
  VoidCallback? onAdd,
}) => MaterialApp(
  theme: AppTheme.data,
  home: Directionality(
    textDirection: AppStrings.isArabic ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          padding: const EdgeInsets.only(top: 24, bottom: 34),
          textScaler: TextScaler.linear(textScale),
        ),
        child: SheetExtent(
          extent: extent,
          child: showCard
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: DestinationCard(
                    destination: destination,
                    route: _route,
                    routing: routing,
                    starting: starting,
                    onGo: onGo ?? () {},
                    onAddAnotherStop: onAdd ?? () {},
                    onChangeDestination: () {},
                    onChangeDeparture: () {},
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  ),
);

final _handle = find.byKey(const ValueKey('destination-sheet-handle'));
final _surface = find.byKey(const ValueKey('destination-sheet-surface'));

void main() {
  setUp(() => AppStrings.setLocale(const Locale('en')));
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  Future<void> phone(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final locale in ['en', 'ar', 'fr']) {
    testWidgets('pending GPS disables Go at either sheet snap ($locale)', (
      tester,
    ) async {
      AppStrings.setLocale(Locale(locale));
      await phone(tester);
      final extent = ValueNotifier<double>(0);
      var goCount = 0;
      await tester.pumpWidget(
        _screen(extent: extent, starting: true, onGo: () => goCount++),
      );
      await tester.pump();

      expect(find.text(AppStrings.navigationStarting), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text(AppStrings.navigationStarting));
      expect(goCount, 0);

      await tester.tap(_handle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.navigationStartingShort), findsOneWidget);
      await tester.tap(find.text(AppStrings.navigationStartingShort));
      expect(goCount, 0);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_screen(extent: extent, onGo: () => goCount++));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text(AppStrings.goNow));
      expect(goCount, 1, reason: 'A failed GPS attempt leaves Go retryable.');
      await tester.pumpWidget(const SizedBox.shrink());
      extent.dispose();
    });
  }

  testWidgets('drag closes and reopens details while Go remains usable', (
    tester,
  ) async {
    await phone(tester);
    final extent = ValueNotifier<double>(0);
    var goCount = 0;
    await tester.pumpWidget(_screen(extent: extent, onGo: () => goCount++));
    await tester.pumpAndSettle();
    final expanded = tester.getSize(_surface).height;
    expect(extent.value, closeTo(expanded / 844, 0.001));

    final drag = await tester.startGesture(tester.getCenter(_handle));
    await drag.moveBy(const Offset(0, 20));
    await drag.moveBy(const Offset(0, 80));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final duringDrag = tester.getSize(_surface).height;
    expect(duringDrag, lessThan(expanded));
    expect(
      extent.value,
      closeTo(duringDrag / 844, 0.001),
      reason: 'Map controls follow the visible sheet during the gesture.',
    );
    await drag.moveBy(const Offset(0, 180));
    await drag.up();
    await tester.pumpAndSettle();

    final collapsed = tester.getSize(_surface).height;
    expect(collapsed, lessThan(expanded - 100));
    expect(find.text(AppStrings.addAnotherStop).hitTestable(), findsNothing);
    expect(find.text(_destination.address!).hitTestable(), findsOneWidget);
    expect(find.text(AppStrings.goNow).hitTestable(), findsOneWidget);
    await tester.tap(find.text(AppStrings.goNow));
    expect(goCount, 1);

    await tester.drag(_handle, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.getSize(_surface).height, closeTo(expanded, 0.1));
    expect(find.text(AppStrings.addAnotherStop).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tap toggles accessibly and route refresh keeps the chosen snap',
    (tester) async {
      await phone(tester);
      final extent = ValueNotifier<double>(0);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(_screen(extent: extent));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_handle),
        matchesSemantics(
          label: AppStrings.collapseTripDetails,
          isButton: true,
          hasTapAction: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      await tester.tap(_handle);
      await tester.pumpAndSettle();
      final collapsed = tester.getSize(_surface).height;
      expect(tester.getSemantics(_handle).label, AppStrings.expandTripDetails);

      await tester.pumpWidget(_screen(extent: extent, routing: true));
      await tester.pumpAndSettle();
      expect(tester.getSize(_surface).height, collapsed);

      await tester.tap(_handle);
      await tester.pumpAndSettle();
      expect(tester.getSize(_surface).height, greaterThan(collapsed));
      semantics.dispose();
    },
  );

  testWidgets(
    'short RTL screen and large text keep Go and scrollable details reachable',
    (tester) async {
      await phone(tester, size: const Size(320, 380));
      AppStrings.setLocale(const Locale('ar'));
      final extent = ValueNotifier<double>(0);
      var addCount = 0;
      await tester.pumpWidget(
        _screen(extent: extent, textScale: 2, onAdd: () => addCount++),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.goNow).hitTestable(), findsOneWidget);
      expect(_handle.hitTestable(), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.addAnotherStop));
      expect(addCount, 1);

      await tester.tap(_handle);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.goNow).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving the destination card clears its map obstruction', (
    tester,
  ) async {
    await phone(tester);
    final extent = ValueNotifier<double>(0);
    await tester.pumpWidget(_screen(extent: extent));
    await tester.pumpAndSettle();
    expect(extent.value, greaterThan(0));
    await tester.pumpWidget(_screen(extent: extent, showCard: false));
    await tester.pumpAndSettle();
    expect(extent.value, 0);
    // A fresh card still must publish its own size rather than inherit a snap.
    await tester.pumpWidget(_screen(extent: extent));
    await tester.pumpAndSettle();
    expect(extent.value, closeTo(tester.getSize(_surface).height / 844, 0.001));
  });
}
