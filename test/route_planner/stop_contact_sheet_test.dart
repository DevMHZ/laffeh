import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/point_actions_sheet.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

RoutePoint _stop({String? phone}) => RoutePoint(
  id: 'p1',
  latitude: 33.5131,
  longitude: 36.2767,
  label: 'مخبز الشام',
  address: 'شارع الباسل',
  phone: phone,
  weight: 10,
  kind: RoutePointKind.stop,
);

void main() {
  late RoutePlannerCubit cubit;

  setUpAll(() => registerFallbackValue(_FakeDraft()));

  setUp(() {
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
    AppStrings.setLocale(const Locale('ar'));
  });

  tearDown(() async {
    await cubit.close();
    AppStrings.setLocale(const Locale('en'));
  });

  /// Opens the point sheet on a throwaway page, the way the map and the
  /// planning grid both do.
  Future<void> openSheet(WidgetTester tester, RoutePoint point) async {
    await tester.pumpWidget(
      BlocProvider<RoutePlannerCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showPointActions(context, point),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a stop with a number offers WhatsApp, a call, and the number', (
    tester,
  ) async {
    await openSheet(tester, _stop(phone: '+963944123456'));

    expect(find.text(AppStrings.stopWhatsapp), findsOneWidget);
    expect(find.text(AppStrings.stopCall), findsOneWidget);
    // The number itself is on show, so the driver can read it out.
    expect(find.text('+963944123456'), findsOneWidget);
    // And the row edits rather than adds.
    expect(find.text(AppStrings.stopPhoneEdit), findsOneWidget);
    expect(find.text(AppStrings.stopPhoneAdd), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a stop with no number offers to add one, and nothing to dial', (
    tester,
  ) async {
    await openSheet(tester, _stop());

    // Never offer a contact action that cannot go anywhere.
    expect(find.text(AppStrings.stopWhatsapp), findsNothing);
    expect(find.text(AppStrings.stopCall), findsNothing);
    expect(find.text(AppStrings.stopPhoneAdd), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('renaming and removing are still on offer', (tester) async {
    await openSheet(tester, _stop(phone: '0944123456'));

    expect(find.text(AppStrings.rename), findsOneWidget);
    expect(find.text(AppStrings.remove), findsOneWidget);
  });

  test('setPointPhone stores, replaces and clears the number', () async {
    await cubit.addPoint(const _Pos(33.5131, 36.2767).latLng);
    final id = cubit.state.points.last.id;

    cubit.setPointPhone(id, ' +963944123456 ');
    expect(cubit.state.points.last.phone, '+963944123456');

    cubit.setPointPhone(id, '0944999888');
    expect(cubit.state.points.last.phone, '0944999888');

    // An emptied field is a deliberate removal, not an empty string.
    cubit.setPointPhone(id, '   ');
    expect(cubit.state.points.last.phone, isNull);
    expect(cubit.state.points.last.hasPhone, isFalse);
  });
}

/// Tiny helper so the test reads as coordinates rather than a LatLng import.
class _Pos {
  final double lat;
  final double lng;
  const _Pos(this.lat, this.lng);
  LatLng get latLng => LatLng(lat, lng);
}
