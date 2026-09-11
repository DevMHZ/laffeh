import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/theme/driver_palette.dart';
import 'package:laffeh/core/widgets/app_button.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_points_sheet.dart';

class _Planner extends Cubit<RoutePlannerState> implements RoutePlannerCubit {
  _Planner(super.initialState);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  tearDown(() {
    AppColors.active = DriverPalette.laffah;
    AppStrings.setLocale(const Locale('en'));
  });

  test('primary actions retain readable text in every palette', () {
    for (final palette in DriverPalette.all) {
      AppColors.active = palette;
      expect(
        contrast(AppColors.action, AppColors.onAction),
        greaterThanOrEqualTo(4.5),
        reason: palette.id,
      );
      expect(
        contrast(AppColors.primary, AppColors.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: palette.id,
      );
    }
    AppColors.active = DriverPalette.laffah;
    expect(
      contrast(AppColors.textMuted, AppColors.surfaceAlt),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.primary, AppColors.primarySoft),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('button exposes its action and blocks activation while loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    Future<void> render({bool loading = false}) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: Scaffold(
          body: AppButton(
            label: 'Plan route',
            loading: loading,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await render();
    expect(tester.getSize(find.byType(AppButton)).height, 56);
    final node = tester.getSemantics(find.byType(AppButton));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.tap,
        nodeId: node.id,
        viewId: tester.view.viewId,
      ),
    );
    expect(taps, 1);
    await render(loading: true);
    expect(
      tester
          .getSemantics(find.byType(AppButton))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final locale in ['en', 'ar', 'fr']) {
    testWidgets('small phone planner fits $locale with large text', (
      tester,
    ) async {
      AppStrings.setLocale(Locale(locale));
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const points = [
        RoutePoint(
          id: 'd',
          latitude: 33,
          longitude: 35,
          label: 'Departure',
          weight: 0,
          kind: RoutePointKind.depot,
        ),
        RoutePoint(
          id: '1',
          latitude: 33.1,
          longitude: 35.1,
          label: 'Gemmayzeh delivery entrance',
          weight: 1,
          kind: RoutePointKind.stop,
        ),
        RoutePoint(
          id: '2',
          latitude: 33.2,
          longitude: 35.2,
          label: 'Ashrafieh main reception',
          weight: 1,
          kind: RoutePointKind.stop,
        ),
      ];
      final cubit = _Planner(
        const RoutePlannerState(
          status: RoutePlannerStatus.pointsUpdated,
          points: points,
        ),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 760),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Directionality(
              textDirection: locale == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: BlocProvider<RoutePlannerCubit>.value(
                value: cubit,
                child: Scaffold(body: const RoutePointsSheet()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        grid.gridDelegate,
        isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
      );
      final first = tester.getTopLeft(find.text(points[1].label));
      final second = tester.getTopLeft(find.text(points[2].label));
      expect(second.dy, greaterThan(first.dy));
    });
  }
}
