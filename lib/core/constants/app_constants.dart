import 'dart:ui';

import 'package:flutter/foundation.dart';

/// User-facing copy for the app.
///
/// The app currently uses a lightweight localization layer instead of
/// generated ARB files so existing cubits/repositories can keep reading
/// strings without a BuildContext. The active language is set by
/// `MaterialApp.localeResolutionCallback` in `app.dart`.
class AppStrings {
  AppStrings._();

  static const supportedLocales = [Locale('en'), Locale('ar'), Locale('fr')];

  static const _supportedCodes = {'en', 'ar', 'fr'};
  static const afdalWebsiteUrl = 'https://www.afdal.tech/';
  static const localeStorageKey = 'laffeh.language_code';
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('en'),
  );

  static String _languageCode = 'en';

  static String get languageCode => _languageCode;
  static bool get isArabic => _languageCode == 'ar';

  static Locale resolveLocale(Locale? locale) {
    final code = locale?.languageCode.toLowerCase();
    return Locale(_supportedCodes.contains(code) ? code! : 'en');
  }

  static void setLocale(Locale locale) {
    final resolved = resolveLocale(locale);
    _languageCode = resolved.languageCode;
    if (localeNotifier.value.languageCode != resolved.languageCode) {
      localeNotifier.value = resolved;
    }
  }

  static String _t(String key) {
    return _copy[_languageCode]?[key] ?? _copy['en']![key] ?? key;
  }

  // App
  static String get appName => _t('appName');
  static String get appTagline => _t('appTagline');

  // Map / Planner
  static String get planRouteTitle => _t('planRouteTitle');
  static String get routePointsTitle => _t('routePointsTitle');
  static String get bestRouteTitle => _t('bestRouteTitle');
  static String get tapToAddPoint => _t('tapToAddPoint');
  static String get panToAddPoint => _t('panToAddPoint');
  static String get noPointsYet => _t('noPointsYet');
  static String get departure => _t('departure');
  static String get returnPoint => _t('returnPoint');
  static String get stop => _t('stop');
  static String get yourLocation => _t('yourLocation');
  static String get vehicle => _t('vehicle');

  // CTAs
  static String get optimizeRoute => _t('optimizeRoute');
  static String get startNewRoute => _t('startNewRoute');
  static String get clearAll => _t('clearAll');
  static String get clearRouteConfirm => _t('clearRouteConfirm');
  static String get showGo => _t('showGo');
  static String get showReturn => _t('showReturn');
  static String get showFull => _t('showFull');
  static String get rename => _t('rename');
  static String get remove => _t('remove');
  static String get removePointTitle => _t('removePointTitle');
  static String get setAsDeparture => _t('setAsDeparture');
  static String get cancel => _t('cancel');
  static String get save => _t('save');
  static String get retry => _t('retry');
  static String get close => _t('close');

  // Metrics
  static String get estimatedTime => _t('estimatedTime');
  static String get totalDistance => _t('totalDistance');
  static String get savings => _t('savings');
  static String get fuelEstimate => _t('fuelEstimate');
  static String get savedDistance => _t('savedDistance');
  static String get savedTime => _t('savedTime');
  static String get unavailable => _t('unavailable');

  // Errors / status
  static String get errMinTwoPoints => _t('errMinTwoPoints');
  static String get errLocationUnavailable => _t('errLocationUnavailable');
  static String get errOptimize => _t('errOptimize');
  static String get errNoInternet => _t('errNoInternet');
  static String get errCannotDrawRoute => _t('errCannotDrawRoute');
  static String get errLocationPermissionDenied =>
      _t('errLocationPermissionDenied');
  static String get errLocationServiceDisabled =>
      _t('errLocationServiceDisabled');
  static String get errInvalidResponse => _t('errInvalidResponse');
  static String get errEmptyOptimizedRoute => _t('errEmptyOptimizedRoute');
  static String get errTimeout => _t('errTimeout');
  static String get errServerConnection => _t('errServerConnection');
  static String get errRouteOptimizationFailed =>
      _t('errRouteOptimizationFailed');
  static String get errOneDepotRequired => _t('errOneDepotRequired');
  static String get errMinOneStopAfterDepot => _t('errMinOneStopAfterDepot');
  static String get errLocalStorageWrite => _t('errLocalStorageWrite');
  static String get errSavedRoutesLoad => _t('errSavedRoutesLoad');
  static String get errSavedRouteSave => _t('errSavedRouteSave');
  static String get errGeneric => _t('errGeneric');
  static String get errSaveRoute => _t('errSaveRoute');

  // Empty states
  static String get emptyPointsHint => _t('emptyPointsHint');
  static String get startCreatingRoute => _t('startCreatingRoute');
  static String get addDepartureHint => _t('addDepartureHint');
  static String get addStopsHint => _t('addStopsHint');
  static String get optimizeHint => _t('optimizeHint');
  static String get addMapCenterAction => _t('addMapCenterAction');
  static String get pasteListAction => _t('pasteListAction');
  static String get setDepartureFirst => _t('setDepartureFirst');
  static String get addOneStopToOptimize => _t('addOneStopToOptimize');
  static String get readyToOptimize => _t('readyToOptimize');
  static String get routeReadyHint => _t('routeReadyHint');
  static String get saveRouteAction => _t('saveRouteAction');

  // Splash
  static String get initializing => _t('initializing');
  static String get poweredBy => _t('poweredBy');

  // Simulation
  static String get simulationTitle => _t('simulationTitle');
  static String get startSimulation => _t('startSimulation');
  static String get playSimulation => _t('playSimulation');
  static String get pauseSimulation => _t('pauseSimulation');
  static String get resumeSimulation => _t('resumeSimulation');
  static String get resetSimulation => _t('resetSimulation');
  static String get exitSimulation => _t('exitSimulation');
  static const simSpeedHalfX = 'x0.5';
  static const simSpeed1x = 'x1';
  static const simSpeed2x = 'x2';
  static const simSpeed4x = 'x4';
  static String get speed => _t('speed');
  static String get cameraMode => _t('cameraMode');
  static String get cameraOverview => _t('cameraOverview');
  static String get cameraFollow => _t('cameraFollow');
  static String get cameraChase => _t('cameraChase');
  static String get headedTo => _t('headedTo');
  static String get departingFrom => _t('departingFrom');
  static String get arrived => _t('arrived');
  static String get progress => _t('progress');
  static String get remainingDistance => _t('remainingDistance');
  static String get remainingTime => _t('remainingTime');
  static String get simulationSubtitle => _t('simulationSubtitle');

  // Saved routes
  static String get savedRoutes => _t('savedRoutes');
  static String get savedRoutesEmpty => _t('savedRoutesEmpty');
  static String get savedRoutesEmptyHint => _t('savedRoutesEmptyHint');
  static String get saveRouteTitle => _t('saveRouteTitle');
  static String get saveRouteHint => _t('saveRouteHint');
  static String get defaultRouteName => _t('defaultRouteName');
  static String get askKeepCurrentRoute => _t('askKeepCurrentRoute');
  static String get saveAndContinue => _t('saveAndContinue');
  static String get discardAndContinue => _t('discardAndContinue');
  static String get dontSave => _t('dontSave');
  static String get saved => _t('saved');
  static String get routeSavedMsg => _t('routeSavedMsg');
  static String get deleteRouteTitle => _t('deleteRouteTitle');
  static String get deleteRouteConfirm => _t('deleteRouteConfirm');
  static String get renameRouteTitle => _t('renameRouteTitle');
  static String get openRoute => _t('openRoute');
  static String get sortNewest => _t('sortNewest');
  static String get clearSavedRoutesConfirm => _t('clearSavedRoutesConfirm');

  // Settings
  static String get settings => _t('settings');
  static String get about => _t('about');
  static String get apiBaseUrl => _t('apiBaseUrl');
  static String get officialWebsite => _t('officialWebsite');
  static String get visitWebsite => _t('visitWebsite');
  static String get aboutDescription => _t('aboutDescription');
  static String get language => _t('language');
  static String get languageEnglish => _t('languageEnglish');
  static String get languageArabic => _t('languageArabic');
  static String get languageFrench => _t('languageFrench');

  // Pin-to-center / paste / navigation
  static String get addPointHere => _t('addPointHere');
  static String get pasteAddresses => _t('pasteAddresses');
  static String get pasteAddressesHint => _t('pasteAddressesHint');
  static String get pasteAddressesPlaceholder =>
      _t('pasteAddressesPlaceholder');
  static String get addPoints => _t('addPoints');
  static String get searchingAddresses => _t('searchingAddresses');
  static String get navigateExternal => _t('navigateExternal');
  static String get sharedPointsLoaded => _t('sharedPointsLoaded');
  static String get startNavigation => _t('startNavigation');
  static String get navigationModeTitle => _t('navigationModeTitle');
  static String get navigationSubtitle => _t('navigationSubtitle');
  static String get stopNavigation => _t('stopNavigation');
  static String get openInGoogleMaps => _t('openInGoogleMaps');
  static String get nextStop => _t('nextStop');
  static String get liveLocation => _t('liveLocation');
  static String get importCsv => _t('importCsv');
  static String get exportCsv => _t('exportCsv');
  static String get csvImportEmpty => _t('csvImportEmpty');
  static String get csvImportFailed => _t('csvImportFailed');
  static String get csvExportFailed => _t('csvExportFailed');
  static String get csvNoPoints => _t('csvNoPoints');
  static String get csvShareText => _t('csvShareText');

  static String pointsAdded(int count) {
    switch (_languageCode) {
      case 'ar':
        return 'تمت إضافة $count نقطة';
      case 'fr':
        return '$count ${count == 1 ? 'point ajouté' : 'points ajoutés'}';
      default:
        return '$count ${count == 1 ? 'point added' : 'points added'}';
    }
  }

  // Trip flow (step indicator / overlays)
  static String get setDepartureHere => _t('setDepartureHere');
  static String get addStopHere => _t('addStopHere');
  static String get stepStops => _t('stepStops');
  static String get stepRoute => _t('stepRoute');
  static String get stepDrive => _t('stepDrive');
  static String get previewRoute => _t('previewRoute');
  static String get endTrip => _t('endTrip');
  static String get moreActions => _t('moreActions');
  static String get googleMapsShort => _t('googleMapsShort');
  static String get newRouteShort => _t('newRouteShort');
  static String get startFresh => _t('startFresh');
  static String get replay => _t('replay');

  static String stopNofM(int n, int m) {
    switch (_languageCode) {
      case 'ar':
        return 'محطة $n من $m';
      case 'fr':
        return 'Arret $n sur $m';
      default:
        return 'Stop $n of $m';
    }
  }

  // Small labels
  static String get departureBadge => _t('departureBadge');
  static String get returnBadge => _t('returnBadge');
  static String get routeOrder => _t('routeOrder');
  static String get points => _t('points');
  static String get dragToReorder => _t('dragToReorder');

  static String pointsCount(int count) {
    switch (_languageCode) {
      case 'ar':
        return '$count نقطة';
      case 'fr':
        return '$count ${count == 1 ? 'point' : 'points'}';
      default:
        return '$count ${count == 1 ? 'point' : 'points'}';
    }
  }

  static String stopLabel(int number) {
    switch (_languageCode) {
      case 'ar':
        return '$stop $number';
      case 'fr':
        return 'Arrêt $number';
      default:
        return 'Stop $number';
    }
  }

  static String routeSaveFailed([Object? error]) {
    if (error == null) return errSaveRoute;
    switch (_languageCode) {
      case 'ar':
        return '$errSaveRoute: $error';
      case 'fr':
        return '$errSaveRoute : $error';
      default:
        return '$errSaveRoute: $error';
    }
  }

  static String websiteOpenFailed(String url) {
    switch (_languageCode) {
      case 'ar':
        return 'تعذر فتح الموقع: $url';
      case 'fr':
        return 'Impossible d\'ouvrir le site : $url';
      default:
        return 'Could not open website: $url';
    }
  }
}

/// Unit suffix helpers.
class AppUnits {
  AppUnits._();

  static String get km => AppStrings._t('unitKm');
  static String get meter => AppStrings._t('unitMeter');
  static String get min => AppStrings._t('unitMin');
  static String get hour => AppStrings._t('unitHour');
  static String get liter => AppStrings._t('unitLiter');
}

const Map<String, Map<String, String>> _copy = {
  'en': {
    'appName': 'Laffeh',
    'appTagline': 'Your smarter route',
    'planRouteTitle': 'Plan your route',
    'routePointsTitle': 'Route points',
    'bestRouteTitle': 'Best route',
    'tapToAddPoint': 'Tap the map to add a point',
    'panToAddPoint': 'Move the map, then press + to add a point',
    'noPointsYet':
        'No points selected yet. Start with the departure point, then add destinations.',
    'departure': 'Departure point',
    'returnPoint': 'Return point',
    'stop': 'Stop',
    'yourLocation': 'Your location',
    'vehicle': 'Vehicle',
    'optimizeRoute': 'Optimize route',
    'startNewRoute': 'Start a new route',
    'clearAll': 'Clear all',
    'clearRouteConfirm': 'All current points will be removed from the map.',
    'showGo': 'Show outbound',
    'showReturn': 'Show return',
    'showFull': 'Full route',
    'rename': 'Rename',
    'remove': 'Delete',
    'setAsDeparture': 'Set as departure',
    'cancel': 'Cancel',
    'save': 'Save',
    'retry': 'Retry',
    'close': 'Close',
    'estimatedTime': 'Estimated time',
    'totalDistance': 'Total distance',
    'savings': 'Savings',
    'fuelEstimate': 'Estimated fuel use',
    'savedDistance': 'Distance saved',
    'savedTime': 'Time saved',
    'unavailable': 'Unavailable from server',
    'errMinTwoPoints': 'Please select at least two points',
    'errLocationUnavailable': 'Could not determine your current location',
    'errOptimize': 'An error occurred while optimizing the route',
    'errNoInternet': 'Check your internet connection',
    'errCannotDrawRoute': 'The route cannot be drawn right now',
    'errLocationPermissionDenied':
        'Location permission was denied. Please allow access in device settings.',
    'errLocationServiceDisabled':
        'Location service is disabled. Please enable GPS and try again.',
    'errInvalidResponse': 'Invalid response from the server',
    'errEmptyOptimizedRoute': 'The model did not return an optimized route',
    'errTimeout': 'The server connection timed out',
    'errServerConnection': 'Could not connect to the server',
    'errRouteOptimizationFailed': 'Route optimization failed',
    'errOneDepotRequired': 'Exactly one departure point is required',
    'errMinOneStopAfterDepot':
        'Please choose at least one destination after the departure point',
    'errLocalStorageWrite': 'Could not write to local storage',
    'errSavedRoutesLoad': 'Could not load saved routes',
    'errSavedRouteSave': 'Could not save route',
    'removePointTitle': 'Remove this point?',
    'errGeneric': 'Something went wrong',
    'errSaveRoute': 'Could not save route',
    'emptyPointsHint': 'Start by adding points on the map',
    'startCreatingRoute': 'Start creating your route',
    'addDepartureHint': '1. Move the map and press + to set departure',
    'addStopsHint': '2. Add more stops the same way, or paste addresses',
    'optimizeHint': 'Tap Optimize route and the AI will handle the rest',
    'addMapCenterAction': 'Add map center',
    'pasteListAction': 'Paste a list',
    'setDepartureFirst': 'Set your departure point first',
    'addOneStopToOptimize': 'Add at least one stop to optimize',
    'readyToOptimize': 'Ready to optimize',
    'routeReadyHint': 'Review, simulate, save, or open your route.',
    'saveRouteAction': 'Save route',
    'initializing': 'Preparing...',
    'poweredBy': 'Powered by',
    'simulationTitle': 'Route simulation',
    'startSimulation': 'Start simulation',
    'playSimulation': 'Play',
    'pauseSimulation': 'Pause',
    'resumeSimulation': 'Resume',
    'resetSimulation': 'Reset',
    'exitSimulation': 'Exit simulation',
    'speed': 'Speed',
    'cameraMode': 'Camera mode',
    'cameraOverview': 'Overview',
    'cameraFollow': 'Follow',
    'cameraChase': 'Cinematic',
    'headedTo': 'Heading to',
    'departingFrom': 'Departing from',
    'arrived': 'Arrived!',
    'progress': 'Progress',
    'remainingDistance': 'Remaining distance',
    'remainingTime': 'Remaining time',
    'simulationSubtitle': 'Watch your route from start to finish',
    'savedRoutes': 'My routes',
    'savedRoutesEmpty': 'No saved routes yet',
    'savedRoutesEmptyHint':
        'After optimizing a route, you can save it here and come back to it later.',
    'saveRouteTitle': 'Save route',
    'saveRouteHint': 'Choose a memorable name for the route',
    'defaultRouteName': 'New route',
    'askKeepCurrentRoute': 'Save the current route before starting over?',
    'saveAndContinue': 'Save',
    'discardAndContinue': 'Do not save',
    'dontSave': 'Do not save',
    'saved': 'Saved',
    'routeSavedMsg': 'Route saved to My routes',
    'deleteRouteTitle': 'Delete route',
    'deleteRouteConfirm': 'Do you want to delete this route permanently?',
    'renameRouteTitle': 'Rename route',
    'openRoute': 'Open route',
    'sortNewest': 'Newest',
    'clearSavedRoutesConfirm':
        'All saved routes will be deleted. Are you sure?',
    'settings': 'Settings',
    'about': 'About',
    'apiBaseUrl': 'AI API URL',
    'officialWebsite': 'Official website',
    'visitWebsite': 'Visit website',
    'language': 'Language',
    'languageEnglish': 'English',
    'languageArabic': 'Arabic',
    'languageFrench': 'French',
    'aboutDescription':
        'A smart app for optimizing delivery routes and daily visits using Afdal Vehicle Routing optimization, with a full route simulation after results are ready.',
    'addPointHere': 'Add point here',
    'pasteAddresses': 'Paste addresses',
    'pasteAddressesHint':
        'Paste one address per line. Each will be geocoded and placed on the map.',
    'pasteAddressesPlaceholder': 'Baker Street 221B\nOxford Road 10\n...',
    'addPoints': 'Add',
    'searchingAddresses': 'Searching addresses...',
    'navigateExternal': 'Open in navigation',
    'sharedPointsLoaded': 'Shared points loaded on the map',
    'startNavigation': 'Start driving',
    'navigationModeTitle': 'Live route',
    'navigationSubtitle': 'Follow your real GPS location on this route',
    'stopNavigation': 'End driving',
    'openInGoogleMaps': 'Open in Google Maps',
    'nextStop': 'Next stop',
    'liveLocation': 'Live location',
    'importCsv': 'Import CSV',
    'exportCsv': 'Export CSV',
    'csvImportEmpty': 'No route points were found in this CSV file',
    'csvImportFailed': 'Could not import CSV file',
    'csvExportFailed': 'Could not export CSV file',
    'csvNoPoints': 'No points to export',
    'csvShareText': 'Laffeh route CSV',
    'departureBadge': 'Start',
    'returnBadge': 'Return',
    'routeOrder': 'Route order',
    'points': 'points',
    'dragToReorder': 'drag to reorder',
    'unitKm': 'km',
    'unitMeter': 'm',
    'unitMin': 'min',
    'unitHour': 'h',
    'unitLiter': 'L',
    'setDepartureHere': 'Set departure here',
    'addStopHere': 'Add stop here',
    'stepStops': 'Stops',
    'stepRoute': 'Route',
    'stepDrive': 'Drive',
    'previewRoute': 'Preview trip',
    'endTrip': 'End trip',
    'moreActions': 'More',
    'googleMapsShort': 'Maps',
    'newRouteShort': 'New',
    'startFresh': 'Delete trip & start fresh',
    'replay': 'Replay',
  },
  'ar': {
    'appName': 'لفّة',
    'appTagline': 'مسارك الأذكى',
    'planRouteTitle': 'خطط مسارك',
    'routePointsTitle': 'نقاط المسار',
    'bestRouteTitle': 'إيجاد المسار الأفضل ',
    'tapToAddPoint': 'اضغط على الخريطة لإضافة نقطة',
    'panToAddPoint': 'حرّك الخريطة ثم اضغط + لإضافة نقطة',
    'noPointsYet':
        'لم تختر أي نقطة بعد. ابدأ بتحديد نقطة الانطلاق ثم أضف الوجهات.',
    'departure': 'نقطة الانطلاق',
    'returnPoint': 'نقطة العودة',
    'stop': 'نقطة',
    'yourLocation': 'موقعك الحالي',
    'vehicle': 'المركبة',
    'optimizeRoute': 'تحسين المسار',
    'startNewRoute': 'لفة جديدة',
    'clearAll': 'مسح الكل',
    'clearRouteConfirm': 'سيتم حذف كل النقاط الحالية من الخريطة.',
    'showGo': 'الذهاب',
    'showReturn': 'العودة',
    'showFull': 'الكامل',
    'rename': 'إعادة تسمية',
    'remove': 'حذف',
    'setAsDeparture': 'تعيين كنقطة انطلاق',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'retry': 'إعادة المحاولة',
    'close': 'إغلاق',
    'estimatedTime': 'الوقت المتوقع',
    'totalDistance': 'إجمالي المسافة',
    'savings': 'التوفير',
    'fuelEstimate': 'استهلاك الوقود التقريبي',
    'savedDistance': 'مسافة موفّرة',
    'savedTime': 'وقت موفّر',
    'unavailable': 'غير متاح من الخادم',
    'errMinTwoPoints': 'يرجى اختيار نقطتين على الأقل',
    'errLocationUnavailable': 'تعذر تحديد موقعك الحالي',
    'errOptimize': 'حدث خطأ أثناء تحسين المسار',
    'errNoInternet': 'تحقق من الاتصال بالإنترنت',
    'errCannotDrawRoute': 'لا يمكن رسم المسار حالياً',
    'errLocationPermissionDenied':
        'تم رفض إذن الموقع. الرجاء السماح بالوصول من إعدادات الجهاز.',
    'errLocationServiceDisabled':
        'خدمة الموقع غير مفعّلة. يرجى تفعيل GPS وإعادة المحاولة.',
    'errInvalidResponse': 'استجابة غير صالحة من الخادم',
    'errEmptyOptimizedRoute': 'لم يُرجِع النموذج أي مسار مُحسَّن',
    'errTimeout': 'انتهت مهلة الاتصال بالخادم',
    'errServerConnection': 'تعذر الاتصال بالخادم',
    'errRouteOptimizationFailed': 'فشل تحسين المسار',
    'errOneDepotRequired': 'يجب تحديد نقطة انطلاق واحدة فقط',
    'errMinOneStopAfterDepot':
        'يرجى اختيار وجهة واحدة على الأقل بعد نقطة الانطلاق',
    'errLocalStorageWrite': 'تعذر الكتابة إلى التخزين المحلي',
    'errSavedRoutesLoad': 'تعذر تحميل المسارات المحفوظة',
    'errSavedRouteSave': 'تعذر حفظ المسار',
    'removePointTitle': 'حذف هذه النقطة؟',
    'errGeneric': 'حدث خطأ',
    'errSaveRoute': 'تعذر حفظ المسار',
    'emptyPointsHint': 'ابدأ بإضافة نقاط على الخريطة',
    'startCreatingRoute': 'ابدأ بإنشاء مسارك',
    'addDepartureHint': '1. حرّك الخريطة واضغط + لتحديد نقطة الانطلاق',
    'addStopsHint': '2. أضف نقاط أخرى بنفس الطريقة، أو الصق عناوين',
    'optimizeHint': 'اضغط تحسين المسار والذكاء الاصطناعي بيتكفّل بالباقي',
    'addMapCenterAction': 'إضافة مركز الخريطة',
    'pasteListAction': 'لصق قائمة',
    'setDepartureFirst': 'حدد نقطة الانطلاق أولاً',
    'addOneStopToOptimize': 'أضف وجهة واحدة على الأقل للتحسين',
    'readyToOptimize': 'جاهز لتحسين المسار',
    'routeReadyHint': 'راجع المسار، شغّل المحاكاة، احفظه، أو افتحه في الملاحة.',
    'saveRouteAction': 'حفظ المسار',
    'initializing': 'جاري التحضير...',
    'poweredBy': 'مدعوم من',
    'simulationTitle': 'محاكاة المسار',
    'startSimulation': 'تشغيل المحاكاة',
    'playSimulation': 'تشغيل',
    'pauseSimulation': 'إيقاف مؤقت',
    'resumeSimulation': 'استئناف',
    'resetSimulation': 'إعادة',
    'exitSimulation': 'إنهاء المحاكاة',
    'speed': 'السرعة',
    'cameraMode': 'وضع الكاميرا',
    'cameraOverview': 'بانورامي',
    'cameraFollow': 'متابعة',
    'cameraChase': 'سينمائي',
    'headedTo': 'متجه إلى',
    'departingFrom': 'الانطلاق من',
    'arrived': 'وصلنا!',
    'progress': 'التقدّم',
    'remainingDistance': 'المسافة المتبقية',
    'remainingTime': 'الوقت المتبقي',
    'simulationSubtitle': 'شاهد مسارك من البداية للنهاية',
    'savedRoutes': 'مساراتي',
    'savedRoutesEmpty': 'لا توجد مسارات محفوظة بعد',
    'savedRoutesEmptyHint':
        'بعد ما تحسّن مسار، تقدر تحفظه هنا للرجوع له لاحقاً',
    'saveRouteTitle': 'حفظ المسار',
    'saveRouteHint': 'اختر اسماً مميزاً للمسار',
    'defaultRouteName': 'مسار جديد',
    'askKeepCurrentRoute': 'حفظ المسار الحالي قبل البدء من جديد؟',
    'saveAndContinue': 'حفظ',
    'discardAndContinue': 'بدون حفظ',
    'dontSave': 'بدون حفظ',
    'saved': 'تم الحفظ',
    'routeSavedMsg': 'تم حفظ المسار في مساراتي',
    'deleteRouteTitle': 'حذف المسار',
    'deleteRouteConfirm': 'هل تريد حذف هذا المسار نهائياً؟',
    'renameRouteTitle': 'إعادة تسمية المسار',
    'openRoute': 'فتح المسار',
    'sortNewest': 'الأحدث',
    'clearSavedRoutesConfirm': 'سيتم حذف كل المسارات المحفوظة. هل أنت متأكد؟',
    'settings': 'الإعدادات',
    'about': 'عن التطبيق',
    'apiBaseUrl': 'عنوان واجهة الذكاء الاصطناعي',
    'officialWebsite': 'الموقع الرسمي',
    'visitWebsite': 'زيارة الموقع',
    'language': 'اللغة',
    'languageEnglish': 'الإنجليزية',
    'languageArabic': 'العربية',
    'languageFrench': 'الفرنسية',
    'aboutDescription':
        'تطبيق ذكي لتحسين مسارات التوصيل والزيارات اليومية باستخدام نموذج تحسين Vehicle Routing من Afdal، مع إمكانية محاكاة المسار كاملاً بعد ظهور النتيجة.',
    'addPointHere': 'أضف نقطة هنا',
    'pasteAddresses': 'لصق عناوين',
    'pasteAddressesHint':
        'الصق عنوان واحد بكل سطر. سيتم البحث عن كل عنوان ووضعه على الخريطة.',
    'pasteAddressesPlaceholder': 'شارع الملك عبدالله\nدوار الداخلية\n...',
    'addPoints': 'إضافة',
    'searchingAddresses': 'جاري البحث عن العناوين...',
    'navigateExternal': 'فتح في الملاحة',
    'sharedPointsLoaded': 'تم تحميل النقاط المشاركة على الخريطة',
    'startNavigation': 'ابدأ القيادة',
    'navigationModeTitle': 'قيادة المسار',
    'navigationSubtitle': 'تتبّع موقعك الحقيقي على هذا المسار',
    'stopNavigation': 'إنهاء القيادة',
    'openInGoogleMaps': 'فتح في Google Maps',
    'nextStop': 'النقطة التالية',
    'liveLocation': 'موقعك المباشر',
    'importCsv': 'استيراد CSV',
    'exportCsv': 'تصدير CSV',
    'csvImportEmpty': 'لم يتم العثور على نقاط ضمن ملف CSV',
    'csvImportFailed': 'تعذر استيراد ملف CSV',
    'csvExportFailed': 'تعذر تصدير ملف CSV',
    'csvNoPoints': 'لا توجد نقاط للتصدير',
    'csvShareText': 'مسار لفة بصيغة CSV',
    'departureBadge': 'انطلاق',
    'returnBadge': 'عودة',
    'routeOrder': 'ترتيب اللفة',
    'points': 'نقطة',
    'dragToReorder': 'اسحب لإعادة الترتيب',
    'unitKm': 'كم',
    'unitMeter': 'م',
    'unitMin': 'دقيقة',
    'unitHour': 'س',
    'unitLiter': 'لتر',
    'setDepartureHere': 'ثبّت الانطلاق هنا',
    'addStopHere': 'أضف محطة هنا',
    'stepStops': 'المحطات',
    'stepRoute': 'المسار',
    'stepDrive': 'القيادة',
    'previewRoute': 'معاينة اللفة',
    'endTrip': 'إنهاء الرحلة',
    'moreActions': 'المزيد',
    'googleMapsShort': 'الخرائط',
    'newRouteShort': 'جديدة',
    'startFresh': 'احذف اللفة وابدأ من جديد',
    'replay': 'إعادة التشغيل',
  },
  'fr': {
    'appName': 'Laffeh',
    'appTagline': 'Votre itineraire plus intelligent',
    'planRouteTitle': 'Planifiez votre itineraire',
    'routePointsTitle': 'Points du trajet',
    'bestRouteTitle': 'Meilleur itineraire',
    'tapToAddPoint': 'Touchez la carte pour ajouter un point',
    'panToAddPoint':
        'Deplacez la carte puis appuyez sur + pour ajouter un point',
    'noPointsYet':
        'Aucun point selectionne. Commencez par le point de depart, puis ajoutez les destinations.',
    'departure': 'Point de depart',
    'returnPoint': 'Point de retour',
    'stop': 'Arret',
    'yourLocation': 'Votre position',
    'vehicle': 'Vehicule',
    'optimizeRoute': 'Optimiser',
    'startNewRoute': 'Demarrer un nouveau trajet',
    'clearAll': 'Tout effacer',
    'clearRouteConfirm': 'Tous les points actuels seront retires de la carte.',
    'showGo': 'Afficher l\'aller',
    'showReturn': 'Afficher le retour',
    'showFull': 'Trajet complet',
    'rename': 'Renommer',
    'remove': 'Supprimer',
    'setAsDeparture': 'Definir comme depart',
    'cancel': 'Annuler',
    'save': 'Enregistrer',
    'retry': 'Reessayer',
    'close': 'Fermer',
    'estimatedTime': 'Temps estime',
    'totalDistance': 'Distance totale',
    'savings': 'Economies',
    'fuelEstimate': 'Carburant estime',
    'savedDistance': 'Distance economisee',
    'savedTime': 'Temps gagne',
    'unavailable': 'Indisponible depuis le serveur',
    'errMinTwoPoints': 'Veuillez selectionner au moins deux points',
    'errLocationUnavailable':
        'Impossible de determiner votre position actuelle',
    'errOptimize': 'Une erreur est survenue pendant l\'optimisation du trajet',
    'errNoInternet': 'Verifiez votre connexion Internet',
    'errCannotDrawRoute': 'Impossible de tracer le trajet pour le moment',
    'errLocationPermissionDenied':
        'L\'autorisation de localisation a ete refusee. Veuillez l\'activer dans les reglages.',
    'errLocationServiceDisabled':
        'Le service de localisation est desactive. Activez le GPS puis reessayez.',
    'errInvalidResponse': 'Reponse invalide du serveur',
    'errEmptyOptimizedRoute':
        'Le modele n\'a renvoye aucun itineraire optimise',
    'errTimeout': 'La connexion au serveur a expire',
    'errServerConnection': 'Impossible de se connecter au serveur',
    'errRouteOptimizationFailed': 'Echec de l\'optimisation du trajet',
    'errOneDepotRequired': 'Un seul point de depart est requis',
    'errMinOneStopAfterDepot':
        'Veuillez choisir au moins une destination apres le point de depart',
    'errLocalStorageWrite': 'Impossible d\'ecrire dans le stockage local',
    'errSavedRoutesLoad': 'Impossible de charger les trajets enregistres',
    'errSavedRouteSave': 'Impossible d\'enregistrer le trajet',
    'removePointTitle': 'Supprimer ce point ?',
    'errGeneric': 'Une erreur est survenue',
    'errSaveRoute': 'Impossible d\'enregistrer le trajet',
    'emptyPointsHint': 'Commencez par ajouter des points sur la carte',
    'startCreatingRoute': 'Commencez a creer votre trajet',
    'addDepartureHint':
        '1. Deplacez la carte et appuyez sur + pour definir le depart',
    'addStopsHint':
        '2. Ajoutez d\'autres arrets de la meme maniere, ou collez des adresses',
    'optimizeHint': 'Touchez Optimiser et l\'IA s\'occupe du reste',
    'addMapCenterAction': 'Ajouter le centre',
    'pasteListAction': 'Coller une liste',
    'setDepartureFirst': 'Definissez d\'abord le depart',
    'addOneStopToOptimize': 'Ajoutez au moins un arret pour optimiser',
    'readyToOptimize': 'Pret a optimiser',
    'routeReadyHint': 'Verifiez, simulez, enregistrez ou ouvrez votre trajet.',
    'saveRouteAction': 'Enregistrer',
    'initializing': 'Preparation...',
    'poweredBy': 'Propulse par',
    'simulationTitle': 'Simulation du trajet',
    'startSimulation': 'Lancer la simulation',
    'playSimulation': 'Lire',
    'pauseSimulation': 'Pause',
    'resumeSimulation': 'Reprendre',
    'resetSimulation': 'Reinitialiser',
    'exitSimulation': 'Quitter la simulation',
    'speed': 'Vitesse',
    'cameraMode': 'Mode camera',
    'cameraOverview': 'Vue globale',
    'cameraFollow': 'Suivi',
    'cameraChase': 'Cinematique',
    'headedTo': 'Direction',
    'departingFrom': 'Depart de',
    'arrived': 'Arrive!',
    'progress': 'Progression',
    'remainingDistance': 'Distance restante',
    'remainingTime': 'Temps restant',
    'simulationSubtitle': 'Visualisez votre trajet du debut a la fin',
    'savedRoutes': 'Mes trajets',
    'savedRoutesEmpty': 'Aucun trajet enregistre',
    'savedRoutesEmptyHint':
        'Apres avoir optimise un trajet, vous pouvez l\'enregistrer ici et y revenir plus tard.',
    'saveRouteTitle': 'Enregistrer le trajet',
    'saveRouteHint': 'Choisissez un nom facile a reconnaitre',
    'defaultRouteName': 'Nouveau trajet',
    'askKeepCurrentRoute':
        'Enregistrer le trajet actuel avant de recommencer ?',
    'saveAndContinue': 'Enregistrer',
    'discardAndContinue': 'Ne pas enregistrer',
    'dontSave': 'Ne pas enregistrer',
    'saved': 'Enregistre',
    'routeSavedMsg': 'Trajet enregistre dans Mes trajets',
    'deleteRouteTitle': 'Supprimer le trajet',
    'deleteRouteConfirm': 'Voulez-vous supprimer definitivement ce trajet ?',
    'renameRouteTitle': 'Renommer le trajet',
    'openRoute': 'Ouvrir le trajet',
    'sortNewest': 'Plus recent',
    'clearSavedRoutesConfirm':
        'Tous les trajets enregistres seront supprimes. Etes-vous sur ?',
    'settings': 'Parametres',
    'about': 'A propos',
    'apiBaseUrl': 'URL de l\'API IA',
    'officialWebsite': 'Site officiel',
    'visitWebsite': 'Visiter le site',
    'language': 'Langue',
    'languageEnglish': 'Anglais',
    'languageArabic': 'Arabe',
    'languageFrench': 'Francais',
    'aboutDescription':
        'Une application intelligente pour optimiser les tournees de livraison et les visites quotidiennes avec l\'optimisation Vehicle Routing d\'Afdal, avec une simulation complete du trajet une fois le resultat pret.',
    'addPointHere': 'Ajouter un point ici',
    'pasteAddresses': 'Coller des adresses',
    'pasteAddressesHint':
        'Collez une adresse par ligne. Chacune sera geocodee et placee sur la carte.',
    'pasteAddressesPlaceholder':
        'Rue de Rivoli 10\nAvenue des Champs-Elysees\n...',
    'addPoints': 'Ajouter',
    'searchingAddresses': 'Recherche des adresses...',
    'navigateExternal': 'Ouvrir dans la navigation',
    'sharedPointsLoaded': 'Points partages charges sur la carte',
    'startNavigation': 'Demarrer la conduite',
    'navigationModeTitle': 'Conduite du trajet',
    'navigationSubtitle': 'Suivez votre position GPS reelle sur ce trajet',
    'stopNavigation': 'Arreter la conduite',
    'openInGoogleMaps': 'Ouvrir dans Google Maps',
    'nextStop': 'Prochain arret',
    'liveLocation': 'Position en direct',
    'importCsv': 'Importer CSV',
    'exportCsv': 'Exporter CSV',
    'csvImportEmpty': 'Aucun point trouve dans ce fichier CSV',
    'csvImportFailed': 'Impossible d\'importer le fichier CSV',
    'csvExportFailed': 'Impossible d\'exporter le fichier CSV',
    'csvNoPoints': 'Aucun point a exporter',
    'csvShareText': 'Trajet Laffeh au format CSV',
    'departureBadge': 'Depart',
    'returnBadge': 'Retour',
    'routeOrder': 'Ordre du trajet',
    'points': 'points',
    'dragToReorder': 'glissez pour reordonner',
    'unitKm': 'km',
    'unitMeter': 'm',
    'unitMin': 'min',
    'unitHour': 'h',
    'unitLiter': 'L',
    'setDepartureHere': 'Definir le depart ici',
    'addStopHere': 'Ajouter un arret ici',
    'stepStops': 'Arrets',
    'stepRoute': 'Itineraire',
    'stepDrive': 'Conduite',
    'previewRoute': 'Apercu du trajet',
    'endTrip': 'Terminer le trajet',
    'moreActions': 'Plus',
    'googleMapsShort': 'Maps',
    'newRouteShort': 'Nouveau',
    'startFresh': 'Supprimer le trajet et recommencer',
    'replay': 'Rejouer',
  },
};
