import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laffeh/core/config/service_profile.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/theme/driver_palette.dart';
import 'package:laffeh/core/theme/vehicle_kind.dart';
import 'package:laffeh/core/theme/vehicle_prefs.dart';
import 'package:laffeh/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:laffeh/features/settings/presentation/pages/settings_page.dart';
import 'package:laffeh/features/settings/presentation/widgets/service_profile_picker.dart';
import 'support/preview_fonts.dart';

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(const AuthUnauthenticated());
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() async {
    await loadPreviewIconFonts();
    final font = FontLoader('Almarai');
    for (final weight in ['Regular', 'Bold', 'ExtraBold', 'Light']) {
      font.addFont(rootBundle.load('assets/fonts/Almarai-$weight.ttf'));
    }
    await font.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.active = DriverPalette.laffah;
    AppStrings.setLocale(const Locale('en'));
  });
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  testWidgets(
    'load choices expose radio state and apply a choice by touch and voice',
    (tester) async {
      final handle = tester.ensureSemantics();
      var selected = ServiceProfile.delivery;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.data,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ServiceProfilePicker(
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      final delivery = find.byKey(const ValueKey('profile-delivery'));
      final pickup = find.byKey(const ValueKey('profile-pickup'));
      expect(
        tester
            .getSemantics(delivery)
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      await tester.tap(pickup);
      await tester.pump();
      expect(selected, ServiceProfile.pickup);
      expect(
        tester
            .getSemantics(delivery)
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        CheckedState.isFalse,
      );
      final node = tester.getSemantics(pickup);
      expect(
        node.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
      );
      final none = tester.getSemantics(
        find.byKey(const ValueKey('profile-none')),
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: none.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(selected, ServiceProfile.none);
      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    },
  );

  for (final language in ['en', 'ar', 'fr']) {
    testWidgets('$language About links launch externally and fit large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppStrings.setLocale(Locale(language));
      final auth = _Auth();
      addTearDown(auth.close);
      final launches = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        launches.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.data,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Directionality(
                textDirection: language == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: const SettingsPage(),
              ),
            ),
          ),
        ),
      );
      for (final (label, url) in [
        (AppStrings.aboutUs, 'https://www.afdal.tech/'),
        (AppStrings.tryOurGame, 'https://game.laffa.afdal.tech/'),
      ]) {
        await tester.scrollUntilVisible(
          find.text(label).hitTestable(),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(launches.last.method, 'launch');
        expect(launches.last.arguments['url'], url);
        expect(launches.last.arguments['useSafariVC'], false);
        expect(launches.last.arguments['useWebView'], false);
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(launches, hasLength(2));
    });

    testWidgets(
      '$language load descriptions fit a narrow screen at 180% text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppStrings.setLocale(Locale(language));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.data,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: Directionality(
                textDirection: language == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ServiceProfilePicker(
                      value: ServiceProfile.delivery,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('profile-none')),
          200,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.serviceProfileNoneHint), findsOneWidget);
      },
    );

    testWidgets(
      '$language settings choosers fit large text and work without swiping',
      (tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth();
        addTearDown(auth.close);
        AppStrings.setLocale(Locale(language));
        VehiclePrefs.notifier.value = VehicleKind.arrow;
        await tester.pumpWidget(
          BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp(
              theme: AppTheme.data,
              home: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.8),
                  disableAnimations: true,
                ),
                child: Directionality(
                  textDirection: language == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: const SettingsPage(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        Future<void> reveal(Finder target) async {
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          position.jumpTo(
            (position.pixels + tester.getCenter(target).dy - 300).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();
        }

        final appearance = find.text(AppStrings.appearance);
        await reveal(appearance);
        await tester.tap(appearance);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await reveal(appearance);
        await tester.tap(appearance);
        await tester.pumpAndSettle();
        final vehicle = find.text(AppStrings.vehicleIcon);
        await reveal(vehicle);
        await tester.tap(vehicle);
        await tester.pumpAndSettle();
        final previous = find.byIcon(Icons.arrow_back_rounded).last;
        await reveal(previous);
        await tester.tap(previous);
        await tester.pumpAndSettle();
        expect(VehiclePrefs.current, VehicleKind.camel);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('$language profile preview', (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppStrings.setLocale(Locale(language));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.data,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: language == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Scaffold(
                appBar: AppBar(title: Text(AppStrings.serviceProfile)),
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ServiceProfilePicker(
                    value: ServiceProfile.delivery,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/settings_profiles_$language.png'),
      );
    });
  }

  for (final throws in [false, true]) {
    testWidgets('failed game launch gives feedback (throws: $throws)', (
      tester,
    ) async {
      final auth = _Auth();
      addTearDown(auth.close);
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        if (throws) throw PlatformException(code: 'no_browser');
        return false;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: auth,
          child: MaterialApp(theme: AppTheme.data, home: const SettingsPage()),
        ),
      );
      await tester.scrollUntilVisible(
        find.text(AppStrings.tryOurGame).hitTestable(),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(AppStrings.tryOurGame));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.websiteOpenFailed(AppStrings.gameWebsiteUrl)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings puts preferences first and load selection persists', (
    tester,
  ) async {
    final auth = _Auth();
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.data,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text(AppStrings.language)).dy,
      lessThan(tester.getTopLeft(find.text(AppStrings.vehicleIcon)).dy),
    );
    await tester.scrollUntilVisible(
      find.text(AppStrings.serviceProfile).hitTestable(),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.serviceProfile));
    await tester.pump(const Duration(milliseconds: 300));
    final pickup = find.byKey(const ValueKey('profile-pickup'));
    await tester.scrollUntilVisible(
      pickup.hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(pickup);
    await tester.pump();
    expect(ServiceProfilePrefs.current, ServiceProfile.pickup);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'laffeh.serviceProfile',
      ),
      'pickup',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
