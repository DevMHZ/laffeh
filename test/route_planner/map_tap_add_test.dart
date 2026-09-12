import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/place_suggestion.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_map_view.dart';

class _Planner extends Cubit<RoutePlannerState> implements RoutePlannerCubit {
  _Planner(super.initialState);
  final added = <LatLng>[];
  final addresses = <String?>[];
  @override
  LatLng? get searchAnchor => null;
  @override
  bool get debugDriveSimActive => false;
  @override
  Future<void> rememberPlace(PlaceSuggestion place) async {}
  @override
  Future<RoutePoint?> addPoint(
    LatLng position, {
    bool optional = false,
    String? address,
    String? label,
    String? phone,
  }) async {
    added.add(position);
    addresses.add(address);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() {
    AppStrings.setLocale(const Locale('en'));
    dotenv.loadFromString(envString: 'AI_ROUTE_BASE_URL=https://example.com');
  });

  Future<_Planner> mount(WidgetTester tester, RoutePlannerState state) async {
    final cubit = _Planner(state);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: BlocProvider<RoutePlannerCubit>.value(
          value: cubit,
          child: const Scaffold(body: RouteMapView()),
        ),
      ),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets('first tap on unlabeled map offers the exact point, once', (
    tester,
  ) async {
    final cubit = await mount(tester, const RoutePlannerState());
    final map = tester.widget<ml.MapLibreMap>(find.byType(ml.MapLibreMap));
    // Native map callback before any label layers are available, as on the
    // first map load or an offline map. No POI is necessary to add a stop.
    map.onMapClick!(
      const math.Point(100.0, 120.0),
      const ml.LatLng(33.887, 35.509),
    );
    map.onMapClick!(
      const math.Point(130.0, 140.0),
      const ml.LatLng(33.888, 35.510),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dropped pin'), findsOneWidget);
    expect(find.text('33.88700, 35.50900'), findsOneWidget);
    expect(find.text('Add as a stop'), findsOneWidget);
    await tester.tap(find.text('Add as a stop'));
    await tester.pumpAndSettle();
    expect(cubit.added, hasLength(1));
    expect(cubit.added.single.latitude, closeTo(33.887, 1e-9));
    expect(cubit.added.single.longitude, closeTo(35.509, 1e-9));
    expect(
      cubit.addresses,
      [null],
      reason: 'reverse geocoding can supply an address, not "Dropped pin"',
    );
    map.onMapClick!(
      const math.Point(100.0, 120.0),
      const ml.LatLng(33.889, 35.512),
    );
    await tester.pumpAndSettle();
    expect(find.text('33.88900, 35.51200'), findsOneWidget);
  });

  testWidgets('drive, preview, move and manual placement keep their gestures', (
    tester,
  ) async {
    for (final state in [
      const RoutePlannerState(navigationActive: true),
      const RoutePlannerState(simulationActive: true),
      const RoutePlannerState(manualPlacement: true),
      const RoutePlannerState(movingPointId: 'existing'),
    ]) {
      await mount(tester, state);
      tester.widget<ml.MapLibreMap>(find.byType(ml.MapLibreMap)).onMapClick!(
        const math.Point(100.0, 120.0),
        const ml.LatLng(33.887, 35.509),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Add as a stop'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
