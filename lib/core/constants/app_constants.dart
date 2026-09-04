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
  static const onboardingDoneKey = 'laffeh.onboarding_done';

  // Auth / onboarding / tracking storage keys.
  static const deviceIdKey = 'laffeh.device_id';
  static const welcomeSeenKey = 'laffeh.welcome_seen';
  static const nudgeLaunchesKey = 'laffeh.account_nudge_launches';
  static const nudgeLastShownKey = 'laffeh.account_nudge_last_shown';
  static const nudgeDismissedKey = 'laffeh.account_nudge_dismissed';
  static const registrationSkippedAtKey = 'laffeh.registration_skipped_at';
  static const termsVersionKey = 'laffeh.terms_version';
  static const termsAcceptedAtKey = 'laffeh.terms_accepted_at';
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
  static String get removePointBody => _t('removePointBody');
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
  static String get enableLocationCta => _t('enableLocationCta');

  /// The splash's location gate — shown when access is missing on the way in.
  static String get locGateTitle => _t('locGateTitle');
  static String get locGateBody => _t('locGateBody');
  static String get locGateBlockedBody => _t('locGateBlockedBody');
  static String get locGateContinue => _t('locGateContinue');

  /// Per-stop contact + the confirmation shown when a point lands.
  static String get pointAdded => _t('pointAdded');
  static String get stopPhoneTitle => _t('stopPhoneTitle');
  static String get stopPhoneHint => _t('stopPhoneHint');
  static String get stopPhoneAdd => _t('stopPhoneAdd');
  static String get stopPhoneEdit => _t('stopPhoneEdit');
  static String get stopCall => _t('stopCall');
  static String get stopWhatsapp => _t('stopWhatsapp');
  // Reaching the stop from inside the drive.
  static String get stopWhatsappOnTheWay => _t('stopWhatsappOnTheWay');
  static String get stopWhatsappArrived => _t('stopWhatsappArrived');
  static String get stopCallFailed => _t('stopCallFailed');
  static String get errInvalidResponse => _t('errInvalidResponse');
  static String get errEmptyOptimizedRoute => _t('errEmptyOptimizedRoute');
  static String get errTimeout => _t('errTimeout');

  /// Shown when a .laffa round cannot be read at all — as opposed to a
  /// format problem, which the parser describes in its own words.
  static String get errLaffaUnreadable => _t('errLaffaUnreadable');
  static String get laffaReplaceTitle => _t('laffaReplaceTitle');
  static String get laffaReplaceMessage => _t('laffaReplaceMessage');
  static String get laffaReplaceConfirm => _t('laffaReplaceConfirm');

  /// Confirmation after a round file is opened.
  static String laffaImported(int stops) =>
      _t('laffaImported').replaceFirst('{n}', '$stops');
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
  static String get recenter => _t('recenter');
  static String get resetView => _t('resetView');
  static String get headedTo => _t('headedTo');
  static String get departingFrom => _t('departingFrom');
  static String get arrived => _t('arrived');
  static String get progress => _t('progress');
  static String get remainingDistance => _t('remainingDistance');
  static String get remainingTime => _t('remainingTime');
  static String get focusMode => _t('focusMode');
  static String get driveControls => _t('driveControls');
  static String get exitFocus => _t('exitFocus');
  static String get remainingShort => _t('remainingShort');
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
  static String get aboutUs => _t('aboutUs');
  static String get aboutDescription => _t('aboutDescription');
  static String get language => _t('language');
  static String get appearance => _t('appearance');
  static String get vehicleIcon => _t('vehicleIcon');
  static String get vehicleVwBus => _t('vehicleVwBus');
  static String get vehicleVespa => _t('vehicleVespa');
  static String get vehicleTaxi => _t('vehicleTaxi');
  static String get vehicleCamel => _t('vehicleCamel');
  static String get vehicleArrow => _t('vehicleArrow');
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
  static String get csvExportSuccess => _t('csvExportSuccess');

  // Optional points (#8) & point actions
  static String get optional => _t('optional');
  static String get optionalPoint => _t('optionalPoint');
  static String get markOptional => _t('markOptional');
  static String get markRequired => _t('markRequired');
  static String get activate => _t('activate');
  static String get deactivate => _t('deactivate');
  static String get activateStopTitle => _t('activateStopTitle');
  static String get activateStopMsg => _t('activateStopMsg');
  static String get reoptimizeNow => _t('reoptimizeNow');
  static String get skipStop => _t('skipStop');
  static String get includeStop => _t('includeStop');
  static String get optionalBadge => _t('optionalBadge');
  static String get deactivatedBadge => _t('deactivatedBadge');
  static String get addOptionalHere => _t('addOptionalHere');

  // Move point on map (#9)
  static String get moveOnMap => _t('moveOnMap');
  static String get movePointTitle => _t('movePointTitle');
  static String get movePointHint => _t('movePointHint');
  static String get saveLocation => _t('saveLocation');
  static String get locationUpdated => _t('locationUpdated');

  // Add-points UX (#12)
  static String get addStop => _t('addStop');
  static String get addOptionalStop => _t('addOptionalStop');
  static String get addByTap => _t('addByTap');
  static String get addMethods => _t('addMethods');
  static String get keepAddingHint => _t('keepAddingHint');

  // Offline / local-save (#10, #11)
  static String get offlineTitle => _t('offlineTitle');
  static String get offlineBody => _t('offlineBody');
  static String get offlineActionUnavailable => _t('offlineActionUnavailable');
  static String get draftRestoredMsg => _t('draftRestoredMsg');
  static String get savedLocallyNote => _t('savedLocallyNote');

  // Error (#4)
  static String get errNoActiveStops => _t('errNoActiveStops');
  static String get noAddressesFound => _t('noAddressesFound');

  /// Localized label for an optional stop, numbered separately from
  /// mandatory stops ("Optional 1", "نقطة اختيارية 1"…).
  static String optionalStopLabel(int number) {
    switch (_languageCode) {
      case 'ar':
        return 'نقطة اختيارية $number';
      case 'fr':
        return 'Arrêt optionnel $number';
      default:
        return 'Optional $number';
    }
  }

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
  static String get previewBadge => _t('previewBadge');
  static String get previewStartDrive => _t('previewStartDrive');
  static String get endTrip => _t('endTrip');
  static String get moreActions => _t('moreActions');
  static String get googleMapsShort => _t('googleMapsShort');
  static String get openWithMaps => _t('openWithMaps');
  static String get newRouteShort => _t('newRouteShort');
  static String get startFresh => _t('startFresh');
  static String get replay => _t('replay');

  // Drive mode — service points & turn guidance
  static String get pointServed => _t('pointServed');
  static String get rerouting => _t('rerouting');
  static String get reoptimize => _t('reoptimize');

  // ── Where the day ends ──
  static String get endOfDay => _t('endOfDay');
  static String get finishRoundTrip => _t('finishRoundTrip');
  static String get finishRoundTripHint => _t('finishRoundTripHint');
  static String get finishOpen => _t('finishOpen');
  static String get finishOpenHint => _t('finishOpenHint');
  static String get finishCustom => _t('finishCustom');
  static String get finishCustomHint => _t('finishCustomHint');
  static String get finishPointLabel => _t('finishPointLabel');
  static String get finishPickPlace => _t('finishPickPlace');
  static String get toLabel => _t('toLabel');
  static String get setFinishHere => _t('setFinishHere');
  static String get view3d => _t('view3d');
  static String get viewFlat => _t('viewFlat');
  static String finishEndsAt(String stop) =>
      _t('finishEndsAt').replaceFirst('{stop}', stop);
  static String get reCenter => _t('reCenter');
  static String get arrivalLabel => _t('arrivalLabel');
  static String get speedUnitKmh => _t('speedUnitKmh');
  static String get manTurnLeft => _t('manTurnLeft');
  static String get manTurnRight => _t('manTurnRight');
  static String get manSlightLeft => _t('manSlightLeft');
  static String get manSlightRight => _t('manSlightRight');
  static String get manSharpLeft => _t('manSharpLeft');
  static String get manSharpRight => _t('manSharpRight');
  static String get manUTurn => _t('manUTurn');
  static String get manStraight => _t('manStraight');
  static String get manMerge => _t('manMerge');
  static String get manKeepLeft => _t('manKeepLeft');
  static String get manKeepRight => _t('manKeepRight');
  static String get manOnRamp => _t('manOnRamp');
  static String get manOffRamp => _t('manOffRamp');
  static String get manRoundabout => _t('manRoundabout');
  static String get manArrive => _t('manArrive');

  static String manRoundaboutExit(int n) =>
      _t('manRoundaboutExit').replaceAll('{n}', '$n');

  static String continueToward(String stop) =>
      _t('continueToward').replaceAll('{stop}', stop);

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
  static String get arrivedHere => _t('arrivedHere');
  static String get departureBadge => _t('departureBadge');
  static String get returnBadge => _t('returnBadge');
  static String get routeOrder => _t('routeOrder');
  static String get points => _t('points');

  // Offline map pack
  static String get offlineMapTitle => _t('offlineMapTitle');
  static String get offlineMapIdleHint => _t('offlineMapIdleHint');
  static String get offlineMapNoTrip => _t('offlineMapNoTrip');
  static String get offlineMapDownloading => _t('offlineMapDownloading');
  static String get offlineMapReady => _t('offlineMapReady');
  static String get offlineMapPartial => _t('offlineMapPartial');
  static String get offlineMapFailed => _t('offlineMapFailed');
  static String get offlineMapDownload => _t('offlineMapDownload');
  static String get offlineMapRetry => _t('offlineMapRetry');
  static String get offlineMapCancel => _t('offlineMapCancel');
  static String get offlineMapDelete => _t('offlineMapDelete');
  static String get offlineMapNeedsConnection =>
      _t('offlineMapNeedsConnection');
  static String get offlineMapPreparing => _t('offlineMapPreparing');
  static String get offlineMapCancelling => _t('offlineMapCancelling');
  static String get offlineMapCancelled => _t('offlineMapCancelled');
  static String get offlineMapResume => _t('offlineMapResume');

  /// "42%" — the headline number during a download.
  static String percent(int value) =>
      _languageCode == 'ar' ? '$value٪' : '$value%';

  /// "4 of ~10 MB" — what has actually landed against what was promised,
  /// so the bar is never the only thing to go on. The unit is stated once:
  /// repeating it on both sides reads as two different measurements.
  static String offlineMapDownloadedOf(num doneMb, num totalMb) {
    final done = _mbNumber(doneMb);
    final total = approxMegabytes(totalMb);
    switch (_languageCode) {
      case 'ar':
        return '$done من $total';
      case 'fr':
        return '$done sur $total';
      default:
        return '$done of $total';
    }
  }

  /// "Part 3 of 12" — the reassurance that a long download is moving even
  /// while the megabyte counter sits still between boxes.
  static String offlineMapPartOf(int done, int total) {
    switch (_languageCode) {
      case 'ar':
        return 'الجزء $done من $total';
      case 'fr':
        return 'Partie $done sur $total';
      default:
        return 'Part $done of $total';
    }
  }

  // Offline map around the driver — no trip required.
  static String get offlineAreaTitle => _t('offlineAreaTitle');
  static String get offlineAreaHint => _t('offlineAreaHint');
  static String get offlineAreaNotSaved => _t('offlineAreaNotSaved');
  static String get offlineAreaUpdate => _t('offlineAreaUpdate');
  static String get offlineAreaNeedsLocation => _t('offlineAreaNeedsLocation');
  static String get offlineAreaDeleteTitle => _t('offlineAreaDeleteTitle');
  static String get offlineAreaDeleteMessage => _t('offlineAreaDeleteMessage');

  // Framing the area to save on the map.
  static String get offlineAreaPickTitle => _t('offlineAreaPickTitle');
  static String get offlineAreaPickHint => _t('offlineAreaPickHint');
  static String get offlineAreaMeasuring => _t('offlineAreaMeasuring');
  static String get offlineAreaTooLarge => _t('offlineAreaTooLarge');
  static String get offlineAreaMyLocation => _t('offlineAreaMyLocation');
  static String get offlineAreaSavedHere => _t('offlineAreaSavedHere');
  static String get offlineAreaAtCeiling => _t('offlineAreaAtCeiling');

  /// "You have 3 saved areas" — shown while the frame is somewhere new, so
  /// the driver knows the other maps are still there and that this download
  /// adds to them rather than replacing one.
  static String offlineAreaSavedCount(int count) {
    switch (_languageCode) {
      case 'ar':
        // MSA number agreement: 1 and 2 take the noun's own forms, 3–10 take
        // the plural, 11+ takes the singular again.
        final noun = switch (count) {
          1 => 'منطقة محفوظة',
          2 => 'منطقتان محفوظتان',
          >= 3 && <= 10 => 'مناطق محفوظة',
          _ => 'منطقة محفوظة',
        };
        return count <= 2 ? 'لديك $noun' : 'لديك $count $noun';
      case 'fr':
        return count == 1
            ? 'Vous avez 1 zone enregistree'
            : 'Vous avez $count zones enregistrees';
      default:
        return count == 1
            ? 'You have 1 saved area'
            : 'You have $count saved areas';
    }
  }

  /// The delete confirmation, naming the area by what it covers and costs —
  /// with several stored, "the saved map" would not say which one.
  static String offlineAreaDeleteMessageOf(String dimensions, String size) {
    switch (_languageCode) {
      case 'ar':
        return 'ستُحذف المنطقة المحفوظة ($dimensions · $size) من هذا '
            'الجهاز، ويمكنك تنزيلها من جديد متى توفّر اتصال بالإنترنت.';
      case 'fr':
        return 'La zone enregistree ($dimensions · $size) sera retiree de '
            'cet appareil. Vous pourrez la telecharger a nouveau des que '
            'vous aurez une connexion.';
      default:
        return 'The saved area ($dimensions · $size) will be removed from '
            'this device. You can download it again whenever you have a '
            'connection.';
    }
  }

  /// "24 × 18 km" — the ground the frame covers, which is what a driver
  /// pictures when deciding whether it holds the roads they need.
  ///
  /// Rounded to a whole number past 10 km: a frame that reads "23.7 × 18.2"
  /// invites a precision the driver has no way to aim for with their thumb.
  static String offlineAreaDimensions(num widthKm, num heightKm) {
    String side(num km) =>
        km >= 10 ? km.round().toString() : km.toStringAsFixed(1);
    return '${side(widthKm)} × ${side(heightKm)} ${AppUnits.km}';
  }

  /// Customer availability windows
  static String get arrivalTime => _t('arrivalTime');
  static String get setArrivalTime => _t('setArrivalTime');
  static String get clearArrivalTime => _t('clearArrivalTime');
  static String get arrivalWindowHint => _t('arrivalWindowHint');
  static String get anyTime => _t('anyTime');
  static String get fromTime => _t('fromTime');
  static String get toTime => _t('toTime');
  static String get departureTimeLabel => _t('departureTimeLabel');
  static String get departureNow => _t('departureNow');
  static String get departureHint => _t('departureHint');
  static String get timeWindowMissedTitle => _t('timeWindowMissedTitle');
  static String get timeWindowMissedBody => _t('timeWindowMissedBody');
  static String get timeWindowMissedBadge => _t('timeWindowMissedBadge');
  static String get sameTimeError => _t('sameTimeError');
  static String get seeDetails => _t('seeDetails');
  static String get youWantedToArrive => _t('youWantedToArrive');
  static String get youWouldArrive => _t('youWouldArrive');
  static String get howToFixIt => _t('howToFixIt');
  static String get fixMoveDeadline => _t('fixMoveDeadline');
  static String get fixMoveDeadlineWhy => _t('fixMoveDeadlineWhy');
  static String get fixLeaveEarlier => _t('fixLeaveEarlier');
  static String get fixLeaveEarlierWhy => _t('fixLeaveEarlierWhy');
  static String get fixDropStop => _t('fixDropStop');
  static String get fixDropStopWhy => _t('fixDropStopWhy');
  static String get keepAsIs => _t('keepAsIs');
  static String get expectedArrival => _t('expectedArrival');
  static String get requiredArrival => _t('requiredArrival');

  /// "25 min late" — the size of the overshoot, the number that tells the
  /// user whether this is a nudge or a re-plan.
  static String lateByMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      switch (_languageCode) {
        case 'ar':
          final hours = h == 1 ? 'ساعة' : 'بـ$h ساعات';
          final prefix = h == 1 ? 'متأخر بساعة' : 'متأخر $hours';
          return m == 0 ? prefix : '$prefix و$m دقيقة';
        case 'fr':
          return m == 0 ? '$h h de retard' : '$h h $m min de retard';
        default:
          return m == 0 ? '$h h late' : '$h h $m min late';
      }
    }
    switch (_languageCode) {
      case 'ar':
        return 'متأخر بـ$minutes دقيقة';
      case 'fr':
        return '$minutes min de retard';
      default:
        return '$minutes min late';
    }
  }

  /// "Leave 35 min earlier — at 07:25"
  static String leaveEarlierBy(int minutes, String newClock) {
    switch (_languageCode) {
      case 'ar':
        return 'الانطلاق مبكراً بـ$minutes دقيقة — عند الساعة $newClock';
      case 'fr':
        return 'Partez $minutes min plus tot — a $newClock';
      default:
        return 'Leave $minutes min earlier — at $newClock';
    }
  }

  /// "Arrive 14:00 – 15:30" — the window summary shown on a stop.
  static String arrivalWindowRange(String from, String to) {
    switch (_languageCode) {
      case 'ar':
        return '$from – $to';
      default:
        return '$from – $to';
    }
  }

  /// "3 stops fall outside their availability" — plural-aware.
  static String timeWindowMissedCount(int count) {
    switch (_languageCode) {
      case 'ar':
        if (count == 1) {
          return 'نقطة واحدة يتعذّر الوصول إليها ضمن فترة توفّرها';
        }
        // Arabic has a dual: two stops are نقطتان, and every pronoun in the
        // sentence agrees with it. Writing "2 نقاط" is a grammar mistake a
        // reader notices immediately.
        if (count == 2) {
          return 'نقطتان يتعذّر الوصول إليهما ضمن فترة توفّرهما';
        }
        // Arabic counts 3–10 with a plural noun and 11+ with a singular one.
        final noun = count <= 10 ? 'نقاط' : 'نقطة';
        return '$count $noun يتعذّر الوصول إليها ضمن فترة توفّرها';
      case 'fr':
        return count == 1
            ? '1 arret ne peut pas etre atteint pendant sa disponibilite'
            : '$count arrets ne peuvent pas etre atteints pendant leur disponibilite';
      default:
        return count == 1
            ? '1 stop falls outside its availability window'
            : '$count stops fall outside their availability windows';
    }
  }

  /// "+1 h 35 m" — the same overshoot as [lateByMinutes], squeezed into a
  /// chip.
  ///
  /// The long form crowds out the stop's own name on a one-line banner
  /// ("متأخر بساعة و35 دقيقة" is wider than most labels), and inside a red
  /// chip the word "late" is already implied by everything around it. The
  /// leading "+" keeps it readable as a delta rather than a clock.
  static String lateByShort(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    switch (_languageCode) {
      case 'ar':
        // No leading "+": a sign is bidi-neutral, so at the start of an
        // Arabic run it lands to the right of the digit and reads as "1+".
        // A word carries the meaning instead and never moves.
        if (h == 0) return 'تأخير $minutes د';
        return m == 0 ? 'تأخير $h س' : 'تأخير $h س $m د';
      default:
        if (h == 0) return '+$minutes min';
        return m == 0 ? '+${h}h' : '+${h}h ${m}m';
    }
  }

  /// "12 MB" — a downloaded corridor's footprint, rounded to whole MB
  /// because the exact byte count is noise to the driver.
  static String megabytes(num mb) {
    switch (_languageCode) {
      case 'ar':
        return '${_mbNumber(mb)} ميغابايت';
      default:
        return '${_mbNumber(mb)} MB';
    }
  }

  /// The bare figure behind [megabytes] — a whole number once past 1 MB,
  /// where a decimal would be false precision on an estimate.
  static String _mbNumber(num mb) =>
      mb < 1 ? mb.toStringAsFixed(1) : mb.round().toString();

  /// "~12 MB" — a pre-download estimate, marked approximate on purpose.
  ///
  /// Not "≈": U+2248 is missing from Almarai and renders as a tofu box on
  /// the very screens this appears on (seen in the download preview).
  static String approxMegabytes(num mb) {
    final size = megabytes(mb);
    switch (_languageCode) {
      case 'ar':
        return 'نحو $size';
      default:
        return '~$size';
    }
  }

  static String pointsCount(int count) {
    switch (_languageCode) {
      case 'ar':
        // Same agreement as [timeWindowMissedCount], and for the same
        // reason: "2 نقطة" and "5 نقطة" are mistakes a reader notices at a
        // glance. One is named, two take the dual, 3–10 take the plural
        // noun, and 11 up goes back to the singular.
        if (count == 1) return 'نقطة واحدة';
        if (count == 2) return 'نقطتان';
        return '$count ${count <= 10 ? 'نقاط' : 'نقطة'}';
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

  // Onboarding (first-run)
  static String get onbSkip => _t('onbSkip');
  static String get onbNext => _t('onbNext');
  static String get onbBack => _t('onbBack');
  static String get onbGetStarted => _t('onbGetStarted');
  static String get onbWelcomeTitle => _t('onbWelcomeTitle');
  static String get onbWelcomeBody => _t('onbWelcomeBody');
  static String get onbLanguageLabel => _t('onbLanguageLabel');
  static String get onbPlanTitle => _t('onbPlanTitle');
  static String get onbPlanBody => _t('onbPlanBody');
  static String get onbImportTitle => _t('onbImportTitle');
  static String get onbImportBody => _t('onbImportBody');
  // iPhone takes a longer road: WhatsApp hands the location to a map app,
  // and that app's share button is the only door into Laffeh.
  static String get onbImportTitleIos => _t('onbImportTitleIos');
  static String get onbImportBodyIos => _t('onbImportBodyIos');
  static String get onbImportIosStep1 => _t('onbImportIosStep1');
  static String get onbImportIosStep2 => _t('onbImportIosStep2');
  static String get onbImportIosStep3 => _t('onbImportIosStep3');
  static String get onbImportWhatsappTag => _t('onbImportWhatsappTag');
  static String get onbImportCsvTag => _t('onbImportCsvTag');
  static String get onbShareToLaffah => _t('onbShareToLaffah');

  // Add-options panel (empty state)
  static String get addOptHeader => _t('addOptHeader');
  static String get addOptManualTitle => _t('addOptManualTitle');
  static String get addOptManualSub => _t('addOptManualSub');
  static String get addOptWhatsappTitle => _t('addOptWhatsappTitle');
  static String get addOptWhatsappSub => _t('addOptWhatsappSub');
  static String get addOptImportTitle => _t('addOptImportTitle');
  static String get addOptImportSub => _t('addOptImportSub');
  static String get addOptManualBack => _t('addOptManualBack');
  static String get importChooserTitle => _t('importChooserTitle');
  static String get importChooserPaste => _t('importChooserPaste');
  static String get importChooserCsv => _t('importChooserCsv');
  static String get importCsvSub => _t('importCsvSub');
  static String get whatsappOpenFailed => _t('whatsappOpenFailed');
  static String get waInfoBody => _t('waInfoBody');
  // The two imports that come from another app, each with its own little
  // demo and its own way out to that app.
  static String get openWhatsappCta => _t('openWhatsappCta');
  static String get gmapsInfoTitle => _t('gmapsInfoTitle');
  static String get gmapsInfoBody => _t('gmapsInfoBody');
  static String get openGoogleMapsCta => _t('openGoogleMapsCta');
  static String get pasteLinkCta => _t('pasteLinkCta');

  /// iOS says it differently: WhatsApp there offers no share-to-Laffah, only
  /// its own fixed list of map apps, so the trip goes out through Maps.
  static String get waInfoBodyIos => _t('waInfoBodyIos');
  static String get addPointCta => _t('addPointCta');
  // ── Single-destination (navigator) shape ──
  static String get whereTo => _t('whereTo');
  static String get whereToHint => _t('whereToHint');
  static String get destinationTitle => _t('destinationTitle');
  static String get goNow => _t('goNow');
  static String get findingRoute => _t('findingRoute');
  static String get routeUnavailableTapGo => _t('routeUnavailableTapGo');
  static String get addAnotherStop => _t('addAnotherStop');
  static String get addAnotherStopSub => _t('addAnotherStopSub');
  static String get changeDestination => _t('changeDestination');
  // Departure — the trip starts where the driver is, until they say
  // otherwise.
  static String get fromLabel => _t('fromLabel');
  static String get currentLocationLabel => _t('currentLocationLabel');
  static String get startFromTitle => _t('startFromTitle');
  static String get useCurrentLocation => _t('useCurrentLocation');
  static String get useCurrentLocationSub => _t('useCurrentLocationSub');
  static String get orPickAPlace => _t('orPickAPlace');
  // The trip's shape, picked before the first point: one place to get to,
  // or a round with several stops in it.
  static String get tripShapeTitle => _t('tripShapeTitle');
  static String get tripShapeSingle => _t('tripShapeSingle');
  static String get tripShapeSingleHint => _t('tripShapeSingleHint');
  static String get tripShapeMulti => _t('tripShapeMulti');
  static String get multiStopCtaSub => _t('multiStopCtaSub');
  // Short forms — three abreast under the search box, where the full
  // "pick on the map" / "paste a location link" labels do not fit.
  static String get methodShortMap => _t('methodShortMap');
  static String get methodShortLink => _t('methodShortLink');
  static String get methodShortWhatsapp => _t('methodShortWhatsapp');
  static String get addMethodTitle => _t('addMethodTitle');
  static String get addMethodAddress => _t('addMethodAddress');
  static String get addMethodAddressSub => _t('addMethodAddressSub');
  static String get addMethodMap => _t('addMethodMap');
  static String get addMethodMapSub => _t('addMethodMapSub');
  static String get addMethodPasteLinkSub => _t('addMethodPasteLinkSub');
  static String get pasteLocationTitle => _t('pasteLocationTitle');
  static String get pasteLocationSub => _t('pasteLocationSub');
  static String get pasteLocationPlaceholder => _t('pasteLocationPlaceholder');
  static String get pasteLocationAdd => _t('pasteLocationAdd');
  static String get pasteLocationInvalid => _t('pasteLocationInvalid');
  static String get pasteFromClipboard => _t('pasteFromClipboard');
  static String get addressSearchTitle => _t('addressSearchTitle');
  static String get addressSearchPlaceholder => _t('addressSearchPlaceholder');
  static String get addressSearchPrompt => _t('addressSearchPrompt');
  static String get addressSearchEmpty => _t('addressSearchEmpty');
  static String get addressSearchRecents => _t('addressSearchRecents');
  static String get addressSearchNearby => _t('addressSearchNearby');
  static String get addressSearchRefining => _t('addressSearchRefining');
  static String get searchPastedCoordinates => _t('searchPastedCoordinates');
  static String get mapLabelKindCity => _t('mapLabelKindCity');
  static String get mapLabelKindArea => _t('mapLabelKindArea');
  static String get mapLabelKindRegion => _t('mapLabelKindRegion');
  static String get mapLabelKindStreet => _t('mapLabelKindStreet');
  static String get mapPlaceAddStop => _t('mapPlaceAddStop');
  static String get mapPlaceSetDeparture => _t('mapPlaceSetDeparture');
  static String get mapPlaceAlreadyAdded => _t('mapPlaceAlreadyAdded');

  /// Label for a kind of place ("محطة وقود"), used when a result found by
  /// category has no name of its own. Keys come from the category lexicon.
  static String placeCategoryLabel(String key) => _t(key);
  static String get placePointHint => _t('placePointHint');
  static String get pressBackAgainToExit => _t('pressBackAgainToExit');
  static String get onbLocationTitle => _t('onbLocationTitle');
  static String get onbLocationBody => _t('onbLocationBody');
  static String get onbAllowLocation => _t('onbAllowLocation');
  static String get onbMaybeLater => _t('onbMaybeLater');

  // ── Auth / Onboarding ──────────────────────────────────
  static String get languageLabel => _t('languageLabel');
  static String get termsAndPrivacy => _t('termsAndPrivacy');

  // Welcome
  static String get welcomeTitle => _t('welcomeTitle');
  static String get welcomeBody => _t('welcomeBody');
  static String get welcomeCreateAccount => _t('welcomeCreateAccount');
  static String get welcomeHaveAccount => _t('welcomeHaveAccount');
  static String get welcomeSkip => _t('welcomeSkip');

  // Common auth actions
  static String get authContinue => _t('authContinue');
  static String get authBack => _t('authBack');
  static String get edit => _t('edit');

  // Sign in
  static String get signInTitle => _t('signInTitle');
  static String get signInButton => _t('signInButton');
  static String get signInNoAccount => _t('signInNoAccount');
  static String get signInCreateNew => _t('signInCreateNew');
  static String get signInSubtitle => _t('signInSubtitle');
  static String get forgotPassword => _t('forgotPassword');

  // Fields
  static String get phoneLabel => _t('phoneLabel');
  static String get countrySearchHint => _t('countrySearchHint');
  static String get passwordLabel => _t('passwordLabel');
  static String get passwordHint => _t('passwordHint');
  static String get passwordConfirmLabel => _t('passwordConfirmLabel');
  static String get passwordConfirmHint => _t('passwordConfirmHint');
  static String get passwordShow => _t('passwordShow');
  static String get passwordHide => _t('passwordHide');

  // Create-account steps
  static String get createAccountTitle => _t('createAccountTitle');
  static String get stepCredentialsTitle => _t('stepCredentialsTitle');
  static String get stepCredentialsSubtitle => _t('stepCredentialsSubtitle');

  /// "Step 2 of 4" — the counter above the create-account progress bar.
  static String stepCounter(int step, int total) => _t(
    'stepCounter',
  ).replaceAll('{n}', '$step').replaceAll('{total}', '$total');
  static String get nameQuestion => _t('nameQuestion');
  static String get nameHint => _t('nameHint');
  static String get companyQuestion => _t('companyQuestion');
  static String get companyHint => _t('companyHint');
  static String get useCaseQuestion => _t('useCaseQuestion');
  static String get useCaseOtherHint => _t('useCaseOtherHint');
  static String get useCaseSelectAtLeastOne => _t('useCaseSelectAtLeastOne');

  // Summary + finish
  static String get summaryTitle => _t('summaryTitle');
  static String get summaryPhone => _t('summaryPhone');
  static String get summaryName => _t('summaryName');
  static String get summaryCompany => _t('summaryCompany');
  static String get summaryUseCases => _t('summaryUseCases');
  static String get finishButton => _t('finishButton');
  static String get successTitle => _t('successTitle');

  // Use-case labels (mirror the seeded `use_cases.code`)
  static String get ucDelivery => _t('ucDelivery');
  static String get ucPersonalUse => _t('ucPersonalUse');
  static String get ucNavigation => _t('ucNavigation');
  static String get ucDriver => _t('ucDriver');
  static String get ucDeliveryDriver => _t('ucDeliveryDriver');
  static String get ucFleetManagement => _t('ucFleetManagement');
  static String get ucBusinessManagement => _t('ucBusinessManagement');
  static String get ucRoutePlanning => _t('ucRoutePlanning');
  static String get ucFieldOperations => _t('ucFieldOperations');
  static String get ucFieldSales => _t('ucFieldSales');
  static String get ucOther => _t('ucOther');

  // Forgot password / support
  static String get forgotPasswordTitle => _t('forgotPasswordTitle');
  static String get forgotPasswordBody => _t('forgotPasswordBody');
  static String get contactSupport => _t('contactSupport');
  static String get whatsappForgotMessage => _t('whatsappForgotMessage');

  // Account nudge
  static String get nudgeTitle => _t('nudgeTitle');
  static String get nudgeBody => _t('nudgeBody');
  static String get nudgeDismiss => _t('nudgeDismiss');
  static String get nudgeLater => _t('nudgeLater');

  // Registration grace period (skipped users)
  static String get registrationRequiredTitle =>
      _t('registrationRequiredTitle');
  static String get registrationRequiredBody => _t('registrationRequiredBody');
  static String get registrationRequiredNote => _t('registrationRequiredNote');
  static String get welcomeSignInInstead => _t('welcomeSignInInstead');

  /// "3 days left to use the app without an account" — the countdown shown in
  /// the nudge as the trial runs out.
  static String trialDaysLeft(int days) {
    switch (_languageCode) {
      case 'ar':
        // MSA agreement: 1 = يوم واحد, 2 = يومان, 3–10 take the plural noun,
        // 11+ the singular.
        final phrase = switch (days) {
          <= 1 => 'يوم واحد',
          2 => 'يومان',
          <= 10 => '$days أيام',
          _ => '$days يوماً',
        };
        return 'يتبقى $phrase لاستخدام التطبيق دون حساب.';
      case 'fr':
        return days == 1
            ? 'Il vous reste 1 jour pour utiliser l\'application sans compte.'
            : 'Il vous reste $days jours pour utiliser l\'application sans compte.';
      default:
        return days == 1
            ? '1 day left to use the app without an account.'
            : '$days days left to use the app without an account.';
    }
  }

  // Account section in Settings (sign out / delete account)
  static String get account => _t('account');
  static String get accountSignedIn => _t('accountSignedIn');
  static String get accountGuest => _t('accountGuest');
  static String get accountGuestHint => _t('accountGuestHint');
  static String get signOut => _t('signOut');
  static String get signOutConfirmTitle => _t('signOutConfirmTitle');
  static String get signOutConfirmBody => _t('signOutConfirmBody');
  static String get signOutDone => _t('signOutDone');
  static String get deleteAccount => _t('deleteAccount');
  static String get deleteAccountTitle => _t('deleteAccountTitle');
  static String get deleteAccountBody => _t('deleteAccountBody');
  static String get deleteAccountItemLogin => _t('deleteAccountItemLogin');
  static String get deleteAccountItemProfile => _t('deleteAccountItemProfile');
  static String get deleteAccountItemLocation =>
      _t('deleteAccountItemLocation');
  static String get deleteAccountItemRoutes => _t('deleteAccountItemRoutes');
  static String get deleteAccountIrreversible =>
      _t('deleteAccountIrreversible');
  static String get deleteAccountAck => _t('deleteAccountAck');
  static String get deleteAccountConfirm => _t('deleteAccountConfirm');
  static String get deleteAccountDone => _t('deleteAccountDone');

  // Auth errors
  static String get errInvalidCredentials => _t('errInvalidCredentials');
  static String get errPhoneInUse => _t('errPhoneInUse');
  static String get errWeakPassword => _t('errWeakPassword');
  static String get errRateLimited => _t('errRateLimited');
  static String get errAuthNetwork => _t('errAuthNetwork');
  static String get errSignupsDisabled => _t('errSignupsDisabled');
  static String get errBackendUnavailable => _t('errBackendUnavailable');
  static String get errUnknownAuth => _t('errUnknownAuth');

  // Validation
  static String get valPasswordRequired => _t('valPasswordRequired');
  static String get valPasswordTooShort => _t('valPasswordTooShort');
  static String get valPasswordConfirmRequired =>
      _t('valPasswordConfirmRequired');
  static String get valPasswordMismatch => _t('valPasswordMismatch');
  static String get valNameRequired => _t('valNameRequired');
  static String get valNameTooShort => _t('valNameTooShort');
  static String get valNameTooLong => _t('valNameTooLong');
  static String get valNameNumeric => _t('valNameNumeric');
  static String get valCompanyRequired => _t('valCompanyRequired');
  static String get valCompanyTooShort => _t('valCompanyTooShort');
  static String get valCompanyTooLong => _t('valCompanyTooLong');
  static String get valPhoneInvalid => _t('valPhoneInvalid');
  static String get valPhoneRequired => _t('valPhoneRequired');
  static String get valPhoneTooShort => _t('valPhoneTooShort');
  static String get valPhoneTooLong => _t('valPhoneTooLong');
  static String get valPhoneNotMobile => _t('valPhoneNotMobile');
  static String get valTermsRequired => _t('valTermsRequired');

  // ── Legal / consent ────────────────────────────────────
  static String get legalTitle => _t('legalTitle');

  // Headings over the groups the Settings page is built from.
  static String get settingsGroupAccount => _t('settingsGroupAccount');
  static String get settingsGroupTrip => _t('settingsGroupTrip');
  static String get settingsGroupMap => _t('settingsGroupMap');
  static String get settingsGroupPreferences => _t('settingsGroupPreferences');
  static String get settingsGroupAbout => _t('settingsGroupAbout');
  static String get legalPrivacy => _t('legalPrivacy');
  static String get legalTerms => _t('legalTerms');
  static String get legalAccountDeletion => _t('legalAccountDeletion');

  /// Consent sentence for the sign-up gate. Contains the `{terms}` and
  /// `{privacy}` placeholders, which the UI replaces with tappable links, so
  /// each language keeps its own word order.
  static String get consentTemplate => _t('consentTemplate');
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
    'appName': 'Laffah',
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
    'enableLocationCta': 'Enable location',
    'pointAdded': 'Point added',
    'stopPhoneTitle': 'Phone number',
    'stopPhoneHint': 'With the country code, e.g. +963944123456',
    'stopPhoneAdd': 'Add a phone number',
    'stopPhoneEdit': 'Edit the phone number',
    'stopCall': 'Call',
    'stopWhatsapp': 'WhatsApp',
    'stopWhatsappOnTheWay': 'Hello, I am on my way to you.',
    'stopWhatsappArrived': 'Hello, I have arrived at your location.',
    'stopCallFailed': 'Could not start the call',
    'locGateTitle': 'Laffah needs your location',
    'locGateBody':
        'Your route starts from where you are, and the map follows you as you drive.',
    'locGateBlockedBody':
        'Location is blocked for Laffah. Open the app settings to allow it.',
    'locGateContinue': 'Continue without location',
    'errInvalidResponse': 'Invalid response from the server',
    'errEmptyOptimizedRoute': 'The model did not return an optimized route',
    'errTimeout': 'The server connection timed out',
    'errLaffaUnreadable': 'This round could not be opened.',
    'laffaReplaceTitle': 'Open this round?',
    'laffaReplaceMessage': 'It replaces the stops currently on your phone.',
    'laffaReplaceConfirm': 'Open it',
    'laffaImported': 'Round loaded — {n} stops.',
    'errServerConnection': 'Could not connect to the server',
    'errRouteOptimizationFailed': 'Route optimization failed',
    'errOneDepotRequired': 'Exactly one departure point is required',
    'errMinOneStopAfterDepot':
        'Please choose at least one destination after the departure point',
    'errLocalStorageWrite': 'Could not write to local storage',
    'errSavedRoutesLoad': 'Could not load saved routes',
    'errSavedRouteSave': 'Could not save route',
    'removePointTitle': 'Remove this point?',
    'removePointBody':
        'It leaves the trip. The rest of your stops stay as they are.',
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
    'addOneStopToOptimize': 'Add your first stop',
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
    'recenter': 'Recenter',
    'resetView': 'Reset view',
    'cameraChase': 'Cinematic',
    'headedTo': 'Heading to',
    'departingFrom': 'Departing from',
    'arrived': 'Arrived!',
    'progress': 'Progress',
    'remainingDistance': 'Remaining distance',
    'remainingTime': 'Remaining time',
    'focusMode': 'Focus',
    'driveControls': 'Trip controls',
    'exitFocus': 'Exit focus',
    'remainingShort': 'left',
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
    'aboutUs': 'About us',
    'language': 'Language',
    'appearance': 'Appearance',
    'vehicleIcon': 'Vehicle icon',
    'vehicleVwBus': 'VW Bus',
    'vehicleVespa': 'Vespa',
    'vehicleTaxi': 'Taxi',
    'vehicleCamel': 'Camel',
    'vehicleArrow': 'Arrow',
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
    'csvExportSuccess': 'CSV file exported',
    'optional': 'Optional',
    'optionalPoint': 'Optional point',
    'markOptional': 'Make optional',
    'markRequired': 'Make required',
    'activate': 'Activate',
    'deactivate': 'Deactivate',
    'activateStopTitle': 'Add this stop back?',
    'activateStopMsg':
        'Including it changes your route. Re-optimize now to add it, or delete the stop.',
    'reoptimizeNow': 'Re-optimize',
    'skipStop': 'Skip this stop',
    'includeStop': 'Add to route',
    'optionalBadge': 'Optional',
    'deactivatedBadge': 'Off',
    'addOptionalHere': 'Add optional stop here',
    'moveOnMap': 'Move on map',
    'movePointTitle': 'Move point',
    'movePointHint': 'Drag the highlighted point on the map, then save.',
    'saveLocation': 'Save location',
    'locationUpdated': 'Location updated',
    'addStop': 'Add stop',
    'addOptionalStop': 'Add optional stop',
    'addByTap': 'Add from map',
    'addMethods': 'Add points',
    'keepAddingHint': 'Keep adding as many points as you need.',
    'offlineTitle': 'Offline',
    'offlineBody': 'No internet — your changes are saved on this device.',
    'offlineActionUnavailable': 'This needs an internet connection.',
    'draftRestoredMsg': 'We restored your saved work.',
    'savedLocallyNote': 'Saved on your device',
    'errNoActiveStops': 'Activate at least one stop before optimizing.',
    'noAddressesFound': 'No addresses found. Check the text and try again.',
    'exportCsv': 'Export CSV',
    'csvImportEmpty': 'No route points were found in this CSV file',
    'csvImportFailed': 'Could not import CSV file',
    'csvExportFailed': 'Could not export CSV file',
    'csvNoPoints': 'No points to export',
    'csvShareText': 'Laffah route CSV',
    'departureBadge': 'Start',
    'returnBadge': 'Return',
    'routeOrder': 'Route order',
    'points': 'points',
    'offlineMapTitle': 'Offline map for this trip',
    'offlineMapIdleHint':
        'Download it and the map keeps working with no signal.',
    'offlineMapNoTrip': 'Available once you have a planned route.',
    'offlineMapDownloading': 'Downloading the map…',
    'offlineMapReady': 'Saved on your device',
    'offlineMapPartial': 'Part of the map is missing — tap to finish it.',
    'offlineMapFailed': "Couldn't download the map.",
    'offlineMapDownload': 'Download',
    'offlineMapRetry': 'Finish',
    'offlineMapCancel': 'Cancel',
    'offlineMapDelete': 'Delete',
    'offlineMapNeedsConnection': 'Downloading the map needs a connection.',
    'offlineMapPreparing': 'Preparing the download…',
    'offlineMapCancelling': 'Stopping…',
    'offlineMapCancelled': 'Stopped. What was downloaded is kept.',
    'offlineMapResume': 'Continue',
    'offlineAreaTitle': 'Offline map',
    'offlineAreaHint':
        'Save any area of the map and its streets keep showing with no '
        'signal — trip or no trip.',
    'offlineAreaNotSaved': 'Not saved',
    'offlineAreaUpdate': 'Update',
    'offlineAreaNeedsLocation':
        'Your location is needed to centre the map on you.',
    'offlineAreaDeleteTitle': 'Delete the saved map?',
    'offlineAreaDeleteMessage':
        'The saved map will be removed from this device. You can download '
        'it again whenever you have a connection.',
    'offlineAreaPickTitle': 'Choose the area to save',
    'offlineAreaPickHint': 'Move the map so the frame holds what you need.',
    'offlineAreaMeasuring': 'Measuring the area…',
    'offlineAreaTooLarge': 'Too much to download — zoom in a little.',
    'offlineAreaMyLocation': 'Centre on me',
    'offlineAreaSavedHere': 'This area is saved',
    'offlineAreaAtCeiling':
        'You have reached the limit of saved areas — delete one first.',
    'arrivalTime': 'Customer availability',
    'setArrivalTime': 'Set when the customer is available',
    'clearArrivalTime': 'Remove the availability window',
    'arrivalWindowHint':
        'The optimizer orders your stops so you get here while the customer is available.',
    'anyTime': 'Available any time',
    'fromTime': 'From',
    'toTime': 'To',
    'departureTimeLabel': 'Departure',
    'departureNow': 'Now',
    'departureHint': 'Arrival times are counted from here.',
    'timeWindowMissedTitle': "Can't make it while they're available",
    'timeWindowMissedBody':
        'These stops stay in your route — change their availability, the departure, or drop a stop.',
    'timeWindowMissedBadge': 'Late',
    'sameTimeError': 'Pick two different times.',
    'seeDetails': 'See what to do',
    'youWantedToArrive': 'Customer is available',
    'youWouldArrive': 'You would get there at',
    'howToFixIt': 'How to fix it',
    'fixMoveDeadline': 'Extend the availability',
    'fixMoveDeadlineWhy':
        'Keeps every stop. Pushes each unreachable window just past what the drive actually takes.',
    'fixLeaveEarlier': 'Leave earlier',
    'fixLeaveEarlierWhy':
        'Keeps every availability window as it is, and starts the trip sooner.',
    'fixDropStop': 'Skip a stop',
    'fixDropStopWhy': 'Frees up the time the other windows need.',
    'keepAsIs': 'Leave it as is',
    'expectedArrival': 'You arrive',
    'requiredArrival': 'Available',
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
    'previewBadge': 'Preview',
    'previewStartDrive': 'Ready? Start driving',
    'endTrip': 'End trip',
    'moreActions': 'More',
    'googleMapsShort': 'Google Maps',
    'openWithMaps': 'Open with Maps',
    'newRouteShort': 'New',
    'startFresh': 'Delete trip & start fresh',
    'replay': 'Replay',
    'arrivedHere': 'Arrived',
    'pointServed': 'Point served',
    'rerouting': 'Recalculating route…',
    'reoptimize': 'Re-optimize',
    'endOfDay': 'Where the day ends',
    'finishRoundTrip': 'Back to the start',
    'finishRoundTripHint': 'Finish where you set off from.',
    'finishOpen': 'Stop at the last stop',
    'finishOpenHint': 'No drive back. The day ends at your last stop.',
    'finishCustom': 'Somewhere else',
    'finishCustomHint': 'Finish at a place you choose, like home.',
    'finishPointLabel': 'Finish',
    'finishPickPlace': 'Choose the place',
    'toLabel': 'To',
    'setFinishHere': 'End the day here',
    'view3d': 'Tilt the map',
    'viewFlat': 'Flatten the map',
    'finishEndsAt': 'Day ends at {stop}',
    'reCenter': 'Re-center',
    'arrivalLabel': 'Arrival',
    'speedUnitKmh': 'km/h',
    'manTurnLeft': 'Turn left',
    'manTurnRight': 'Turn right',
    'manSlightLeft': 'Keep slightly left',
    'manSlightRight': 'Keep slightly right',
    'manSharpLeft': 'Turn sharply left',
    'manSharpRight': 'Turn sharply right',
    'manUTurn': 'Make a U-turn',
    'manStraight': 'Continue straight',
    'manMerge': 'Merge onto the road',
    'manKeepLeft': 'Keep left',
    'manKeepRight': 'Keep right',
    'manOnRamp': 'Take the ramp',
    'manOffRamp': 'Take the exit',
    'manRoundabout': 'Enter the roundabout',
    'manRoundaboutExit': 'At the roundabout, take exit {n}',
    'manArrive': 'Arriving at your stop',
    'continueToward': 'Continue toward {stop}',
    'onbSkip': 'Skip',
    'onbNext': 'Next',
    'onbBack': 'Back',
    'onbGetStarted': 'Get started',
    'onbWelcomeTitle': 'Welcome to Laffah',
    'onbWelcomeBody':
        'Plan the smartest route through all your stops — in seconds.',
    'onbLanguageLabel': 'Choose your language',
    'onbPlanTitle': 'Drop stops, get the best order',
    'onbPlanBody':
        'Move the map and tap to add each stop. Laffah reorders them into the fastest route automatically.',
    'onbImportTitle': 'Add stops from WhatsApp',
    'onbImportBody':
        'Share a location to Laffah and it lands right on your route — no typing. A CSV import or a pasted list works too.',
    'onbImportTitleIos': 'Add stops from WhatsApp via Google Maps',
    'onbImportIosStep1': 'Tap the location in WhatsApp',
    'onbImportIosStep2': 'In Google Maps, tap the share button',
    'onbImportIosStep3': 'Choose Laffah',
    'onbImportBodyIos':
        'Tap the location in WhatsApp to open it in Google Maps, then share it to Laffah — the stop lands on your route. A CSV import or a pasted list works too.',
    'onbImportWhatsappTag': 'WhatsApp',
    'onbImportCsvTag': 'CSV & paste',
    'onbShareToLaffah': 'Open with Laffah',
    'addOptHeader': 'How would you like to add stops?',
    'addOptManualTitle': 'Add manually',
    'addOptManualSub': 'Drop a pin on the map',
    'addOptWhatsappTitle': 'From WhatsApp',
    'addOptWhatsappSub': 'Share a location to Laffah',
    'addOptImportTitle': 'Paste or import',
    'addOptImportSub': 'A list of addresses or a CSV',
    'addOptManualBack': 'Choose another way',
    'importChooserTitle': 'Add several stops',
    'importChooserPaste': 'Paste a list of addresses',
    'importChooserCsv': 'Import a CSV file',
    'importCsvSub': 'Addresses, names and numbers in one go',
    'addMethodTitle': 'How do you want to add this point?',
    'addMethodAddress': 'Type an address',
    'addMethodAddressSub': 'Search and pick one address',
    'addMethodMap': 'Pick on the map',
    'addMethodMapSub': 'Drop a pin where you want',
    'addMethodPasteLinkSub': 'Share a place to Laffah, or paste its link',
    'pasteLocationTitle': 'Paste a Google location',
    'pasteLocationSub': 'Paste a Google Maps link — we\'ll drop a pin for it',
    'pasteLocationPlaceholder': 'Paste a Maps link…',
    'pasteLocationAdd': 'Add point',
    'pasteLocationInvalid': 'Couldn\'t find a location in that link',
    'pasteFromClipboard': 'Paste from clipboard',
    'addressSearchTitle': 'Search address',
    'addressSearchPlaceholder': 'Street, place, city…',
    'addressSearchPrompt': 'Start typing to search for an address',
    'addressSearchEmpty': 'No matches. Try a different search.',
    'addressSearchRecents': 'Recent places',
    'addressSearchNearby': 'Nearby',
    'addressSearchRefining': 'Still looking…',
    'searchPastedCoordinates': 'The location you pasted',
    'mapLabelKindCity': 'City',
    'mapLabelKindArea': 'Neighbourhood',
    'mapLabelKindRegion': 'Region',
    'mapLabelKindStreet': 'Street',
    'mapPlaceAddStop': 'Add as a stop',
    'mapPlaceSetDeparture': 'Start the trip here',
    'mapPlaceAlreadyAdded': 'This place is already on the route',
    'catFuel': 'Fuel station',
    'catPharmacy': 'Pharmacy',
    'catHospital': 'Hospital',
    'catBank': 'Bank',
    'catAtm': 'ATM',
    'catRestaurant': 'Restaurant',
    'catCafe': 'Cafe',
    'catSupermarket': 'Supermarket',
    'catBakery': 'Bakery',
    'catMosque': 'Place of worship',
    'catSchool': 'School',
    'catUniversity': 'University',
    'catHotel': 'Hotel',
    'catParking': 'Parking',
    'catPolice': 'Police station',
    'catPost': 'Post office',
    'catCarRepair': 'Car repair',
    'catBusStation': 'Bus station',
    'catMarket': 'Market',
    'catPark': 'Park',
    'placePointHint': 'Move the map, then confirm',
    'whatsappOpenFailed': "Couldn't open WhatsApp",
    'openWhatsappCta': 'Open WhatsApp',
    'gmapsInfoTitle': 'Add a stop from Google Maps',
    'gmapsInfoBody':
        'Find the place in Google Maps, tap Share, and pick Laffah — the stop lands on your route. Or copy the link and paste it here.',
    'openGoogleMapsCta': 'Open Google Maps',
    'pasteLinkCta': 'Paste a link',
    'waInfoBody':
        'In WhatsApp, tap the shared location and choose "Open with Laffah" — the app opens with the stop already on your route. Repeat for each new stop; it stacks onto the previous ones.',
    'waInfoBodyIos':
        'In WhatsApp, tap the shared location and open it in Google Maps (or Apple Maps). From there tap the share button and pick Laffah — the app opens with the stop already on your route. Repeat for each new stop; it stacks onto the previous ones.',
    'whereTo': 'Where to?',
    'whereToHint': 'Search for a place or an address',
    'destinationTitle': 'Destination',
    'goNow': 'Go',
    'findingRoute': 'Finding the way…',
    'routeUnavailableTapGo': 'Tap Go to get the route',
    'addAnotherStop': 'Add another stop',
    'addAnotherStopSub': 'Laffeh puts them in the best order',
    'changeDestination': 'Change destination',
    'fromLabel': 'From',
    'currentLocationLabel': 'My current location',
    'startFromTitle': 'Start from',
    'useCurrentLocation': 'Use my current location',
    'useCurrentLocationSub': 'The trip starts wherever you are',
    'orPickAPlace': 'or name a place',
    'tripShapeTitle': 'Trip type',
    'tripShapeSingle': 'One destination',
    'tripShapeSingleHint': 'Straight to one place, the fastest way',
    'tripShapeMulti': 'Multiple stops',
    'multiStopCtaSub': 'Add every stop — Laffeh puts them in order',
    'methodShortMap': 'On map',
    'methodShortLink': 'Google Maps',
    'methodShortWhatsapp': 'WhatsApp',
    'addPointCta': 'Add a stop',
    'pressBackAgainToExit': 'Press back again to exit',
    'onbLocationTitle': 'Find your starting point',
    'onbLocationBody':
        'Allow location so Laffah can set your departure and guide you while you drive.',
    'onbAllowLocation': 'Allow location',
    'onbMaybeLater': 'Maybe later',
    // ── Auth / Onboarding ──
    'languageLabel': 'Language',
    'termsAndPrivacy': 'Terms & Privacy Policy',
    'welcomeTitle': 'Plan smarter routes',
    'welcomeBody':
        'Optimize your stops, save your trips, and get where you\'re going faster.',
    'welcomeCreateAccount': 'Create account',
    'welcomeHaveAccount': 'I already have an account',
    'welcomeSkip': 'Skip for now',
    'authContinue': 'Continue',
    'authBack': 'Back',
    'edit': 'Edit',
    'signInTitle': 'Welcome back',
    'signInButton': 'Sign in',
    'signInNoAccount': 'Don\'t have an account?',
    'signInCreateNew': 'Create a new account',
    'signInSubtitle': 'Sign in with your phone number to get your trips back.',
    'forgotPassword': 'Forgot password?',
    'phoneLabel': 'Phone number',
    'countrySearchHint': 'Search country',
    'passwordLabel': 'Password',
    'passwordHint': 'At least 8 characters',
    'passwordConfirmLabel': 'Confirm password',
    'passwordConfirmHint': 'Re-enter your password',
    'passwordShow': 'Show password',
    'passwordHide': 'Hide password',
    'createAccountTitle': 'Create account',
    'stepCounter': 'Step {n} of {total}',
    'stepCredentialsTitle': 'Your phone & password',
    'stepCredentialsSubtitle':
        'You sign in with your phone number. Pick a password of at least 8 characters.',
    'nameQuestion': 'What\'s your name?',
    'nameHint': 'Enter your full name.',
    'companyQuestion': 'Which company do you work for?',
    'companyHint': 'Enter the company name.',
    'useCaseQuestion':
        'Why do you want to use the app? You can select more than one option.',
    'useCaseOtherHint': 'Tell us how you plan to use the app.',
    'useCaseSelectAtLeastOne': 'Select at least one option to continue.',
    'summaryTitle': 'Review your details',
    'summaryPhone': 'Phone number',
    'summaryName': 'Full name',
    'summaryCompany': 'Company',
    'summaryUseCases': 'Reasons for use',
    'finishButton': 'Get started',
    'successTitle': 'Great, your account is ready.',
    'ucDelivery': 'Delivery',
    'ucPersonalUse': 'Personal use',
    'ucNavigation': 'Navigation and transportation',
    'ucDriver': 'Working as a driver',
    'ucDeliveryDriver': 'Delivery driver',
    'ucFleetManagement': 'Fleet management',
    'ucBusinessManagement': 'Business or company management',
    'ucRoutePlanning': 'Trip and route planning',
    'ucFieldOperations': 'Field operations',
    'ucFieldSales': 'Sales and field visits',
    'ucOther': 'Other use',
    'forgotPasswordTitle': 'Forgot password',
    'forgotPasswordBody': 'Contact support to recover your account.',
    'contactSupport': 'Contact support',
    'whatsappForgotMessage': 'I forgot my password',
    'nudgeTitle': 'Create your account',
    'nudgeBody': 'Save your routes and keep them across devices.',
    'nudgeDismiss': 'Not now',
    'nudgeLater': 'Later',
    'registrationRequiredTitle': 'An account is needed to continue',
    'registrationRequiredBody':
        'Your week of using the app without an account has ended. Create an '
        'account — or sign in — to keep planning your routes.',
    'registrationRequiredNote':
        'Creating an account takes less than a minute, and your saved routes '
        'stay with you.',
    'welcomeSignInInstead': 'Sign in instead',
    'account': 'Account',
    'accountSignedIn': 'Signed in',
    'accountGuest': 'Not signed in',
    'accountGuestHint': 'Sign in to keep your trips',
    'signOut': 'Sign out',
    'signOutConfirmTitle': 'Sign out?',
    'signOutConfirmBody':
        'You can sign back in anytime with your phone number. Nothing is deleted.',
    'signOutDone': 'Signed out.',
    'deleteAccount': 'Delete account',
    'deleteAccountTitle': 'Delete your account?',
    'deleteAccountBody': 'This permanently deletes:',
    'deleteAccountItemLogin': 'Your phone number and sign-in details',
    'deleteAccountItemProfile': 'Your name, company and selected use cases',
    'deleteAccountItemLocation': 'Your last saved location',
    'deleteAccountItemRoutes': 'Your saved trips on every device',
    'deleteAccountIrreversible':
        'This cannot be undone. You will need to create a new account to sign in again.',
    'deleteAccountAck': 'I understand this is permanent',
    'deleteAccountConfirm': 'Delete permanently',
    'deleteAccountDone': 'Your account and its data have been deleted.',
    'valTermsRequired':
        'Please accept the Terms of Service and Privacy Policy to continue.',
    'legalTitle': 'Legal',
    'settingsGroupAccount': 'Account',
    'settingsGroupTrip': 'Trip',
    'settingsGroupMap': 'Map',
    'settingsGroupPreferences': 'Preferences',
    'settingsGroupAbout': 'About',
    'legalPrivacy': 'Privacy Policy',
    'legalTerms': 'Terms of Service',
    'legalAccountDeletion': 'Account deletion',
    'consentTemplate': 'I agree to the {terms} and the {privacy}.',
    'errInvalidCredentials': 'Incorrect phone number or password.',
    'errPhoneInUse':
        'This phone number is already linked to an account. Try signing in.',
    'errWeakPassword': 'Please choose a stronger password.',
    'errRateLimited': 'Too many attempts. Please try again later.',
    'errAuthNetwork': 'No internet connection. Please check and try again.',
    'errSignupsDisabled': 'New sign-ups are currently unavailable.',
    'errBackendUnavailable': 'The service is unavailable right now.',
    'errUnknownAuth': 'Something went wrong. Please try again.',
    'valPasswordRequired': 'Please enter a password.',
    'valPasswordTooShort': 'Password must be at least 8 characters.',
    'valPasswordConfirmRequired': 'Please confirm your password.',
    'valPasswordMismatch': 'Passwords do not match.',
    'valNameRequired': 'Please enter your name.',
    'valNameTooShort': 'Name is too short.',
    'valNameTooLong': 'Name is too long.',
    'valNameNumeric': 'Please enter a valid name.',
    'valCompanyRequired': 'Please enter the company name.',
    'valCompanyTooShort': 'Company name is too short.',
    'valCompanyTooLong': 'Company name is too long.',
    'valPhoneInvalid': 'Please enter a valid phone number.',
    'valPhoneRequired': 'Please enter your phone number.',
    'valPhoneTooShort': 'Too short for {country}. Example: {example}',
    'valPhoneTooLong': 'Too long for {country}. Example: {example}',
    'valPhoneNotMobile':
        'That isn\'t a {country} mobile number. Example: {example}',
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
    'enableLocationCta': 'تفعيل الموقع',
    'pointAdded': 'تمت إضافة النقطة',
    'stopPhoneTitle': 'رقم الهاتف',
    'stopPhoneHint': 'مع رمز الدولة، مثل ‎+963944123456',
    'stopPhoneAdd': 'إضافة رقم هاتف',
    'stopPhoneEdit': 'تعديل رقم الهاتف',
    'stopCall': 'اتصال',
    'stopWhatsapp': 'واتساب',
    'stopWhatsappOnTheWay': 'مرحبًا، أنا في الطريق إليك.',
    'stopWhatsappArrived': 'مرحبًا، لقد وصلتُ إلى موقعك.',
    'stopCallFailed': 'تعذر بدء المكالمة',
    'locGateTitle': 'لفّة تحتاج إلى موقعك',
    'locGateBody': 'مسارك يبدأ من مكانك، والخريطة تتابعك أثناء القيادة.',
    'locGateBlockedBody':
        'الوصول إلى الموقع ممنوع للتطبيق. افتح إعدادات التطبيق للسماح به.',
    'locGateContinue': 'المتابعة بدون موقع',
    'errInvalidResponse': 'استجابة غير صالحة من الخادم',
    'errEmptyOptimizedRoute': 'لم يُرجِع النموذج أي مسار مُحسَّن',
    'errTimeout': 'انتهت مهلة الاتصال بالخادم',
    'errLaffaUnreadable': 'تعذر فتح هذه اللفة.',
    'laffaReplaceTitle': 'هل تفتح هذه اللفة؟',
    'laffaReplaceMessage': 'ستحل محل المحطات الموجودة على هاتفك.',
    'laffaReplaceConfirm': 'افتحها',
    'laffaImported': 'تم تحميل اللفة — {n} محطات.',
    'errServerConnection': 'تعذر الاتصال بالخادم',
    'errRouteOptimizationFailed': 'فشل تحسين المسار',
    'errOneDepotRequired': 'يجب تحديد نقطة انطلاق واحدة فقط',
    'errMinOneStopAfterDepot':
        'يرجى اختيار وجهة واحدة على الأقل بعد نقطة الانطلاق',
    'errLocalStorageWrite': 'تعذر الكتابة إلى التخزين المحلي',
    'errSavedRoutesLoad': 'تعذر تحميل المسارات المحفوظة',
    'errSavedRouteSave': 'تعذر حفظ المسار',
    'removePointTitle': 'حذف هذه النقطة؟',
    'removePointBody': 'تخرج من الرحلة، وتبقى بقية نقاطك كما هي.',
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
    'addOneStopToOptimize': 'أضف نقطتك الأولى',
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
    'recenter': 'إعادة التوسيط',
    'resetView': 'إعادة ضبط العرض',
    'cameraChase': 'سينمائي',
    'headedTo': 'متجه إلى',
    'departingFrom': 'الانطلاق من',
    'arrived': 'وصلنا!',
    'progress': 'التقدّم',
    'remainingDistance': 'المسافة المتبقية',
    'remainingTime': 'الوقت المتبقي',
    'focusMode': 'تركيز',
    'driveControls': 'أدوات الرحلة',
    'exitFocus': 'خروج من التركيز',
    'remainingShort': 'متبقّي',
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
    'aboutUs': 'من نحن',
    'language': 'اللغة',
    'appearance': 'المظهر',
    'vehicleIcon': 'أيقونة المركبة',
    'vehicleVwBus': 'حافلة فولكسفاغن',
    'vehicleVespa': 'فيسبا',
    'vehicleTaxi': 'تاكسي',
    'vehicleCamel': 'جمل',
    'vehicleArrow': 'سهم',
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
    'csvExportSuccess': 'تم تصدير ملف CSV',
    'optional': 'اختياري',
    'optionalPoint': 'نقطة اختيارية',
    'markOptional': 'اجعلها اختيارية',
    'markRequired': 'اجعلها إلزامية',
    'activate': 'تفعيل',
    'deactivate': 'تعطيل',
    'activateStopTitle': 'تضمين هذه النقطة؟',
    'activateStopMsg':
        'تضمينها رح يغيّر مسارك. أعد التحسين الآن لإضافتها، أو احذف النقطة.',
    'reoptimizeNow': 'أعد التحسين',
    'skipStop': 'تخطّى هذه النقطة',
    'includeStop': 'ضمّنها بالمسار',
    'optionalBadge': 'اختيارية',
    'deactivatedBadge': 'معطّلة',
    'addOptionalHere': 'أضف نقطة اختيارية هنا',
    'moveOnMap': 'تعديل الموقع على الخريطة',
    'movePointTitle': 'تحريك النقطة',
    'movePointHint': 'اسحب النقطة المميّزة على الخريطة ثم احفظ الموقع الجديد.',
    'saveLocation': 'حفظ الموقع',
    'locationUpdated': 'تم تحديث الموقع',
    'addStop': 'إضافة نقطة',
    'addOptionalStop': 'إضافة نقطة اختيارية',
    'addByTap': 'من الخريطة',
    'addMethods': 'إضافة نقاط',
    'keepAddingHint': 'يمكنك متابعة إضافة أي عدد من النقاط.',
    'offlineTitle': 'غير متصل',
    'offlineBody': 'لا يوجد إنترنت — يتم حفظ تعديلاتك على هذا الجهاز.',
    'offlineActionUnavailable': 'هذه العملية تحتاج اتصالاً بالإنترنت.',
    'draftRestoredMsg': 'تمت استعادة عملك المحفوظ.',
    'savedLocallyNote': 'محفوظ على جهازك',
    'errNoActiveStops': 'فعّل نقطة واحدة على الأقل قبل تحسين المسار.',
    'noAddressesFound':
        'لم يتم العثور على أي عنوان. تحقق من النص وحاول مجدداً.',
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
    'offlineMapTitle': 'خريطة هذه الرحلة دون إنترنت',
    'offlineMapIdleHint': 'نزّلها لتبقى الخريطة ظاهرة عند انقطاع الشبكة.',
    'offlineMapNoTrip': 'تصبح متاحة بعد أن يجهز المسار.',
    'offlineMapDownloading': 'جارٍ تنزيل الخريطة…',
    'offlineMapReady': 'محفوظة على جهازك',
    'offlineMapPartial': 'لم يكتمل تنزيل الخريطة — اضغط لإتمامها.',
    'offlineMapFailed': 'تعذّر تنزيل الخريطة.',
    'offlineMapDownload': 'تنزيل',
    'offlineMapRetry': 'إتمام',
    'offlineMapCancel': 'إلغاء',
    'offlineMapDelete': 'حذف',
    'offlineMapNeedsConnection': 'يحتاج تنزيل الخريطة اتصالاً بالإنترنت.',
    'offlineMapPreparing': 'جارٍ تحضير التنزيل…',
    'offlineMapCancelling': 'جارٍ الإيقاف…',
    'offlineMapCancelled': 'أوقفتَ التنزيل، وما نُزّل محفوظ.',
    'offlineMapResume': 'متابعة',
    'offlineAreaTitle': 'خريطة دون إنترنت',
    'offlineAreaHint':
        'احفظ أي منطقة من الخريطة لتبقى شوارعها ظاهرة عند انقطاع الشبكة، '
        'مع رحلة أو بدونها.',
    'offlineAreaNotSaved': 'غير محفوظة',
    'offlineAreaUpdate': 'تحديث',
    'offlineAreaNeedsLocation': 'نحتاج موقعك لتوسيط الخريطة عليه.',
    'offlineAreaDeleteTitle': 'حذف الخريطة المحفوظة؟',
    'offlineAreaDeleteMessage':
        'ستُحذف الخريطة المحفوظة من هذا الجهاز، ويمكنك تنزيلها من جديد متى '
        'توفّر اتصال بالإنترنت.',
    'offlineAreaPickTitle': 'اختر المنطقة المراد حفظها',
    'offlineAreaPickHint': 'حرّك الخريطة حتى يضمّ الإطار ما تحتاجه.',
    'offlineAreaMeasuring': 'جارٍ قياس المنطقة…',
    'offlineAreaTooLarge':
        'المنطقة أكبر مما يمكن تنزيله — قرّب الخريطة قليلًا.',
    'offlineAreaMyLocation': 'توسيط على موقعي',
    'offlineAreaSavedHere': 'هذه المنطقة محفوظة',
    'offlineAreaAtCeiling':
        'بلغتَ الحد الأقصى للمناطق المحفوظة — احذف واحدة أولًا.',
    'arrivalTime': 'وقت توفّر العميل',
    'setArrivalTime': 'حدّد وقت توفّر العميل',
    'clearArrivalTime': 'إزالة وقت التوفّر',
    'arrivalWindowHint': 'سيرتّب المُحسِّن نقاطك كي تصل ضمن فترة توفّر العميل.',
    'anyTime': 'متوفّر في أي وقت',
    'fromTime': 'من',
    'toTime': 'إلى',
    'departureTimeLabel': 'وقت الانطلاق',
    'departureNow': 'الآن',
    'departureHint': 'تُحتسب أوقات الوصول ابتداءً من هذه اللحظة.',
    'timeWindowMissedTitle': 'يتعذّر الوصول ضمن فترة التوفّر',
    'timeWindowMissedBody':
        'النقاط ما زالت ضمن مسارك — عدّل فترة توفّرها، أو وقت الانطلاق، أو استثنِ نقطة.',
    'timeWindowMissedBadge': 'متأخر',
    'sameTimeError': 'اختر وقتين مختلفين.',
    'seeDetails': 'اطّلع على الحلول المتاحة',
    'youWantedToArrive': 'فترة توفّر العميل',
    'youWouldArrive': 'وقت وصولك المتوقّع',
    'howToFixIt': 'كيف تعالج ذلك',
    'fixMoveDeadline': 'تأجيل فترة التوفّر',
    'fixMoveDeadlineWhy':
        'تبقى جميع النقاط، وتُؤجَّل كل فترة متعذّرة إلى ما بعد المدة التي يستغرقها الطريق فعلياً.',
    'fixLeaveEarlier': 'الانطلاق مبكراً',
    'fixLeaveEarlierWhy':
        'تبقى فترات التوفّر كما هي، ويبدأ المسار في وقت أبكر.',
    'fixDropStop': 'استثناء نقطة',
    'fixDropStopWhy': 'يوفّر الوقت الذي تحتاجه بقية فترات التوفّر.',
    'keepAsIs': 'إبقاء الوضع كما هو',
    'expectedArrival': 'وصولك',
    'requiredArrival': 'التوفّر',
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
    'previewBadge': 'معاينة',
    'previewStartDrive': 'جاهز؟ ابدأ القيادة',
    'endTrip': 'إنهاء الرحلة',
    'moreActions': 'المزيد',
    'googleMapsShort': 'خرائط Google',
    'openWithMaps': 'فتح في الخرائط',
    'newRouteShort': 'جديدة',
    'startFresh': 'احذف اللفة وابدأ من جديد',
    'replay': 'إعادة التشغيل',
    'arrivedHere': 'تم الوصول',
    'pointServed': 'تمت الخدمة',
    'rerouting': 'جارٍ إعادة حساب المسار…',
    'reoptimize': 'إعادة التحسين',
    'endOfDay': 'أين ينتهي اليوم',
    'finishRoundTrip': 'العودة إلى نقطة الانطلاق',
    'finishRoundTripHint': 'تنتهي اللفة حيث بدأت.',
    'finishOpen': 'التوقف عند آخر نقطة',
    'finishOpenHint': 'بدون رحلة عودة. ينتهي اليوم عند آخر نقطة.',
    'finishCustom': 'مكان آخر',
    'finishCustomHint': 'انهِ اللفة في مكان تختاره، مثل المنزل.',
    'finishPointLabel': 'نقطة النهاية',
    'finishPickPlace': 'اختر المكان',
    'toLabel': 'إلى',
    'setFinishHere': 'أنهِ اليوم هنا',
    'view3d': 'إمالة الخريطة',
    'viewFlat': 'تسطيح الخريطة',
    'finishEndsAt': 'ينتهي اليوم عند {stop}',
    'reCenter': 'إعادة التمركز',
    'arrivalLabel': 'الوصول',
    'speedUnitKmh': 'كم/س',
    'manTurnLeft': 'انعطف يسارًا',
    'manTurnRight': 'انعطف يمينًا',
    'manSlightLeft': 'انحرف قليلًا لليسار',
    'manSlightRight': 'انحرف قليلًا لليمين',
    'manSharpLeft': 'انعطف بحدة لليسار',
    'manSharpRight': 'انعطف بحدة لليمين',
    'manUTurn': 'قم بالالتفاف للخلف',
    'manStraight': 'تابع للأمام',
    'manMerge': 'اندمج مع الطريق',
    'manKeepLeft': 'الزم اليسار',
    'manKeepRight': 'الزم اليمين',
    'manOnRamp': 'اسلك المدخل',
    'manOffRamp': 'اسلك المخرج',
    'manRoundabout': 'ادخل الدوار',
    'manRoundaboutExit': 'عند الدوار، اسلك المخرج {n}',
    'manArrive': 'أنت تصل إلى محطتك',
    'continueToward': 'تابع نحو {stop}',
    'onbSkip': 'تخطّي',
    'onbNext': 'التالي',
    'onbBack': 'السابق',
    'onbGetStarted': 'لنبدأ',
    'onbWelcomeTitle': 'أهلاً بك في لفّة',
    'onbWelcomeBody': 'خطّط أذكى مسار يمرّ بكل نقاطك — خلال ثوانٍ.',
    'onbLanguageLabel': 'اختر لغتك',
    'onbPlanTitle': 'أضف نقاطك واحصل على أفضل ترتيب',
    'onbPlanBody':
        'حرّك الخريطة واضغط لإضافة كل نقطة، ولفّة ترتّبها تلقائياً في أسرع مسار.',
    'onbImportTitle': 'أضف نقاطاً من واتساب مباشرة',
    'onbImportBody':
        'شارك موقعاً إلى لفّة ليظهر مباشرة على مسارك دون كتابة. ويمكنك أيضاً استيراد ملف CSV أو لصق قائمة عناوين.',
    'onbImportTitleIos': 'أضف نقاطاً من واتساب عبر خرائط Google',
    'onbImportIosStep1': 'اضغط الموقع في واتساب',
    'onbImportIosStep2': 'في خرائط Google، اضغط زر المشاركة',
    'onbImportIosStep3': 'اختر لفّة',
    'onbImportBodyIos':
        'اضغط الموقع في واتساب ليفتح في خرائط Google، ثم اضغط زر المشاركة واختر لفّة — تنزل النقطة على مسارك. ويمكنك أيضاً استيراد ملف CSV أو لصق قائمة عناوين.',
    'onbImportWhatsappTag': 'واتساب',
    'onbImportCsvTag': 'CSV ولصق',
    'onbShareToLaffah': 'فتح بواسطة لفّة',
    'addOptHeader': 'كيف تريد إضافة نقاطك؟',
    'addOptManualTitle': 'إضافة يدوية',
    'addOptManualSub': 'ضع دبوساً على الخريطة',
    'addOptWhatsappTitle': 'من واتساب',
    'addOptWhatsappSub': 'شارك موقعاً إلى لفّة',
    'addOptImportTitle': 'لصق أو استيراد',
    'addOptImportSub': 'قائمة عناوين أو ملف CSV',
    'addOptManualBack': 'اختر طريقة أخرى',
    'importChooserTitle': 'أضف عدة نقاط',
    'importChooserPaste': 'لصق قائمة عناوين',
    'importChooserCsv': 'استيراد ملف CSV',
    'importCsvSub': 'العناوين والأسماء والأرقام دفعة واحدة',
    'addMethodTitle': 'كيف تريد إضافة هذه النقطة؟',
    'addMethodAddress': 'اكتب عنواناً',
    'addMethodAddressSub': 'ابحث واختر عنواناً واحداً',
    'addMethodMap': 'اختر على الخريطة',
    'addMethodMapSub': 'ضع دبوساً في المكان المطلوب',
    'addMethodPasteLinkSub': 'شارك المكان إلى لفّة أو الصق رابطه',
    'pasteLocationTitle': 'الصق موقع من Google',
    'pasteLocationSub': 'الصق رابط خرائط Google وسنضع الدبوس مكانه',
    'pasteLocationPlaceholder': 'الصق رابط الخريطة…',
    'pasteLocationAdd': 'أضف النقطة',
    'pasteLocationInvalid': 'لم نجد موقعاً في هذا الرابط',
    'pasteFromClipboard': 'الصق من الحافظة',
    'addressSearchTitle': 'ابحث عن عنوان',
    'addressSearchPlaceholder': 'شارع، مكان، مدينة…',
    'addressSearchPrompt': 'ابدأ الكتابة للبحث عن عنوان',
    'addressSearchEmpty': 'لا نتائج. جرّب بحثاً مختلفاً.',
    'addressSearchRecents': 'أماكن سابقة',
    'addressSearchNearby': 'قريب منك',
    'addressSearchRefining': 'ما زال البحث جارياً…',
    'searchPastedCoordinates': 'الموقع الذي لصقته',
    'mapLabelKindCity': 'مدينة',
    'mapLabelKindArea': 'حي',
    'mapLabelKindRegion': 'محافظة',
    'mapLabelKindStreet': 'شارع',
    'mapPlaceAddStop': 'أضِفها كمحطة',
    'mapPlaceSetDeparture': 'ابدأ الرحلة من هنا',
    'mapPlaceAlreadyAdded': 'هذا المكان موجود في المسار',
    'catFuel': 'محطة وقود',
    'catPharmacy': 'صيدلية',
    'catHospital': 'مشفى',
    'catBank': 'مصرف',
    'catAtm': 'صراف آلي',
    'catRestaurant': 'مطعم',
    'catCafe': 'مقهى',
    'catSupermarket': 'سوبر ماركت',
    'catBakery': 'مخبز',
    'catMosque': 'دار عبادة',
    'catSchool': 'مدرسة',
    'catUniversity': 'جامعة',
    'catHotel': 'فندق',
    'catParking': 'موقف سيارات',
    'catPolice': 'مركز شرطة',
    'catPost': 'مكتب بريد',
    'catCarRepair': 'تصليح سيارات',
    'catBusStation': 'محطة حافلات',
    'catMarket': 'سوق',
    'catPark': 'حديقة',
    'placePointHint': 'حرّك الخريطة ثم أكّد',
    'whatsappOpenFailed': 'تعذّر فتح واتساب',
    'openWhatsappCta': 'افتح واتساب',
    'gmapsInfoTitle': 'أضف نقطة من خرائط Google',
    'gmapsInfoBody':
        'ابحث عن المكان في خرائط Google، اضغط مشاركة، ثم اختر لفّة — تنزل النقطة على مسارك. أو انسخ الرابط والصقه هنا.',
    'openGoogleMapsCta': 'افتح خرائط Google',
    'pasteLinkCta': 'الصق رابطاً',
    'waInfoBody':
        'في واتساب، اضغط على الموقع المُشارَك واختر «فتح بواسطة لفّة» — يفتح التطبيق والنقطة جاهزة على مسارك. كرّر الخطوات لكل نقطة جديدة، لتضاف فوق السابقة.',
    'waInfoBodyIos':
        'في واتساب، اضغط على الموقع المُشارَك ثم افتحه في خرائط Google (أو خرائط آبل). ومن هناك اضغط زر المشاركة واختر لفّة — يفتح التطبيق والنقطة جاهزة على مسارك. كرّر الخطوات لكل نقطة جديدة، لتضاف فوق السابقة.',
    'whereTo': 'إلى أين؟',
    'whereToHint': 'ابحث عن مكان أو عنوان',
    'destinationTitle': 'الوجهة',
    'goNow': 'انطلق',
    'findingRoute': 'جارٍ إيجاد الطريق…',
    'routeUnavailableTapGo': 'اضغط انطلق للحصول على الطريق',
    'addAnotherStop': 'أضف وجهة أخرى',
    'addAnotherStopSub': 'لفة ترتّبها لك بأفضل تسلسل',
    'changeDestination': 'تغيير الوجهة',
    'fromLabel': 'من',
    'currentLocationLabel': 'موقعي الحالي',
    'startFromTitle': 'ابدأ من',
    'useCurrentLocation': 'استخدم موقعي الحالي',
    'useCurrentLocationSub': 'تبدأ الرحلة من مكانك الحالي',
    'orPickAPlace': 'أو حدّد مكاناً',
    'tripShapeTitle': 'نوع الرحلة',
    'tripShapeSingle': 'وجهة واحدة',
    'tripShapeSingleHint': 'إلى مكان واحد وبأسرع طريق',
    'tripShapeMulti': 'نقاط متعددة',
    'multiStopCtaSub': 'أضف كل نقاطك ولفّة ترتّبها لك',
    'methodShortMap': 'على الخريطة',
    'methodShortLink': 'خرائط Google',
    'methodShortWhatsapp': 'واتساب',
    'addPointCta': 'أضف نقطة',
    'pressBackAgainToExit': 'اضغط رجوع مرة أخرى للخروج',
    'onbLocationTitle': 'حدّد نقطة انطلاقك',
    'onbLocationBody':
        'اسمح بالوصول إلى الموقع ليحدّد لفّة نقطة انطلاقك ويرشدك أثناء القيادة.',
    'onbAllowLocation': 'السماح بالموقع',
    'onbMaybeLater': 'لاحقاً',
    // ── Auth / Onboarding ──
    'languageLabel': 'اللغة',
    'termsAndPrivacy': 'الشروط وسياسة الخصوصية',
    'welcomeTitle': 'خطّط مساراتك بذكاء',
    'welcomeBody': 'رتّب محطّاتك، احفظ رحلاتك، ووصّل أسرع إلى وجهتك.',
    'welcomeCreateAccount': 'إنشاء حساب',
    'welcomeHaveAccount': 'لدي حساب',
    'welcomeSkip': 'تخطّي الآن',
    'authContinue': 'متابعة',
    'authBack': 'رجوع',
    'edit': 'تعديل',
    'signInTitle': 'مرحباً بعودتك',
    'signInButton': 'تسجيل الدخول',
    'signInNoAccount': 'ليس لديك حساب؟',
    'signInCreateNew': 'إنشاء حساب جديد',
    'signInSubtitle': 'سجّل دخولك برقم هاتفك لتستعيد رحلاتك.',
    'forgotPassword': 'نسيت كلمة المرور؟',
    'phoneLabel': 'رقم الهاتف',
    'countrySearchHint': 'ابحث عن الدولة',
    'passwordLabel': 'كلمة المرور',
    'passwordHint': '8 محارف على الأقل',
    'passwordConfirmLabel': 'تأكيد كلمة المرور',
    'passwordConfirmHint': 'أعد إدخال كلمة المرور',
    'passwordShow': 'إظهار كلمة المرور',
    'passwordHide': 'إخفاء كلمة المرور',
    'createAccountTitle': 'إنشاء حساب',
    'stepCounter': 'الخطوة {n} من {total}',
    'stepCredentialsTitle': 'رقم هاتفك وكلمة المرور',
    'stepCredentialsSubtitle':
        'ستسجّل دخولك برقم هاتفك. اختر كلمة مرور من 8 محارف على الأقل.',
    'nameQuestion': 'ما اسمك؟',
    'nameHint': 'أدخل اسمك الكامل.',
    'companyQuestion': 'ما اسم الشركة التي تعمل فيها؟',
    'companyHint': 'أدخل اسم الشركة.',
    'useCaseQuestion': 'لماذا تريد استخدام التطبيق؟ يمكنك اختيار أكثر من خيار.',
    'useCaseOtherHint': 'اكتب كيف تريد استخدام التطبيق.',
    'useCaseSelectAtLeastOne': 'اختر خياراً واحداً على الأقل للمتابعة.',
    'summaryTitle': 'راجع معلوماتك',
    'summaryPhone': 'رقم الهاتف',
    'summaryName': 'الاسم الكامل',
    'summaryCompany': 'الشركة',
    'summaryUseCases': 'أسباب الاستخدام',
    'finishButton': 'ابدأ الآن',
    'successTitle': 'ممتاز، أصبح حسابك جاهزاً.',
    'ucDelivery': 'التوصيل',
    'ucPersonalUse': 'الاستخدام الشخصي',
    'ucNavigation': 'الملاحة والتنقل',
    'ucDriver': 'العمل كسائق',
    'ucDeliveryDriver': 'مندوب توصيل',
    'ucFleetManagement': 'إدارة أسطول مركبات',
    'ucBusinessManagement': 'إدارة أعمال أو شركة',
    'ucRoutePlanning': 'تخطيط الرحلات والمسارات',
    'ucFieldOperations': 'متابعة العمليات الميدانية',
    'ucFieldSales': 'المبيعات والزيارات الميدانية',
    'ucOther': 'استخدام آخر',
    'forgotPasswordTitle': 'نسيت كلمة المرور',
    'forgotPasswordBody': 'لاستعادة حسابك، تواصل مع فريق الدعم.',
    'contactSupport': 'تواصل مع الدعم',
    'whatsappForgotMessage': 'لقد نسيت كلمة المرور',
    'nudgeTitle': 'أنشئ حسابك',
    'nudgeBody': 'احفظ مساراتك واحتفظ بها عبر أجهزتك.',
    'nudgeDismiss': 'ليس الآن',
    'nudgeLater': 'لاحقاً',
    'registrationRequiredTitle': 'يلزم إنشاء حساب للمتابعة',
    'registrationRequiredBody':
        'انتهت مدة استخدام التطبيق دون حساب. أنشئ حساباً، أو سجّل الدخول، '
        'لمتابعة تخطيط مساراتك.',
    'registrationRequiredNote':
        'إنشاء الحساب يستغرق أقل من دقيقة، وتبقى مساراتك المحفوظة معك.',
    'welcomeSignInInstead': 'تسجيل الدخول بدلاً من ذلك',
    'account': 'الحساب',
    'accountSignedIn': 'مسجّل الدخول',
    'accountGuest': 'غير مسجّل',
    'accountGuestHint': 'سجّل دخولك لتحتفظ برحلاتك',
    'signOut': 'تسجيل الخروج',
    'signOutConfirmTitle': 'تسجيل الخروج؟',
    'signOutConfirmBody':
        'يمكنك تسجيل الدخول مجدداً في أي وقت برقم هاتفك. لن يُحذف أي شيء.',
    'signOutDone': 'تم تسجيل الخروج.',
    'deleteAccount': 'حذف الحساب',
    'deleteAccountTitle': 'حذف حسابك؟',
    'deleteAccountBody': 'سيتم حذف ما يلي نهائياً:',
    'deleteAccountItemLogin': 'رقم هاتفك وبيانات تسجيل الدخول',
    'deleteAccountItemProfile': 'اسمك وشركتك وأسباب الاستخدام المختارة',
    'deleteAccountItemLocation': 'آخر موقع محفوظ لك',
    'deleteAccountItemRoutes': 'لفاتك المحفوظة على جميع الأجهزة',
    'deleteAccountIrreversible':
        'لا يمكن التراجع عن هذا. ستحتاج إلى إنشاء حساب جديد لتسجيل الدخول مرة أخرى.',
    'deleteAccountAck': 'أفهم أن هذا الإجراء نهائي',
    'deleteAccountConfirm': 'حذف نهائي',
    'deleteAccountDone': 'تم حذف حسابك وبياناته.',
    'valTermsRequired':
        'الرجاء الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة.',
    'legalTitle': 'المستندات القانونية',
    'settingsGroupAccount': 'الحساب',
    'settingsGroupTrip': 'الرحلة',
    'settingsGroupMap': 'الخريطة',
    'settingsGroupPreferences': 'التفضيلات',
    'settingsGroupAbout': 'عن التطبيق',
    'legalPrivacy': 'سياسة الخصوصية',
    'legalTerms': 'شروط الاستخدام',
    'legalAccountDeletion': 'حذف الحساب',
    'consentTemplate': 'أوافق على {terms} و{privacy}.',
    'errInvalidCredentials': 'رقم الهاتف أو كلمة المرور غير صحيحة.',
    'errPhoneInUse': 'يوجد حساب مرتبط بهذا الرقم. جرّب تسجيل الدخول.',
    'errWeakPassword': 'اختر كلمة مرور أقوى.',
    'errRateLimited': 'محاولات كثيرة. حاول مرة أخرى لاحقاً.',
    'errAuthNetwork': 'لا يوجد اتصال بالإنترنت. تحقّق وحاول مجدداً.',
    'errSignupsDisabled': 'إنشاء الحسابات غير متاح حالياً.',
    'errBackendUnavailable': 'الخدمة غير متاحة حالياً.',
    'errUnknownAuth': 'حدث خطأ ما. حاول مرة أخرى.',
    'valPasswordRequired': 'الرجاء إدخال كلمة المرور.',
    'valPasswordTooShort': 'يجب أن تكون كلمة المرور 8 محارف على الأقل.',
    'valPasswordConfirmRequired': 'الرجاء تأكيد كلمة المرور.',
    'valPasswordMismatch': 'كلمتا المرور غير متطابقتين.',
    'valNameRequired': 'الرجاء إدخال اسمك.',
    'valNameTooShort': 'الاسم قصير جداً.',
    'valNameTooLong': 'الاسم طويل جداً.',
    'valNameNumeric': 'الرجاء إدخال اسم صالح.',
    'valCompanyRequired': 'الرجاء إدخال اسم الشركة.',
    'valCompanyTooShort': 'اسم الشركة قصير جداً.',
    'valCompanyTooLong': 'اسم الشركة طويل جداً.',
    'valPhoneInvalid': 'الرجاء إدخال رقم هاتف صالح.',
    'valPhoneRequired': 'الرجاء إدخال رقم هاتفك.',
    'valPhoneTooShort': 'الرقم قصير بالنسبة لـ{country}. مثال: {example}',
    'valPhoneTooLong': 'الرقم طويل بالنسبة لـ{country}. مثال: {example}',
    'valPhoneNotMobile': 'هذا ليس رقم موبايل في {country}. مثال: {example}',
  },
  'fr': {
    'appName': 'Laffah',
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
    'enableLocationCta': 'Activer la localisation',
    'pointAdded': 'Point ajoute',
    'stopPhoneTitle': 'Numero de telephone',
    'stopPhoneHint': 'Avec l\'indicatif du pays, ex. +963944123456',
    'stopPhoneAdd': 'Ajouter un numero',
    'stopPhoneEdit': 'Modifier le numero',
    'stopCall': 'Appeler',
    'stopWhatsapp': 'WhatsApp',
    'stopWhatsappOnTheWay': 'Bonjour, je suis en route vers vous.',
    'stopWhatsappArrived': 'Bonjour, je suis arrive a votre adresse.',
    'stopCallFailed': "Impossible de lancer l'appel",
    'locGateTitle': 'Laffah a besoin de votre position',
    'locGateBody':
        'Votre itineraire part de la ou vous etes, et la carte vous suit pendant la conduite.',
    'locGateBlockedBody':
        "La position est bloquee pour Laffah. Ouvrez les reglages de l'app pour l'autoriser.",
    'locGateContinue': 'Continuer sans position',
    'errInvalidResponse': 'Reponse invalide du serveur',
    'errEmptyOptimizedRoute':
        'Le modele n\'a renvoye aucun itineraire optimise',
    'errTimeout': 'La connexion au serveur a expire',
    'errLaffaUnreadable': 'Cette tournee n\'a pas pu etre ouverte.',
    'laffaReplaceTitle': 'Ouvrir cette tournee ?',
    'laffaReplaceMessage': 'Elle remplace les arrets actuellement sur le telephone.',
    'laffaReplaceConfirm': 'Ouvrir',
    'laffaImported': 'Tournee chargee — {n} arrets.',
    'errServerConnection': 'Impossible de se connecter au serveur',
    'errRouteOptimizationFailed': 'Echec de l\'optimisation du trajet',
    'errOneDepotRequired': 'Un seul point de depart est requis',
    'errMinOneStopAfterDepot':
        'Veuillez choisir au moins une destination apres le point de depart',
    'errLocalStorageWrite': 'Impossible d\'ecrire dans le stockage local',
    'errSavedRoutesLoad': 'Impossible de charger les trajets enregistres',
    'errSavedRouteSave': 'Impossible d\'enregistrer le trajet',
    'removePointTitle': 'Supprimer ce point ?',
    'removePointBody':
        'Il quitte le trajet. Vos autres arrets restent en place.',
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
    'addOneStopToOptimize': 'Ajoutez votre premier arret',
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
    'recenter': 'Recentrer',
    'resetView': 'Réinitialiser la vue',
    'cameraChase': 'Cinematique',
    'headedTo': 'Direction',
    'departingFrom': 'Depart de',
    'arrived': 'Arrive!',
    'progress': 'Progression',
    'remainingDistance': 'Distance restante',
    'remainingTime': 'Temps restant',
    'focusMode': 'Focus',
    'driveControls': 'Commandes du trajet',
    'exitFocus': 'Quitter',
    'remainingShort': 'restant',
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
    'aboutUs': 'À propos',
    'language': 'Langue',
    'appearance': 'Apparence',
    'vehicleIcon': 'Icône du véhicule',
    'vehicleVwBus': 'Combi VW',
    'vehicleVespa': 'Vespa',
    'vehicleTaxi': 'Taxi',
    'vehicleCamel': 'Chameau',
    'vehicleArrow': 'Flèche',
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
    'csvExportSuccess': 'Fichier CSV exporté',
    'optional': 'Optionnel',
    'optionalPoint': 'Point optionnel',
    'markOptional': 'Rendre optionnel',
    'markRequired': 'Rendre obligatoire',
    'activate': 'Activer',
    'deactivate': 'Désactiver',
    'activateStopTitle': 'Rajouter cet arrêt ?',
    'activateStopMsg':
        'L\'inclure modifie votre trajet. Réoptimisez pour l\'ajouter, ou supprimez l\'arrêt.',
    'reoptimizeNow': 'Réoptimiser',
    'skipStop': 'Ignorer cet arrêt',
    'includeStop': 'Ajouter au trajet',
    'optionalBadge': 'Optionnel',
    'deactivatedBadge': 'Inactif',
    'addOptionalHere': 'Ajouter un arrêt optionnel ici',
    'moveOnMap': 'Déplacer sur la carte',
    'movePointTitle': 'Déplacer le point',
    'movePointHint':
        'Faites glisser le point en surbrillance, puis enregistrez.',
    'saveLocation': 'Enregistrer l\'emplacement',
    'locationUpdated': 'Emplacement mis à jour',
    'addStop': 'Ajouter un arrêt',
    'addOptionalStop': 'Ajouter un arrêt optionnel',
    'addByTap': 'Depuis la carte',
    'addMethods': 'Ajouter des points',
    'keepAddingHint': 'Continuez à ajouter autant de points que nécessaire.',
    'offlineTitle': 'Hors ligne',
    'offlineBody':
        'Pas de connexion — vos modifications sont enregistrées sur cet appareil.',
    'offlineActionUnavailable':
        'Cette action nécessite une connexion Internet.',
    'draftRestoredMsg': 'Nous avons restauré votre travail enregistré.',
    'savedLocallyNote': 'Enregistré sur votre appareil',
    'errNoActiveStops': 'Activez au moins un arrêt avant l\'optimisation.',
    'noAddressesFound':
        'Aucune adresse trouvée. Vérifiez le texte et réessayez.',
    'exportCsv': 'Exporter CSV',
    'csvImportEmpty': 'Aucun point trouve dans ce fichier CSV',
    'csvImportFailed': 'Impossible d\'importer le fichier CSV',
    'csvExportFailed': 'Impossible d\'exporter le fichier CSV',
    'csvNoPoints': 'Aucun point a exporter',
    'csvShareText': 'Trajet Laffah au format CSV',
    'departureBadge': 'Depart',
    'returnBadge': 'Retour',
    'routeOrder': 'Ordre du trajet',
    'points': 'points',
    'offlineMapTitle': 'Carte hors ligne pour ce trajet',
    'offlineMapIdleHint':
        'Telechargez-la et la carte reste affichee sans reseau.',
    'offlineMapNoTrip': 'Disponible une fois l\'itineraire pret.',
    'offlineMapDownloading': 'Telechargement de la carte…',
    'offlineMapReady': 'Enregistree sur votre appareil',
    'offlineMapPartial': 'La carte est incomplete — appuyez pour la finir.',
    'offlineMapFailed': 'Telechargement de la carte impossible.',
    'offlineMapDownload': 'Telecharger',
    'offlineMapRetry': 'Terminer',
    'offlineMapCancel': 'Annuler',
    'offlineMapDelete': 'Supprimer',
    'offlineMapPreparing': 'Preparation du telechargement…',
    'offlineMapCancelling': 'Arret…',
    'offlineMapCancelled': 'Arrete. Ce qui est telecharge est conserve.',
    'offlineMapResume': 'Continuer',
    'offlineMapNeedsConnection':
        'Le telechargement de la carte necessite une connexion.',
    'offlineAreaTitle': 'Carte hors ligne',
    'offlineAreaHint':
        'Enregistrez n\'importe quelle zone de la carte et ses rues restent '
        'affichees sans reseau, avec ou sans trajet.',
    'offlineAreaNotSaved': 'Non enregistree',
    'offlineAreaUpdate': 'Mettre a jour',
    'offlineAreaNeedsLocation':
        'Votre position est necessaire pour centrer la carte sur vous.',
    'offlineAreaDeleteTitle': 'Supprimer la carte enregistree ?',
    'offlineAreaDeleteMessage':
        'La carte enregistree sera retiree de cet appareil. Vous pourrez '
        'la telecharger a nouveau des que vous aurez une connexion.',
    'offlineAreaPickTitle': 'Choisissez la zone a enregistrer',
    'offlineAreaPickHint':
        'Deplacez la carte pour que le cadre contienne ce qu\'il vous faut.',
    'offlineAreaMeasuring': 'Mesure de la zone…',
    'offlineAreaTooLarge': 'Trop a telecharger — zoomez un peu.',
    'offlineAreaMyLocation': 'Centrer sur moi',
    'offlineAreaSavedHere': 'Cette zone est enregistree',
    'offlineAreaAtCeiling':
        'Vous avez atteint la limite de zones — supprimez-en une.',
    'arrivalTime': 'Disponibilite du client',
    'setArrivalTime': 'Definir la disponibilite du client',
    'clearArrivalTime': 'Retirer le creneau de disponibilite',
    'arrivalWindowHint':
        'L\'optimiseur ordonne vos arrets pour arriver pendant la disponibilite du client.',
    'anyTime': 'Disponible a tout moment',
    'fromTime': 'De',
    'toTime': 'A',
    'departureTimeLabel': 'Depart',
    'departureNow': 'Maintenant',
    'departureHint': 'Les heures d\'arrivee sont comptees a partir d\'ici.',
    'timeWindowMissedTitle': 'Arrivee pendant la disponibilite impossible',
    'timeWindowMissedBody':
        'Ces arrets restent dans le trajet — changez leur disponibilite, le depart, ou retirez un arret.',
    'timeWindowMissedBadge': 'En retard',
    'sameTimeError': 'Choisissez deux heures differentes.',
    'seeDetails': 'Voir quoi faire',
    'youWantedToArrive': 'Le client est disponible',
    'youWouldArrive': 'Vous y seriez a',
    'howToFixIt': 'Comment corriger',
    'fixMoveDeadline': 'Elargir la disponibilite',
    'fixMoveDeadlineWhy':
        'Garde tous les arrets. Repousse chaque creneau impossible juste au-dela du temps de route reel.',
    'fixLeaveEarlier': 'Partir plus tot',
    'fixLeaveEarlierWhy': 'Garde chaque creneau tel quel et avance le depart.',
    'fixDropStop': 'Retirer un arret',
    'fixDropStopWhy': 'Libere le temps dont les autres creneaux ont besoin.',
    'keepAsIs': 'Laisser ainsi',
    'expectedArrival': 'Vous arrivez',
    'requiredArrival': 'Disponible',
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
    'previewBadge': 'Apercu',
    'previewStartDrive': 'Pret ? Demarrer',
    'endTrip': 'Terminer le trajet',
    'moreActions': 'Plus',
    'googleMapsShort': 'Google Maps',
    'openWithMaps': 'Ouvrir dans Maps',
    'newRouteShort': 'Nouveau',
    'startFresh': 'Supprimer le trajet et recommencer',
    'replay': 'Rejouer',
    'arrivedHere': 'Arrive',
    'pointServed': 'Point servi',
    'rerouting': 'Recalcul de l\'itineraire…',
    'reoptimize': 'Reoptimiser',
    'endOfDay': 'Fin de journee',
    'finishRoundTrip': 'Retour au depart',
    'finishRoundTripHint': 'Terminez la ou vous etes parti.',
    'finishOpen': 'Arret au dernier point',
    'finishOpenHint': 'Pas de retour. La journee finit au dernier point.',
    'finishCustom': 'Ailleurs',
    'finishCustomHint': 'Terminez a un endroit de votre choix, comme chez vous.',
    'finishPointLabel': 'Arrivee',
    'finishPickPlace': 'Choisir le lieu',
    'toLabel': 'Vers',
    'setFinishHere': 'Terminer la journee ici',
    'view3d': 'Incliner la carte',
    'viewFlat': 'Aplatir la carte',
    'finishEndsAt': 'La journee finit a {stop}',
    'reCenter': 'Recentrer',
    'arrivalLabel': 'Arrivee',
    'speedUnitKmh': 'km/h',
    'manTurnLeft': 'Tournez a gauche',
    'manTurnRight': 'Tournez a droite',
    'manSlightLeft': 'Restez legerement a gauche',
    'manSlightRight': 'Restez legerement a droite',
    'manSharpLeft': 'Virage serre a gauche',
    'manSharpRight': 'Virage serre a droite',
    'manUTurn': 'Faites demi-tour',
    'manStraight': 'Continuez tout droit',
    'manMerge': 'Inserez-vous sur la route',
    'manKeepLeft': 'Restez a gauche',
    'manKeepRight': 'Restez a droite',
    'manOnRamp': 'Prenez la bretelle',
    'manOffRamp': 'Prenez la sortie',
    'manRoundabout': 'Entrez dans le rond-point',
    'manRoundaboutExit': 'Au rond-point, prenez la sortie {n}',
    'manArrive': 'Arrivee a votre arret',
    'continueToward': 'Continuez vers {stop}',
    'onbSkip': 'Passer',
    'onbNext': 'Suivant',
    'onbBack': 'Retour',
    'onbGetStarted': 'Commencer',
    'onbWelcomeTitle': 'Bienvenue sur Laffah',
    'onbWelcomeBody':
        'Planifiez le meilleur itineraire passant par tous vos arrets — en quelques secondes.',
    'onbLanguageLabel': 'Choisissez votre langue',
    'onbPlanTitle': 'Ajoutez des arrets, obtenez le meilleur ordre',
    'onbPlanBody':
        'Deplacez la carte et touchez pour ajouter chaque arret. Laffah les remet automatiquement dans le trajet le plus rapide.',
    'onbImportTitle': 'Ajoutez des arrets depuis WhatsApp',
    'onbImportBody':
        'Partagez une position vers Laffah et elle apparait sur votre itineraire, sans saisie. Importer un CSV ou coller une liste fonctionne aussi.',
    'onbImportTitleIos': 'Ajoutez des arrets depuis WhatsApp via Google Maps',
    'onbImportIosStep1': 'Touchez la position dans WhatsApp',
    'onbImportIosStep2': 'Dans Google Maps, touchez le bouton de partage',
    'onbImportIosStep3': 'Choisissez Laffah',
    'onbImportBodyIos':
        "Touchez la position dans WhatsApp pour l'ouvrir dans Google Maps, puis touchez le bouton de partage et choisissez Laffah — l'arret arrive sur votre itineraire. Importer un CSV ou coller une liste fonctionne aussi.",
    'onbImportWhatsappTag': 'WhatsApp',
    'onbImportCsvTag': 'CSV et liste',
    'onbShareToLaffah': 'Ouvrir avec Laffah',
    'addOptHeader': 'Comment ajouter vos arrets ?',
    'addOptManualTitle': 'Ajout manuel',
    'addOptManualSub': 'Placez un point sur la carte',
    'addOptWhatsappTitle': 'Depuis WhatsApp',
    'addOptWhatsappSub': 'Partagez une position vers Laffah',
    'addOptImportTitle': 'Coller ou importer',
    'addOptImportSub': "Une liste d'adresses ou un CSV",
    'addOptManualBack': 'Choisir une autre methode',
    'importChooserTitle': 'Ajouter plusieurs arrets',
    'importChooserPaste': "Coller une liste d'adresses",
    'importChooserCsv': 'Importer un fichier CSV',
    'importCsvSub': 'Adresses, noms et numeros en une fois',
    'addMethodTitle': 'Comment ajouter ce point ?',
    'addMethodAddress': 'Saisir une adresse',
    'addMethodAddressSub': 'Rechercher et choisir une adresse',
    'addMethodMap': 'Choisir sur la carte',
    'addMethodMapSub': 'Placez un point où vous voulez',
    'addMethodPasteLinkSub': 'Partagez un lieu vers Laffah ou collez son lien',
    'pasteLocationTitle': 'Coller un lien Google Maps',
    'pasteLocationSub':
        'Collez un lien Google Maps — on y place le point automatiquement',
    'pasteLocationPlaceholder': 'Collez un lien Maps…',
    'pasteLocationAdd': 'Ajouter le point',
    'pasteLocationInvalid': 'Aucun lieu trouvé dans ce lien',
    'pasteFromClipboard': 'Coller depuis le presse-papiers',
    'addressSearchTitle': 'Rechercher une adresse',
    'addressSearchPlaceholder': 'Rue, lieu, ville…',
    'addressSearchPrompt': 'Commencez à taper pour rechercher une adresse',
    'addressSearchEmpty': 'Aucun résultat. Essayez autrement.',
    'addressSearchRecents': 'Lieux récents',
    'addressSearchNearby': 'À proximité',
    'addressSearchRefining': 'Recherche en cours…',
    'searchPastedCoordinates': 'Le lieu que vous avez collé',
    'mapLabelKindCity': 'Ville',
    'mapLabelKindArea': 'Quartier',
    'mapLabelKindRegion': 'Région',
    'mapLabelKindStreet': 'Rue',
    'mapPlaceAddStop': 'Ajouter comme arrêt',
    'mapPlaceSetDeparture': 'Partir d\'ici',
    'mapPlaceAlreadyAdded': 'Ce lieu est déjà sur l\'itinéraire',
    'catFuel': 'Station-service',
    'catPharmacy': 'Pharmacie',
    'catHospital': 'Hôpital',
    'catBank': 'Banque',
    'catAtm': 'Distributeur',
    'catRestaurant': 'Restaurant',
    'catCafe': 'Café',
    'catSupermarket': 'Supermarché',
    'catBakery': 'Boulangerie',
    'catMosque': 'Lieu de culte',
    'catSchool': 'École',
    'catUniversity': 'Université',
    'catHotel': 'Hôtel',
    'catParking': 'Parking',
    'catPolice': 'Poste de police',
    'catPost': 'Bureau de poste',
    'catCarRepair': 'Garage',
    'catBusStation': 'Gare routière',
    'catMarket': 'Marché',
    'catPark': 'Parc',
    'placePointHint': 'Déplacez la carte, puis confirmez',
    'whatsappOpenFailed': "Impossible d'ouvrir WhatsApp",
    'openWhatsappCta': 'Ouvrir WhatsApp',
    'gmapsInfoTitle': 'Ajouter un arret depuis Google Maps',
    'gmapsInfoBody':
        'Trouvez le lieu dans Google Maps, touchez Partager, puis choisissez Laffah — l\'arret arrive sur votre itineraire. Ou copiez le lien et collez-le ici.',
    'openGoogleMapsCta': 'Ouvrir Google Maps',
    'pasteLinkCta': 'Coller un lien',
    'waInfoBody':
        "Dans WhatsApp, touchez la position partagee et choisissez « Ouvrir avec Laffah » — l'app s'ouvre avec l'arret deja sur votre itineraire. Repetez pour chaque arret ; il s'ajoute aux precedents.",
    'waInfoBodyIos':
        "Dans WhatsApp, touchez la position partagee et ouvrez-la dans Google Maps (ou Plans). De la, touchez le bouton de partage et choisissez Laffah — l'app s'ouvre avec l'arret deja sur votre itineraire. Repetez pour chaque arret ; il s'ajoute aux precedents.",
    'whereTo': 'Ou allez-vous ?',
    'whereToHint': 'Cherchez un lieu ou une adresse',
    'destinationTitle': 'Destination',
    'goNow': 'Aller',
    'findingRoute':
        'Recherche de l'
        'itineraire…',
    'routeUnavailableTapGo':
        'Appuyez sur Aller pour obtenir l'
        'itineraire',
    'addAnotherStop': 'Ajouter un autre arret',
    'addAnotherStopSub': 'Laffeh les met dans le meilleur ordre',
    'changeDestination': 'Changer de destination',
    'fromLabel': 'De',
    'currentLocationLabel': 'Ma position actuelle',
    'startFromTitle': 'Partir de',
    'useCurrentLocation': 'Utiliser ma position actuelle',
    'useCurrentLocationSub': 'Le trajet part de la ou vous etes',
    'orPickAPlace': 'ou choisissez un lieu',
    'tripShapeTitle': 'Type de trajet',
    'tripShapeSingle': 'Une destination',
    'tripShapeSingleHint': 'Vers un seul lieu, au plus vite',
    'tripShapeMulti': 'Plusieurs arrets',
    'multiStopCtaSub': 'Ajoutez chaque arret — Laffeh les met en ordre',
    'methodShortMap': 'Sur la carte',
    'methodShortLink': 'Google Maps',
    'methodShortWhatsapp': 'WhatsApp',
    'addPointCta': 'Ajouter un arret',
    'pressBackAgainToExit': 'Appuyez encore pour quitter',
    'onbLocationTitle': 'Trouvez votre point de depart',
    'onbLocationBody':
        'Autorisez la localisation pour que Laffah definisse votre depart et vous guide pendant la conduite.',
    'onbAllowLocation': 'Autoriser la localisation',
    'onbMaybeLater': 'Plus tard',
    // ── Auth / Onboarding ──
    'languageLabel': 'Langue',
    'termsAndPrivacy': 'Conditions et confidentialité',
    'welcomeTitle': 'Planifiez des trajets plus intelligents',
    'welcomeBody':
        'Optimisez vos arrêts, enregistrez vos trajets et arrivez plus vite.',
    'welcomeCreateAccount': 'Créer un compte',
    'welcomeHaveAccount': 'J\'ai déjà un compte',
    'welcomeSkip': 'Passer pour l\'instant',
    'authContinue': 'Continuer',
    'authBack': 'Retour',
    'edit': 'Modifier',
    'signInTitle': 'Bon retour',
    'signInButton': 'Se connecter',
    'signInNoAccount': 'Vous n\'avez pas de compte ?',
    'signInCreateNew': 'Créer un nouveau compte',
    'signInSubtitle':
        'Connectez-vous avec votre numéro pour retrouver vos trajets.',
    'forgotPassword': 'Mot de passe oublié ?',
    'phoneLabel': 'Numéro de téléphone',
    'countrySearchHint': 'Rechercher un pays',
    'passwordLabel': 'Mot de passe',
    'passwordHint': 'Au moins 8 caractères',
    'passwordConfirmLabel': 'Confirmer le mot de passe',
    'passwordConfirmHint': 'Ressaisissez votre mot de passe',
    'passwordShow': 'Afficher le mot de passe',
    'passwordHide': 'Masquer le mot de passe',
    'createAccountTitle': 'Créer un compte',
    'stepCounter': 'Étape {n} sur {total}',
    'stepCredentialsTitle': 'Votre téléphone et mot de passe',
    'stepCredentialsSubtitle':
        'Vous vous connecterez avec votre numéro. Choisissez un mot de passe d\'au moins 8 caractères.',
    'nameQuestion': 'Comment vous appelez-vous ?',
    'nameHint': 'Saisissez votre nom complet.',
    'companyQuestion': 'Dans quelle entreprise travaillez-vous ?',
    'companyHint': 'Saisissez le nom de l\'entreprise.',
    'useCaseQuestion':
        'Pourquoi souhaitez-vous utiliser l\'application ? Vous pouvez sélectionner plusieurs options.',
    'useCaseOtherHint':
        'Expliquez-nous comment vous souhaitez utiliser l\'application.',
    'useCaseSelectAtLeastOne':
        'Sélectionnez au moins une option pour continuer.',
    'summaryTitle': 'Vérifiez vos informations',
    'summaryPhone': 'Numéro de téléphone',
    'summaryName': 'Nom complet',
    'summaryCompany': 'Entreprise',
    'summaryUseCases': 'Raisons d\'utilisation',
    'finishButton': 'Commencer',
    'successTitle': 'Parfait, votre compte est prêt.',
    'ucDelivery': 'Livraison',
    'ucPersonalUse': 'Usage personnel',
    'ucNavigation': 'Navigation et déplacements',
    'ucDriver': 'Travail en tant que conducteur',
    'ucDeliveryDriver': 'Livreur',
    'ucFleetManagement': 'Gestion de flotte',
    'ucBusinessManagement': 'Gestion d\'entreprise',
    'ucRoutePlanning': 'Planification des trajets et itinéraires',
    'ucFieldOperations': 'Opérations sur le terrain',
    'ucFieldSales': 'Ventes et visites sur le terrain',
    'ucOther': 'Autre utilisation',
    'forgotPasswordTitle': 'Mot de passe oublié',
    'forgotPasswordBody': 'Contactez le support pour récupérer votre compte.',
    'contactSupport': 'Contacter le support',
    'whatsappForgotMessage': 'J\'ai oublié mon mot de passe',
    'nudgeTitle': 'Créez votre compte',
    'nudgeBody': 'Enregistrez vos trajets et retrouvez-les sur vos appareils.',
    'nudgeDismiss': 'Pas maintenant',
    'nudgeLater': 'Plus tard',
    'registrationRequiredTitle': 'Un compte est nécessaire pour continuer',
    'registrationRequiredBody':
        'Votre semaine d\'utilisation sans compte est terminée. Créez un '
        'compte — ou connectez-vous — pour continuer à planifier vos trajets.',
    'registrationRequiredNote':
        'La création d\'un compte prend moins d\'une minute, et vos trajets '
        'enregistrés vous suivent.',
    'welcomeSignInInstead': 'Se connecter',
    'account': 'Compte',
    'accountSignedIn': 'Connecté',
    'accountGuest': 'Non connecté',
    'accountGuestHint': 'Connectez-vous pour conserver vos trajets',
    'signOut': 'Se déconnecter',
    'signOutConfirmTitle': 'Se déconnecter ?',
    'signOutConfirmBody':
        'Vous pourrez vous reconnecter à tout moment avec votre numéro. Rien n\'est supprimé.',
    'signOutDone': 'Déconnecté.',
    'deleteAccount': 'Supprimer le compte',
    'deleteAccountTitle': 'Supprimer votre compte ?',
    'deleteAccountBody': 'Ceci supprime définitivement :',
    'deleteAccountItemLogin': 'Votre numéro et vos identifiants de connexion',
    'deleteAccountItemProfile':
        'Votre nom, votre société et vos usages sélectionnés',
    'deleteAccountItemLocation': 'Votre dernière position enregistrée',
    'deleteAccountItemRoutes': 'Vos trajets enregistrés sur tous les appareils',
    'deleteAccountIrreversible':
        'Cette action est irréversible. Vous devrez créer un nouveau compte pour vous reconnecter.',
    'deleteAccountAck': 'Je comprends que cette action est définitive',
    'deleteAccountConfirm': 'Supprimer définitivement',
    'deleteAccountDone': 'Votre compte et ses données ont été supprimés.',
    'valTermsRequired':
        'Veuillez accepter les Conditions d\'utilisation et la Politique de confidentialité pour continuer.',
    'legalTitle': 'Documents légaux',
    'settingsGroupAccount': 'Compte',
    'settingsGroupTrip': 'Trajet',
    'settingsGroupMap': 'Carte',
    'settingsGroupPreferences': 'Preferences',
    'settingsGroupAbout': 'A propos',
    'legalPrivacy': 'Politique de confidentialité',
    'legalTerms': 'Conditions d\'utilisation',
    'legalAccountDeletion': 'Suppression du compte',
    'consentTemplate': 'J\'accepte les {terms} et la {privacy}.',
    'errInvalidCredentials': 'Numéro de téléphone ou mot de passe incorrect.',
    'errPhoneInUse':
        'Un compte est déjà associé à ce numéro. Essayez de vous connecter.',
    'errWeakPassword': 'Veuillez choisir un mot de passe plus fort.',
    'errRateLimited': 'Trop de tentatives. Réessayez plus tard.',
    'errAuthNetwork': 'Pas de connexion internet. Vérifiez et réessayez.',
    'errSignupsDisabled': 'Les inscriptions sont actuellement indisponibles.',
    'errBackendUnavailable': 'Le service est actuellement indisponible.',
    'errUnknownAuth': 'Une erreur s\'est produite. Veuillez réessayer.',
    'valPasswordRequired': 'Veuillez saisir un mot de passe.',
    'valPasswordTooShort':
        'Le mot de passe doit contenir au moins 8 caractères.',
    'valPasswordConfirmRequired': 'Veuillez confirmer votre mot de passe.',
    'valPasswordMismatch': 'Les mots de passe ne correspondent pas.',
    'valNameRequired': 'Veuillez saisir votre nom.',
    'valNameTooShort': 'Le nom est trop court.',
    'valNameTooLong': 'Le nom est trop long.',
    'valNameNumeric': 'Veuillez saisir un nom valide.',
    'valCompanyRequired': 'Veuillez saisir le nom de l\'entreprise.',
    'valCompanyTooShort': 'Le nom de l\'entreprise est trop court.',
    'valCompanyTooLong': 'Le nom de l\'entreprise est trop long.',
    'valPhoneInvalid': 'Veuillez saisir un numéro de téléphone valide.',
    'valPhoneRequired': 'Veuillez saisir votre numéro de téléphone.',
    'valPhoneTooShort': 'Trop court pour {country}. Exemple : {example}',
    'valPhoneTooLong': 'Trop long pour {country}. Exemple : {example}',
    'valPhoneNotMobile':
        'Ce n\'est pas un numéro mobile {country}. Exemple : {example}',
  },
};
