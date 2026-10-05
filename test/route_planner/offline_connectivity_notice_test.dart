import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/services/location_gate.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/pages/route_planner_overlays.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_connectivity_notice.dart';

class _Planner extends Cubit<RoutePlannerState> implements RoutePlannerCubit {
  _Planner(super.initialState);

  void update(RoutePlannerState state) => emit(state);

  @override
  Future<void> refreshConnectivity() async =>
      emit(state.copyWith(isOffline: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _cachedRoute = OptimizedRoute(
  orderedPoints: [],
  fullPolyline: [LatLng(33.51, 36.27), LatLng(33.52, 36.28)],
  goPolyline: [],
  returnPolyline: [],
  metrics: RouteMetrics(totalDistanceKm: 1),
  hasRoadGeometry: true,
);

Widget _app(Widget child, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: language == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('offline launch exposes its notice without opening a sheet', (
    tester,
  ) async {
    final cubit = _Planner(const RoutePlannerState(isOffline: true));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      _app(
        BlocProvider<RoutePlannerCubit>.value(
          value: cubit,
          child: const Stack(children: [PlannerConnectivityNotice()]),
        ),
      ),
    );

    expect(find.text(AppStrings.offlineBody), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.checkConnection));
    await tester.pump();
    expect(find.byType(RouteConnectivityNotice), findsNothing);
  });

  testWidgets(
    'saved routes explain offline driving and survive status changes',
    (tester) async {
      final cubit = _Planner(
        const RoutePlannerState(isOffline: true, optimizedRoute: _cachedRoute),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _app(
          BlocProvider<RoutePlannerCubit>.value(
            value: cubit,
            child: const Stack(children: [PlannerConnectivityNotice()]),
          ),
        ),
      );
      expect(find.text(AppStrings.offlineSavedRouteBody), findsOneWidget);

      cubit.update(cubit.state.copyWith(isOffline: false));
      await tester.pump();
      expect(find.byType(RouteConnectivityNotice), findsNothing);
      expect(cubit.state.optimizedRoute, same(_cachedRoute));

      cubit.update(
        cubit.state.copyWith(isOffline: true, navigationActive: true),
      );
      await tester.pump();
      // The drive overlay owns its own placement; no overlapping planner card.
      expect(find.byType(RouteConnectivityNotice), findsNothing);
    },
  );

  testWidgets('location and offline notices have separate vertical space', (
    tester,
  ) async {
    final cubit = _Planner(
      const RoutePlannerState(
        status: RoutePlannerStatus.locationReady,
        isOffline: true,
        locationAccess: LocationAccess.denied,
      ),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      _app(
        BlocProvider<RoutePlannerCubit>.value(
          value: cubit,
          child: const Stack(
            children: [LocationAccessChip(), PlannerConnectivityNotice()],
          ),
        ),
      ),
    );

    final locationBottom = tester.getBottomLeft(
      find.text(AppStrings.enableLocationCta),
    );
    final offlineTop = tester.getTopLeft(find.byType(RouteConnectivityNotice));
    expect(offlineTop.dy, greaterThan(locationBottom.dy));
  });

  testWidgets('retry shows progress and does not issue duplicate probes', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        RouteConnectivityNotice(
          hasSavedRoute: true,
          isDriving: true,
          onRetry: () {
            calls++;
            return pending.future;
          },
        ),
      ),
    );

    expect(find.text(AppStrings.offlineDriveTitle), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.checkConnection));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip(AppStrings.checkConnection), findsNothing);
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip(AppStrings.checkConnection), findsOneWidget);
  });

  for (final language in ['en', 'ar', 'fr']) {
    testWidgets(
      'offline copy fits narrow screens with larger text: $language',
      (tester) async {
        AppStrings.setLocale(Locale(language));
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            Padding(
              padding: const EdgeInsets.all(14),
              child: RouteConnectivityNotice(
                hasSavedRoute: true,
                onRetry: () async {},
              ),
            ),
            language: language,
            scale: 1.5,
          ),
        );
        expect(find.text(AppStrings.offlineSavedRouteBody), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
