import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/utils/marker_factory.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/map_marker_renderer.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/stop_timeline.dart';

RoutePoint _stop(String id, String label) => RoutePoint(
  id: id,
  label: label,
  latitude: 33.5,
  longitude: 36.3,
  weight: 1,
  kind: RoutePointKind.stop,
);

Finder _dot(Color color, Finder child) => find.ancestor(
  of: child,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color == color,
  ),
);

Future<int> _pixelsWithColor(Uint8List png, Color color) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final argb = color.toARGB32();
  var count = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] == ((argb >> 16) & 255) &&
        bytes[i + 1] == ((argb >> 8) & 255) &&
        bytes[i + 2] == (argb & 255) &&
        bytes[i + 3] == 255) {
      count++;
    }
  }
  image.dispose();
  codec.dispose();
  return count;
}

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('failed stops remain red Xs after trip completion', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StopTimeline(
            points: [
              _stop('ok', 'Delivered stop'),
              _stop('failed', 'Failed stop'),
            ],
            currentTarget: 1,
            finished: true,
            compact: true,
            skippedPointIds: const {'failed'},
          ),
        ),
      ),
    );

    expect(
      _dot(AppColors.danger, find.byIcon(Icons.close_rounded)),
      findsOneWidget,
    );
    expect(_dot(AppColors.primary, find.text('1')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Failed stop, ${AppStrings.couldNotDeliver}'),
      findsOneWidget,
    );
    expect(find.text('2'), findsNothing);
    semantics.dispose();
  });

  testWidgets('preview defaults keep ordinary visited stop numbers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StopTimeline(
            points: [_stop('a', 'First'), _stop('b', 'Second')],
            currentTarget: 1,
            finished: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(_dot(AppColors.primary, find.text('1')), findsOneWidget);
    expect(_dot(AppColors.primary, find.text('2')), findsOneWidget);
  });

  testWidgets('failed widget marker exposes its localized delivery outcome', (
    tester,
  ) async {
    AppStrings.setLocale(const Locale('ar'));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkerFactory.stop(
            2,
            tooltip: 'نقطة ٢',
            visit: StopVisitState.skipped,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
      find.byTooltip('نقطة ٢ · ${AppStrings.couldNotDeliver}'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('نقطة ٢ · ${AppStrings.couldNotDeliver}'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'native map PNGs distinguish failed from delivered in both modes',
    (tester) async {
      final counts = await tester.runAsync(
        () async => [
          await _pixelsWithColor(
            await MapMarkerRenderer.stop(2, StopVisitState.skipped),
            AppColors.danger,
          ),
          await _pixelsWithColor(
            await MapMarkerRenderer.stop(2, StopVisitState.visited),
            AppColors.danger,
          ),
          await _pixelsWithColor(
            await MapMarkerRenderer.destination(StopVisitState.skipped),
            AppColors.danger,
          ),
          await _pixelsWithColor(
            await MapMarkerRenderer.destination(StopVisitState.visited),
            AppColors.danger,
          ),
        ],
      );

      expect(counts![0], greaterThan(100));
      expect(counts[1], 0);
      expect(counts[2], greaterThan(100));
      expect(counts[3], 0);
    },
  );
}
