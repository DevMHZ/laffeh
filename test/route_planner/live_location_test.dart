import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
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
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

Position _fix(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// A Geolocator whose position stream is fed by hand.
///
/// It counts listens and cancels as well as delivering fixes, because half
/// of what the planning dot has to get right is *not* holding the GPS open:
/// while drive mode owns it, or while the app is off screen.
class _FakeGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  final _controller = StreamController<Position>.broadcast();

  int listens = 0;
  int cancels = 0;
  LocationSettings? lastSettings;

  bool get isStreaming => listens > cancels;

  /// Delivers a fix to whoever is listening right now.
  Future<void> emitFix(double lat, double lon) async {
    _controller.add(_fix(lat, lon));
    // Let the broadcast reach the cubit's listener before assertions run.
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    lastSettings = locationSettings;
    // Wrapping the broadcast stream makes each subscribe/cancel pair
    // individually observable.
    late StreamController<Position> view;
    StreamSubscription<Position>? inner;
    view = StreamController<Position>(
      onListen: () {
        listens++;
        inner = _controller.stream.listen(view.add);
      },
      onCancel: () {
        cancels++;
        return inner?.cancel();
      },
    );
    return view.stream;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => _fix(33.8938, 35.5018);

  Future<void> dispose() => _controller.close();
}

void main() {
  late _FakeGeolocator geo;
  late RoutePlannerCubit cubit;

  setUpAll(() => registerFallbackValue(_FakeDraft()));

  setUp(() {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;

    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    final network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => false);

    cubit = RoutePlannerCubit(
      _MockOptimize(),
      _MockSavedRoutes(),
      _MockGeocoding(),
      _MockPlaces(),
      draft,
      network,
      _MockRouting(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await geo.dispose();
  });

  group('live location — the dot with no route in sight', () {
    test('a fix moves the dot and leaves the camera alone', () async {
      await cubit.recenterOnUser();
      expect(geo.isStreaming, isTrue, reason: 'a granted fix starts the dot');

      final cameraBefore = cubit.state.cameraTarget;
      await geo.emitFix(34.10, 35.70);

      expect(cubit.state.userLocation?.latitude, closeTo(34.10, 1e-9));
      expect(cubit.state.userLocation?.longitude, closeTo(35.70, 1e-9));
      expect(
        cubit.state.cameraTarget,
        cameraBefore,
        reason: 'the map must not pan itself under someone reading it',
      );
    });

    test('the stream is coarser than drive mode', () async {
      await cubit.recenterOnUser();
      final settings = geo.lastSettings!;
      expect(
        settings.distanceFilter,
        greaterThan(0),
        reason: "planning doesn't need every metre — that is drive mode's job",
      );
      expect(settings.accuracy, isNot(LocationAccuracy.bestForNavigation));
    });

    test('drive mode takes the dot over, and hands it back', () async {
      await cubit.recenterOnUser();
      expect(geo.isStreaming, isTrue);

      cubit.emit(cubit.state.copyWith(navigationActive: true));
      expect(
        geo.isStreaming,
        isFalse,
        reason: 'two GPS streams for one dot is one too many',
      );

      cubit.stopNavigation();
      expect(geo.isStreaming, isTrue, reason: 'ending a drive resumes the dot');
    });

    test('backgrounding parks the stream, returning resumes it', () async {
      await cubit.recenterOnUser();

      cubit.setAppForeground(false);
      expect(geo.isStreaming, isFalse);

      await geo.emitFix(34.0, 35.6);
      expect(
        cubit.state.userLocation?.latitude,
        closeTo(33.8938, 1e-9),
        reason: 'a parked stream must not still be moving the dot',
      );

      cubit.setAppForeground(true);
      expect(geo.isStreaming, isTrue);

      await geo.emitFix(34.20, 35.80);
      expect(cubit.state.userLocation?.latitude, closeTo(34.20, 1e-9));
    });

    test('a dot that never started is not resurrected by a resume', () {
      cubit.setAppForeground(false);
      cubit.setAppForeground(true);
      expect(
        geo.listens,
        0,
        reason: 'no permission, no fix, no stream — resuming changes nothing',
      );
    });

    test('closing the cubit releases the GPS', () async {
      await cubit.recenterOnUser();
      expect(geo.isStreaming, isTrue);

      await cubit.close();
      expect(geo.isStreaming, isFalse);
    });
  });
}
