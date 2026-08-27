import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/saved_routes/data/datasources/saved_routes_local_datasource.dart';
import 'package:laffeh/features/saved_routes/data/datasources/saved_routes_remote_datasource.dart';
import 'package:laffeh/features/saved_routes/data/models/saved_route_model.dart';
import 'package:laffeh/features/saved_routes/data/repositories/saved_routes_repository_impl.dart';
import 'package:laffeh/features/saved_routes/domain/entities/saved_route.dart';

class _MockRemote extends Mock implements SavedRoutesRemoteDataSource {}

SavedRoute _route(String id, {required DateTime savedAt, String? name}) =>
    SavedRoute(
      id: id,
      name: name ?? 'Trip $id',
      savedAt: savedAt,
      routingMode: 'car',
      orderedPoints: const [
        RoutePoint(
          id: 'd',
          latitude: 24.70,
          longitude: 46.60,
          label: 'Departure',
          weight: 0,
          kind: RoutePointKind.depot,
        ),
        RoutePoint(
          id: 's1',
          latitude: 24.71,
          longitude: 46.61,
          label: 'Stop 1',
          weight: 0,
          kind: RoutePointKind.stop,
        ),
      ],
      metrics: const RouteMetrics(totalDistanceKm: 4.4),
      fullPolyline: const [LatLng(24.70, 46.60), LatLng(24.71, 46.61)],
      goPolyline: const [LatLng(24.70, 46.60), LatLng(24.71, 46.61)],
      returnPolyline: const [],
      hasRoadGeometry: true,
    );

SavedRouteModel _model(String id, {required DateTime savedAt, String? name}) =>
    SavedRouteModel.fromEntity(_route(id, savedAt: savedAt, name: name));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final jan = DateTime.utc(2026, 1, 1);
  final feb = DateTime.utc(2026, 2, 1);
  final mar = DateTime.utc(2026, 3, 1);

  late SharedPreferences prefs;
  late SavedRoutesLocalDataSource local;
  late _MockRemote remote;

  /// The repo under test, signed in as [uid] (null = signed out).
  SavedRoutesRepositoryImpl repoFor(String? uid) => SavedRoutesRepositoryImpl(
    local,
    remote: remote,
    currentUserId: () => uid,
  );

  setUpAll(() {
    registerFallbackValue(<SavedRouteModel>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = SavedRoutesLocalDataSource(prefs);
    remote = _MockRemote();
    when(() => remote.fetchAll()).thenAnswer((_) async => const []);
    when(() => remote.upsertAll(any())).thenAnswer((_) async {});
    when(() => remote.deleteAll(any())).thenAnswer((_) async {});
    when(() => remote.deleteEverything()).thenAnswer((_) async {});
  });

  group('sync', () {
    test('a fresh phone gets the account\'s trips', () async {
      when(() => remote.fetchAll()).thenAnswer(
        (_) async => [_model('a', savedAt: jan), _model('b', savedAt: feb)],
      );

      final changed = await repoFor('u1').sync();

      expect(changed, isTrue);
      final list = await repoFor('u1').list();
      // Newest first.
      expect(list.map((r) => r.id), ['b', 'a']);
    });

    test('trips saved before signing up are adopted by the account', () async {
      await repoFor(null).upsert(_route('trial', savedAt: jan));
      // Nothing went up while signed out.
      verifyNever(() => remote.upsertAll(any()));

      await repoFor('u1').sync();

      final pushed =
          verify(() => remote.upsertAll(captureAny())).captured.single
              as List<SavedRouteModel>;
      expect(pushed.map((m) => m.id), ['trial']);
      expect((await repoFor('u1').list()).map((r) => r.id), ['trial']);
    });

    test('the newer copy of a trip wins', () async {
      await repoFor('u1').upsert(_route('a', savedAt: mar, name: 'renamed'));
      clearInteractions(remote);
      when(
        () => remote.fetchAll(),
      ).thenAnswer((_) async => [_model('a', savedAt: jan, name: 'stale')]);

      await repoFor('u1').sync();

      expect((await repoFor('u1').list()).single.name, 'renamed');
      final pushed =
          verify(() => remote.upsertAll(captureAny())).captured.single
              as List<SavedRouteModel>;
      expect(pushed.single.name, 'renamed');
    });

    test('the account\'s newer copy replaces the local one', () async {
      await repoFor('u1').upsert(_route('a', savedAt: jan, name: 'old'));
      clearInteractions(remote);
      when(
        () => remote.fetchAll(),
      ).thenAnswer((_) async => [_model('a', savedAt: mar, name: 'newer')]);

      await repoFor('u1').sync();

      expect((await repoFor('u1').list()).single.name, 'newer');
      verifyNever(() => remote.upsertAll(any()));
    });

    test('a deletion made offline is not undone by the next pull', () async {
      final repo = repoFor('u1');
      await repo.upsert(_route('a', savedAt: jan));
      // The account is unreachable when the driver deletes the trip.
      when(() => remote.deleteAll(any())).thenThrow(Exception('offline'));
      await repo.delete('a');
      expect(local.readDeletedIds(), ['a']);

      // The account still has the row when the connection comes back.
      when(() => remote.deleteAll(any())).thenAnswer((_) async {});
      when(
        () => remote.fetchAll(),
      ).thenAnswer((_) async => [_model('a', savedAt: jan)]);
      clearInteractions(remote);

      await repo.sync();

      verify(() => remote.deleteAll(['a'])).called(1);
      expect(await repo.list(), isEmpty);
      expect(local.readDeletedIds(), isEmpty);
    });

    test(
      'a different account does not inherit the last driver\'s trips',
      () async {
        await repoFor('u1').upsert(_route('mine', savedAt: jan));
        await repoFor('u1').sync();
        clearInteractions(remote);

        when(
          () => remote.fetchAll(),
        ).thenAnswer((_) async => [_model('theirs', savedAt: feb)]);
        await repoFor('u2').sync();

        expect((await repoFor('u2').list()).map((r) => r.id), ['theirs']);
        // The first driver's trip was never pushed into the second's account.
        verifyNever(() => remote.upsertAll(any()));
      },
    );

    test('signed out, or with no backend, it does nothing', () async {
      expect(await repoFor(null).sync(), isFalse);
      expect(await SavedRoutesRepositoryImpl(local).sync(), isFalse);
      verifyNever(() => remote.fetchAll());
    });

    test('a failing account leaves the local history untouched', () async {
      await repoFor('u1').upsert(_route('a', savedAt: jan));
      when(() => remote.fetchAll()).thenThrow(Exception('boom'));

      expect(await repoFor('u1').sync(), isFalse);
      expect((await repoFor('u1').list()).map((r) => r.id), ['a']);
    });
  });

  group('mirroring', () {
    test('saving while signed in echoes to the account', () async {
      await repoFor('u1').upsert(_route('a', savedAt: jan));
      final pushed =
          verify(() => remote.upsertAll(captureAny())).captured.single
              as List<SavedRouteModel>;
      expect(pushed.single.id, 'a');
    });

    test('a mirror failure never costs the local save', () async {
      when(() => remote.upsertAll(any())).thenThrow(Exception('offline'));
      final saved = await repoFor('u1').upsert(_route('a', savedAt: jan));
      expect(saved.id, 'a');
      expect((await repoFor('u1').list()).map((r) => r.id), ['a']);
    });

    test('forgetAccount clears the history and its owner', () async {
      final repo = repoFor('u1');
      await repo.upsert(_route('a', savedAt: jan));
      await repo.sync();
      expect(local.readOwner(), 'u1');

      await repo.forgetAccount();

      expect(await repo.list(), isEmpty);
      expect(local.readOwner(), isNull);
    });
  });
}
