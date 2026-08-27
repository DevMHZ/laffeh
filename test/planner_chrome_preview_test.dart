// Visual previews of the planner's small chrome: the departure sheet, the
// confirmation dialog, the top toast, and the readiness note under the
// optimize button. These are the pieces a driver meets between the big
// screens, and each one used to be styled by whoever wrote it last.
// Run: flutter test test/planner_chrome_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/widgets/app_dialog.dart';
import 'package:laffeh/core/widgets/app_toast.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/pages/route_planner_actions.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_plan_action_bar.dart';

/// Render-only stand-in: holds a fixed state, ignores all commands.
class _FakeRouteCubit extends Cubit<RoutePlannerState>
    implements RoutePlannerCubit {
  _FakeRouteCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

const _departure = RoutePoint(
  id: 'depot_current',
  latitude: 33.88,
  longitude: 35.49,
  label: 'Departure',
  weight: 0,
  kind: RoutePointKind.depot,
);

Widget _screen(Widget child, {RoutePlannerState? state}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.data,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider<RoutePlannerCubit>.value(
      value: _FakeRouteCubit(
        state ??
            const RoutePlannerState(
              status: RoutePlannerStatus.pointsUpdated,
              points: [_departure],
              userLocation: LatLng(33.88, 35.49),
            ),
      ),
      child: Scaffold(
        // Stands in for the live map these all float over.
        backgroundColor: const Color(0xFFDFE7DA),
        body: Stack(children: [child]),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _loadFonts();
    AppStrings.setLocale(const Locale('ar'));
  });
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('departure sheet — the four ways, ar', (tester) async {
    await phone(tester);
    late BuildContext host;
    await tester.pumpWidget(
      _screen(
        Builder(
          builder: (context) {
            host = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    RoutePlannerActions.showDeparturePicker(
      host,
      host.read<RoutePlannerCubit>(),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/departure_sheet_ar.png'),
    );
  });

  testWidgets('confirm dialog — clearing the trip, ar', (tester) async {
    await phone(tester);
    late BuildContext host;
    await tester.pumpWidget(
      _screen(
        Builder(
          builder: (context) {
            host = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    AppDialog.confirm(
      context: host,
      title: AppStrings.clearAll,
      message: AppStrings.clearRouteConfirm,
      icon: Iconsax.trash,
      tone: AppDialogTone.danger,
      confirmLabel: AppStrings.remove,
      confirmIcon: Iconsax.trash,
      destructive: true,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/confirm_dialog_ar.png'),
    );
  });

  testWidgets('toast — over the map, never under the thumb, ar', (
    tester,
  ) async {
    await phone(tester);
    late BuildContext host;
    await tester.pumpWidget(
      _screen(
        Builder(
          builder: (context) {
            host = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    AppToast.show(host, AppStrings.pointAdded);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/top_toast_ar.png'),
    );
    // Let it leave on its own, so its timer doesn't outlive the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('optimize bar — the note is a nudge, not a fault, ar', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      _screen(
        Align(
          alignment: Alignment.bottomCenter,
          child: ColoredBox(
            color: AppColors.surface,
            child: RoutePlanActionBar(
              pointsCount: 1,
              canOptimize: false,
              isOptimizing: false,
              onOptimize: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/optimize_bar_tip_ar.png'),
    );
  });
}
