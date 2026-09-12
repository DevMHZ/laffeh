import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

const poi =
    'https://www.google.com/maps/place/Cafe+Beirut/'
    '@33.889,35.50,16z/data=!8m2!3d33.89!4d35.51';

void main() {
  late RoutePlannerCubit cubit;
  late _MockPlaces places;
  setUpAll(() => registerFallbackValue(_FakeDraft()));
  setUp(() async {
    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    final network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => false);
    places = _MockPlaces();
    cubit = RoutePlannerCubit(
      _MockOptimize(),
      _MockSavedRoutes(),
      _MockGeocoding(),
      places,
      draft,
      network,
      _MockRouting(),
    );
    AppStrings.setLocale(const Locale('en'));
    await cubit.refreshConnectivity();
  });
  tearDown(() => cubit.close());

  test(
    'a business share imports its one POI, not its caption as extra stops',
    () async {
      final count = await cubit.addPointsFromSharedText(
        'Cafe Beirut\nA restaurant\n$poi',
      );
      expect(count, 1);
      expect(cubit.state.points, hasLength(1));
      expect(cubit.state.points.single.label, 'Cafe Beirut');
      expect(cubit.state.points.single.latitude, 33.89);
      expect(cubit.state.points.single.longitude, 35.51);
      verifyNever(() => places.resolveOne(any(), near: any(named: 'near')));
    },
  );

  test('pasting a POI URL uses the same pin and preserves its name', () async {
    expect(await cubit.addPointsFromText(poi), 1);
    expect(cubit.state.points.single.label, 'Cafe Beirut');
    expect(cubit.state.points.single.latitude, 33.89);
  });

  test('ordinary pasted coordinate rows still import separately', () async {
    cubit.beginMultiStopTrip();
    expect(await cubit.addPointsFromText('33.89,35.51\n33.90,35.52'), 2);
    expect(cubit.state.points, hasLength(2));
  });
}
