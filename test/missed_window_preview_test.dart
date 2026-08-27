// Visual preview of the missed-availability warning (not a regression gate).
// Run: flutter test test/missed_window_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/entities/stop_time_window.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/missed_time_window_sheet.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

const _depot = RoutePoint(
  id: 'depot',
  latitude: 33.8938,
  longitude: 35.5018,
  label: 'الانطلاق',
  weight: 0,
  kind: RoutePointKind.depot,
);

/// A fixed far-future departure: still ahead of "now", so "leave earlier"
/// renders as a live option rather than the greyed-out explanation — and
/// every clock on screen is identical on every run, which a now-based
/// departure would not be.
final _departure = DateTime(2099, 1, 1, 9, 0);

/// A stop the driver reaches [lateBy] minutes after its window closes.
///
/// The ETA is derived rather than passed in, so the preview can't drift
/// into showing an arrival that contradicts the lateness beside it.
RoutePoint _late(String label, {required int dueHour, required int lateBy}) {
  final endMinuteOfDay = dueHour * 60;
  return RoutePoint(
    id: label,
    latitude: 33.9,
    longitude: 35.55,
    label: label,
    weight: 10,
    kind: RoutePointKind.stop,
    timeWindow: StopTimeWindow(
      startMinuteOfDay: endMinuteOfDay - 60,
      endMinuteOfDay: endMinuteOfDay,
    ),
    etaMinutesFromDeparture:
        endMinuteOfDay + lateBy - (_departure.hour * 60 + _departure.minute),
    timeWindowMissed: true,
    latenessMinutes: lateBy,
  );
}

final _lateStops = [
  _late('صيدلية الحكمة', dueHour: 10, lateBy: 25),
  _late('مستودع الزهراء', dueHour: 11, lateBy: 95),
];

/// The banner as it appears in a bottom sheet: over the map, on the
/// surface colour, at phone width.
Widget _bannerHarness(Widget child, TextDirection dir) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.data,
  home: Directionality(
    textDirection: dir,
    child: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: const Color(0xFFDFE7DA))),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: child,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => registerFallbackValue(_FakeDraft()));

  setUp(() async {
    await _loadFonts();
    AppStrings.setLocale(const Locale('ar'));
  });

  tearDown(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('banner — Arabic', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _bannerHarness(
        MissedWindowBanner(points: _lateStops, onTap: () {}),
        TextDirection.rtl,
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/missed_window_banner_ar.png'),
    );
  });

  testWidgets('banner — English, single stop', (tester) async {
    AppStrings.setLocale(const Locale('en'));
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _bannerHarness(
        MissedWindowBanner(
          points: [_late('Warehouse gate 4', dueHour: 11, lateBy: 95)],
          onTap: () {},
        ),
        TextDirection.ltr,
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/missed_window_banner_en.png'),
    );
  });

  testWidgets('sheet — Arabic', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    when(() => draft.clear()).thenAnswer((_) async {});

    final cubit = RoutePlannerCubit(
      _MockOptimize(),
      _MockSavedRoutes(),
      _MockGeocoding(),
      _MockPlaces(),
      draft,
      _MockNetwork(),
      _MockRouting(),
    );
    addTearDown(cubit.close);

    cubit.emit(
      RoutePlannerState(
        status: RoutePlannerStatus.optimizedSuccess,
        departureAt: _departure,
        points: [_depot, ..._lateStops],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.data,
        home: BlocProvider.value(
          value: cubit,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: const Color(0xFFDFE7DA),
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showMissedTimeWindowSheet(context),
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

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/missed_window_sheet_ar.png'),
    );
  });
}
