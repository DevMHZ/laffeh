import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/services/location_ping_service.dart';
import 'core/services/saved_routes_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/driver_palette.dart';
import 'core/utils/tree_refresh.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/route_planner/presentation/pages/splash_page.dart';

class LaffahApp extends StatefulWidget {
  const LaffahApp({super.key});

  @override
  State<LaffahApp> createState() => _LaffahAppState();
}

class _LaffahAppState extends State<LaffahApp> with WidgetsBindingObserver {
  /// Language and palette both live in plain statics — [AppStrings] and
  /// [AppColors] — read at build time by widgets that never subscribe to
  /// anything. Watched together here so one change refreshes the app.
  late final Listenable _appearance = Listenable.merge([
    AppStrings.localeNotifier,
    AppTheme.notifier,
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appearance.addListener(_onAppearanceChanged);
  }

  @override
  void dispose() {
    _appearance.removeListener(_onAppearanceChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rebuild every screen in place the moment the language (or theme)
  /// changes — including routes already on the stack.
  ///
  /// The obvious fix, re-keying the app so the tree is rebuilt from scratch,
  /// is the one thing we cannot do: it destroys and recreates the native map
  /// surface under the planner, which used to crash. And the cheap fix,
  /// rebuilding [MaterialApp], stops at the Navigator — the pages below it
  /// are handed the same widget instances, so Flutter rightly skips them and
  /// the driver keeps reading the old language until they restart the app.
  ///
  /// So the element tree is walked and marked dirty instead. Every element
  /// rebuilds on the next frame; every [State] — the map's included — is
  /// left exactly where it was.
  void _onAppearanceChanged() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    // A change raised *during* a build (the locale resolution callback can
    // do it) cannot mark anything dirty until that build is over.
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildTree());
    } else {
      _rebuildTree();
    }
  }

  void _rebuildTree() {
    if (!mounted) return;
    markSubtreeForRebuild(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sl<LocationPingService>().ping();

      sl<SavedRoutesSyncService>().syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>.value(
      value: sl<AuthCubit>(),
      child: ScreenUtilInit(
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
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(
                                    minScaleFactor: 0.9,
                                    maxScaleFactor: 1.18,
                                  ),
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
      ),
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
