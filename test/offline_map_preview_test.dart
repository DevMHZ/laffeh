// Visual previews of the offline-map flow (not regression gates).
// Run: flutter test test/offline_map_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laffeh/core/config/offline_map_config.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/di/service_locator.dart';
import 'package:laffeh/core/services/map_cache_service.dart';
import 'package:laffeh/core/services/map_pack_controller.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/utils/area_grid.dart';
import 'package:laffeh/core/utils/tile_math.dart';
import 'package:laffeh/core/widgets/map_pack_progress_view.dart';
import 'package:laffeh/core/widgets/offline_area_picker_page.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/offline_area_offer.dart';
import 'package:laffeh/features/settings/presentation/widgets/offline_map_section.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

Widget _harness(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.data,
  home: Directionality(
    textDirection: TextDirection.rtl,
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

  setUp(() async {
    await _loadFonts();
    // Previewed in Arabic: it is the language the app ships in, and the
    // one where a mixed-direction line like "8 MB of ≈ 20 MB" can go wrong.
    AppStrings.setLocale(const Locale('ar'));
    SharedPreferences.setMockInitialValues({});
    if (!sl.isRegistered<SharedPreferences>()) {
      sl.registerSingleton<SharedPreferences>(
        await SharedPreferences.getInstance(),
      );
    }
  });

  testWidgets('offline area offer', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 300 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(const OfflineAreaOffer()));
    // The widget's own bind() can't resolve without a platform behind it,
    // so put the pack in the state this preview is about: nothing saved.
    MapPackController.area.debugSetProgress(status: MapPackStatus.idle);
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_area_offer.png'),
    );
  });

  testWidgets('download progress', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 300 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Drive the shared controller into a mid-download state without
    // touching the platform: this is a render preview, not a download.
    final pack = MapPackController.area;
    pack.debugSetProgress(
      status: MapPackStatus.downloading,
      progress: 0.42,
      bytes: 8 * 1048576,
      doneBoxes: 4,
      boxCount: 12,
    );
    addTearDown(pack.reset);

    await tester.pumpWidget(
      _harness(MapPackProgressView(pack: pack, estimatedMb: 20)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_download_progress.png'),
    );
  });

  testWidgets('download progress while stopping', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 300 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final pack = MapPackController.area;
    pack.debugSetProgress(
      status: MapPackStatus.downloading,
      progress: 0.42,
      bytes: 8 * 1048576,
      doneBoxes: 4,
      boxCount: 12,
      cancelling: true,
    );
    addTearDown(pack.reset);

    await tester.pumpWidget(
      _harness(MapPackProgressView(pack: pack, estimatedMb: 20)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_download_stopping.png'),
    );
  });

  testWidgets('picker card — a framed area, priced', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(MapPackController.area.reset);

    final pack = MapPackController.area;
    pack.debugSetProgress(status: MapPackStatus.idle);

    await tester.pumpWidget(
      _harness(
        OfflineAreaPickerCard(
          pack: pack,
          widthKm: 24.4,
          heightKm: 18.1,
          estimateMb: 31,
          quotedMb: 31,
          tooLarge: false,
          onDownload: () {},
          onDelete: null,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_area_picker_card.png'),
    );
  });

  testWidgets('picker card — a new area while others are saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(MapPackController.area.reset);

    final pack = MapPackController.area;
    pack.debugSetProgress(status: MapPackStatus.idle);

    await tester.pumpWidget(
      _harness(
        OfflineAreaPickerCard(
          pack: pack,
          widthKm: 24.4,
          heightKm: 18.1,
          estimateMb: 31,
          quotedMb: 31,
          tooLarge: false,
          // Two maps are already stored, but not of *this* place. The
          // button has to read "download" — saying "update" here is the bug
          // that sent us down this road.
          savedHere: null,
          savedCount: 2,
          statusApplies: false,
          onDownload: () {},
          onDelete: null,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_area_new_place.png'),
    );
  });

  testWidgets('picker card — the frame sits on a saved area', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(MapPackController.area.reset);

    final pack = MapPackController.area;
    pack.debugSetProgress(status: MapPackStatus.ready, progress: 1);

    await tester.pumpWidget(
      _harness(
        OfflineAreaPickerCard(
          pack: pack,
          widthKm: 24.4,
          heightKm: 18.1,
          estimateMb: 31,
          quotedMb: 31,
          tooLarge: false,
          // Only here does "update" tell the truth.
          savedHere: SavedMapArea(
            packId: 'area.test',
            bounds: AreaGrid.squareAround(
              const LatLng(24.7136, 46.6753),
              radiusKm: 12,
            ),
            bytes: 29 * 1048576,
          ),
          savedCount: 2,
          onDownload: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_area_saved_here.png'),
    );
  });

  testWidgets('picker card — the frame holds more than we will fetch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(MapPackController.area.reset);

    final pack = MapPackController.area;
    pack.debugSetProgress(status: MapPackStatus.idle);

    await tester.pumpWidget(
      _harness(
        OfflineAreaPickerCard(
          pack: pack,
          widthKm: 310,
          heightKm: 240,
          estimateMb: 940,
          quotedMb: 940,
          tooLarge: true,
          // Disabled, which is the point of this preview: the button has to
          // read as unavailable rather than as broken.
          onDownload: null,
          onDelete: null,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_area_too_large.png'),
    );
  });

  testWidgets('settings row', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 160 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(MapPackController.area.reset);

    await tester.pumpWidget(_harness(const OfflineMapSection()));
    MapPackController.area.debugSetProgress(
      status: MapPackStatus.ready,
      progress: 1,
      bytes: 24 * 1048576,
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline_settings_row.png'),
    );
  });

  test('the area the picker opens on costs what a driver would accept', () {
    final mb = TileMath.estimatedMb(
      AreaGrid.around(
        const LatLng(24.7136, 46.6753),
        radiusKm: OfflineMapConfig.defaultAreaRadiusKm,
      ),
      minZoom: OfflineMapConfig.areaMinZoom,
      maxZoom: OfflineMapConfig.areaMaxZoom,
    );

    // The frame opens pre-filled, so this is the figure most drivers will
    // ever see on the button. If a config change turns the opening shot
    // into a download nobody would accept, it should fail here.
    expect(mb, greaterThan(1));
    expect(mb, lessThan(OfflineMapConfig.maxAreaMb / 4));
  });
}
