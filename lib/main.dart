import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/dispatch/dispatch_service.dart';
import 'core/config/supabase_config.dart';
import 'core/config/env_config.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/services/map_cache_service.dart';
import 'core/services/saved_routes_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/vehicle_prefs.dart';
import 'core/config/service_profile.dart';
import 'core/config/preview_prefs.dart';
import 'core/utils/debug_log.dart';
import 'core/utils/share_intent_handler.dart';
import 'features/route_planner/presentation/pages/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final startup = _initializeApp();
  runApp(_StartupCoordinator(startup: startup));
}

Future<void> _initializeApp() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  DebugLog.banner('laffeh startup');

  await initializeDateFormatting();

  try {
    await dotenv.load(fileName: 'assets/public.env');
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  await EnvConfig.loadAccountConfig(prefs);
  await SupabaseConfig.init();
  final savedLanguage = prefs.getString(AppStrings.localeStorageKey);
  final initialLocale = savedLanguage == null
      ? WidgetsBinding.instance.platformDispatcher.locale
      : Locale(savedLanguage);
  AppStrings.setLocale(AppStrings.resolveLocale(initialLocale));

  await AppTheme.init();
  await VehiclePrefs.init();
  await ServiceProfilePrefs.init();
  await PreviewPrefs.init();

  await setupServiceLocator();

  // Watches the session so a signed-in driver's route history follows the
  // account rather than the handset. Best-effort and off the startup path —
  // the planner never waits on it.
  sl<SavedRoutesSyncService>().start();
  sl<DispatchService>().start();

  await MapCacheService.init();

  ShareIntentHandler.init();
}

/// Draw the animated splash while the services initialize. Once they are
/// ready, build the app behind it; the splash handles the location gate and
/// then fades away without waiting for its road animation to finish.
class _StartupCoordinator extends StatefulWidget {
  const _StartupCoordinator({required this.startup});

  final Future<void> startup;

  @override
  State<_StartupCoordinator> createState() => _StartupCoordinatorState();
}

class _StartupCoordinatorState extends State<_StartupCoordinator> {
  bool _ready = false;
  bool _leaving = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    widget.startup.then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _finishSplash() {
    if (_leaving) return;
    setState(() => _leaving = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        if (_ready) const LaffahApp(showSplash: false),
        if (_showSplash)
          AnimatedOpacity(
            opacity: _leaving ? 0 : 1,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            onEnd: () {
              if (_leaving && mounted) setState(() => _showSplash = false);
            },
            child: IgnorePointer(
              ignoring: _leaving,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: SplashPage(
                  startup: widget.startup,
                  onFinished: _finishSplash,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
