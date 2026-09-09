/// The "To ·" row on the planner sheet names where the day ends.
///
/// It went on saying "Back to the start" after a different ending was picked.
/// The state was right; nothing rebuilt. Neither the sheet host nor the points
/// sheet listed `finish` in its buildWhen, so the row kept whatever label it
/// happened to be built with — a bug that no amount of reading the row itself
/// would have found, because the row was correct.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_finish.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_points_sheet.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

class _FakeGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  final _controller = StreamController<Position>.broadcast();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      _controller.stream;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  Future<void> dispose() => _controller.close();
}

RoutePoint _pt(String id, double lat, double lon, {bool depot = false}) =>
    RoutePoint(
      id: id,
      latitude: lat,
      longitude: lon,
      label: id,
      weight: 1,
      kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGeolocator geo;
  late RoutePlannerCubit cubit;

  setUpAll(() => registerFallbackValue(_FakeDraft()));

  setUp(() {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;

    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    when(() => draft.clear()).thenAnswer((_) async {});

    final network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);

    cubit = RoutePlannerCubit(
      _MockOptimize(),
      _MockSavedRoutes(),
      _MockGeocoding(),
      _MockPlaces(),
      draft,
      network,
      _MockRouting(),
    );
    cubit.emit(
      cubit.state.copyWith(
        points: [
          _pt('depot', 25.20, 55.27, depot: true),
          _pt('a', 25.21, 55.28),
          _pt('b', 25.22, 55.29),
        ],
      ),
    );
  });

  tearDown(() async {
    await geo.dispose();
    await cubit.close();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const SingleChildScrollView(child: RoutePointsSheet()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('starts out saying the round trip goes back to the start', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.text(AppStrings.finishRoundTrip), findsOneWidget);
  });

  testWidgets('follows a switch to an open route', (tester) async {
    await pumpSheet(tester);
    expect(find.text(AppStrings.finishRoundTrip), findsOneWidget);

    await cubit.setRouteFinish(const RouteFinish.open());
    await tester.pump();

    expect(
      find.text(AppStrings.finishRoundTrip),
      findsNothing,
      reason: 'the row kept the old ending',
    );
    expect(find.text(AppStrings.finishOpen), findsOneWidget);
  });

  testWidgets('follows a switch to a place of the driver\'s own', (
    tester,
  ) async {
    await pumpSheet(tester);

    await cubit.setRouteFinish(
      RouteFinish.at(const LatLng(25.30, 55.30), label: 'Home'),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text(AppStrings.finishRoundTrip), findsNothing);
  });

  testWidgets('and back again', (tester) async {
    await pumpSheet(tester);

    await cubit.setRouteFinish(const RouteFinish.open());
    await tester.pump();
    expect(find.text(AppStrings.finishOpen), findsOneWidget);

    await cubit.setRouteFinish(const RouteFinish.depot());
    await tester.pump();
    expect(find.text(AppStrings.finishRoundTrip), findsOneWidget);
  });

  testWidgets(
    'a custom ending with nowhere to go still reads as a round trip',
    (tester) async {
      // effectiveMode falls back to depot when a custom finish has no place
      // yet, because that is what the solver will actually do with it. The row
      // has to say the same thing, or it promises an ending that will not
      // happen.
      await pumpSheet(tester);

      final incomplete = RouteFinish.fromJson({'mode': 'custom'});
      await cubit.setRouteFinish(incomplete ?? const RouteFinish.depot());
      await tester.pump();

      expect(find.text(AppStrings.finishRoundTrip), findsOneWidget);
    },
  );
}
