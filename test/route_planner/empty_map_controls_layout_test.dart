import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/pages/route_add_options_host.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/add_place_bar.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/map_action_button.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_map_view.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/sheet_extent.dart';

class _Planner extends Cubit<RoutePlannerState> implements RoutePlannerCubit {
  _Planner() : super(const RoutePlannerState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('empty map controls clear the address card only in that state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppStrings.setLocale(const Locale('en'));
    dotenv.loadFromString(envString: 'AI_ROUTE_BASE_URL=https://example.com');

    final planner = _Planner();
    final sheetExtent = ValueNotifier<double>(0);
    final emptyExtent = ValueNotifier<double>(0);
    addTearDown(planner.close);
    addTearDown(sheetExtent.dispose);
    addTearDown(emptyExtent.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RoutePlannerCubit>.value(
          value: planner,
          child: Scaffold(
            body: SheetExtent(
              extent: sheetExtent,
              child: Stack(
                children: [
                  RouteMapView(emptyOptionsExtent: emptyExtent),
                  AddOptionsHost(extent: emptyExtent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(emptyExtent.value, greaterThan(0));
    final mapButton = find.byType(MapActionButton);
    final emptyButtonBottom = tester.getBottomLeft(mapButton).dy;
    final addressTop = tester.getTopLeft(find.byType(AddPlaceBar)).dy;
    expect(emptyButtonBottom, lessThan(addressTop - 8));

    planner.emit(const RoutePlannerState(manualPlacement: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getBottomLeft(mapButton).dy, greaterThan(emptyButtonBottom + 80));
  });
}
