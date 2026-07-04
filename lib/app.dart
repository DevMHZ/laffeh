import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/driver_palette.dart';
import 'features/route_planner/presentation/pages/splash_page.dart';

class LaffahApp extends StatelessWidget {
  const LaffahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) {
        return ValueListenableBuilder<DriverPalette>(
          valueListenable: AppTheme.notifier,
          builder: (_, __, ___) {
            return ValueListenableBuilder<Locale>(
              valueListenable: AppStrings.localeNotifier,
              builder: (_, locale, __) {
                return MaterialApp(
                  // Deliberately NOT re-keyed on locale. Re-keying tore down
                  // the whole tree — including the live MapLibre native map
                  // (a platform view) — which crashes iOS when it's disposed
                  // mid-flight during a language switch. Text direction still
                  // flips cleanly without it: MaterialApp re-resolves the
                  // locale and updates its Directionality in place, and every
                  // string is read live via AppStrings, so the rebuild
                  // triggered by localeNotifier is all that's needed. Bonus:
                  // the user stays on their current screen instead of being
                  // bounced back to the splash page.
                  onGenerateTitle: (_) => AppStrings.appName,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.data,
                  locale: locale,
                  supportedLocales: AppStrings.supportedLocales,
                  localeResolutionCallback: (_, __) {
                    final resolved = AppStrings.resolveLocale(locale);
                    AppStrings.setLocale(resolved);
                    return resolved;
                  },
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: EasyLoading.init(
                    builder: (context, child) {
                      return ScrollConfiguration(
                        behavior: const _LaffahScrollBehavior(),
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: MediaQuery.textScalerOf(
                              context,
                            ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.18),
                          ),
                          child: child ?? const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                  home: const SplashPage(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LaffahScrollBehavior extends MaterialScrollBehavior {
  const _LaffahScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
