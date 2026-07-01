import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/vehicle_prefs.dart';
import 'core/utils/debug_log.dart';
import 'core/utils/share_intent_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  DebugLog.banner('laffeh startup');

  await initializeDateFormatting();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString(AppStrings.localeStorageKey);
  final initialLocale = savedLanguage == null
      ? WidgetsBinding.instance.platformDispatcher.locale
      : Locale(savedLanguage);
  AppStrings.setLocale(AppStrings.resolveLocale(initialLocale));

  // Restore the saved driver theme before first paint.
  await AppTheme.init();
  await VehiclePrefs.init();

  await setupServiceLocator();

  ShareIntentHandler.init();

  runApp(const LaffahApp());
}
