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
  static String get recenter => _t('recenter');
  static String get resetView => _t('resetView');
  static String get headedTo => _t('headedTo');
  static String get departingFrom => _t('departingFrom');
  static String get arrived => _t('arrived');
  static String get progress => _t('progress');
  static String get remainingDistance => _t('remainingDistance');
  static String get remainingTime => _t('remainingTime');
  static String get focusMode => _t('focusMode');
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
  static String get endTrip => _t('endTrip');
  static String get moreActions => _t('moreActions');
  static String get googleMapsShort => _t('googleMapsShort');
  static String get openWithMaps => _t('openWithMaps');
  static String get newRouteShort => _t('newRouteShort');
  static String get startFresh => _t('startFresh');
  static String get replay => _t('replay');

  // Drive mode — service points & turn guidance
  static String get pointServed => _t('pointServed');
  static String get autoServedNotice => _t('autoServedNotice');
  static String get rerouting => _t('rerouting');
  static String get reoptimize => _t('reoptimize');
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
  static String get whatsappOpenFailed => _t('whatsappOpenFailed');
  static String get waInfoBody => _t('waInfoBody');
  static String get addPointCta => _t('addPointCta');
  static String get addMethodTitle => _t('addMethodTitle');
  static String get addMethodAddress => _t('addMethodAddress');
  static String get addMethodAddressSub => _t('addMethodAddressSub');
  static String get addMethodMap => _t('addMethodMap');
  static String get addMethodMapSub => _t('addMethodMapSub');
  static String get addMethodPasteLink => _t('addMethodPasteLink');
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
  static String get valCompanyTooLong => _t('valCompanyTooLong');
  static String get valPhoneInvalid => _t('valPhoneInvalid');
  static String get valPhoneRequired => _t('valPhoneRequired');
  static String get valPhoneTooShort => _t('valPhoneTooShort');
  static String get valPhoneTooLong => _t('valPhoneTooLong');
  static String get valPhoneNotMobile => _t('valPhoneNotMobile');
  static String get valTermsRequired => _t('valTermsRequired');

  // ── Legal / consent ────────────────────────────────────
  static String get legalTitle => _t('legalTitle');
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
    'openWithMaps': 'Open with Maps',
    'newRouteShort': 'New',
    'startFresh': 'Delete trip & start fresh',
    'replay': 'Replay',
    'arrivedHere': 'Arrived',
    'pointServed': 'Point served',
    'autoServedNotice': 'Service point completed. Navigating to next stop.',
    'rerouting': 'Recalculating route…',
    'reoptimize': 'Re-optimize',
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
    'addMethodTitle': 'How do you want to add this point?',
    'addMethodAddress': 'Type an address',
    'addMethodAddressSub': 'Search and pick one address',
    'addMethodMap': 'Pick on the map',
    'addMethodMapSub': 'Drop a pin where you want',
    'addMethodPasteLink': 'Paste a Google location',
    'addMethodPasteLinkSub': 'Paste a Maps link you copied',
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
    'placePointHint': 'Move the map, then confirm',
    'whatsappOpenFailed': "Couldn't open WhatsApp",
    'waInfoBody':
        'In WhatsApp, tap the shared location and choose "Open with Laffah" — the app opens with the stop already on your route. Repeat for each new stop; it stacks onto the previous ones.',
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
    'deleteAccountIrreversible':
        'This cannot be undone. You will need to create a new account to sign in again.',
    'deleteAccountAck': 'I understand this is permanent',
    'deleteAccountConfirm': 'Delete permanently',
    'deleteAccountDone': 'Your account and its data have been deleted.',
    'valTermsRequired':
        'Please accept the Terms of Service and Privacy Policy to continue.',
    'legalTitle': 'Legal',
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
    'openWithMaps': 'فتح في الخرائط',
    'newRouteShort': 'جديدة',
    'startFresh': 'احذف اللفة وابدأ من جديد',
    'replay': 'إعادة التشغيل',
    'arrivedHere': 'تم الوصول',
    'pointServed': 'تمت الخدمة',
    'autoServedNotice': 'اكتملت خدمة النقطة. جارٍ التوجه إلى المحطة التالية.',
    'rerouting': 'جارٍ إعادة حساب المسار…',
    'reoptimize': 'إعادة التحسين',
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
    'addMethodTitle': 'كيف تريد إضافة هذه النقطة؟',
    'addMethodAddress': 'اكتب عنواناً',
    'addMethodAddressSub': 'ابحث واختر عنواناً واحداً',
    'addMethodMap': 'اختر على الخريطة',
    'addMethodMapSub': 'ضع دبوساً في المكان المطلوب',
    'addMethodPasteLink': 'الصق موقع من Google',
    'addMethodPasteLinkSub': 'الصق رابط خرائط نسخته',
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
    'placePointHint': 'حرّك الخريطة ثم أكّد',
    'whatsappOpenFailed': 'تعذّر فتح واتساب',
    'waInfoBody':
        'في واتساب، اضغط على الموقع المُشارَك واختر «فتح بواسطة لفّة» — يفتح التطبيق والنقطة جاهزة على مسارك. كرّر الخطوات لكل نقطة جديدة، لتضاف فوق السابقة.',
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
    'deleteAccountIrreversible':
        'لا يمكن التراجع عن هذا. ستحتاج إلى إنشاء حساب جديد لتسجيل الدخول مرة أخرى.',
    'deleteAccountAck': 'أفهم أن هذا الإجراء نهائي',
    'deleteAccountConfirm': 'حذف نهائي',
    'deleteAccountDone': 'تم حذف حسابك وبياناته.',
    'valTermsRequired':
        'الرجاء الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة.',
    'legalTitle': 'المستندات القانونية',
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
    'openWithMaps': 'Ouvrir dans Maps',
    'newRouteShort': 'Nouveau',
    'startFresh': 'Supprimer le trajet et recommencer',
    'replay': 'Rejouer',
    'arrivedHere': 'Arrive',
    'pointServed': 'Point servi',
    'autoServedNotice':
        'Point de service termine. Navigation vers le prochain arret.',
    'rerouting': 'Recalcul de l\'itineraire…',
    'reoptimize': 'Reoptimiser',
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
    'addMethodTitle': 'Comment ajouter ce point ?',
    'addMethodAddress': 'Saisir une adresse',
    'addMethodAddressSub': 'Rechercher et choisir une adresse',
    'addMethodMap': 'Choisir sur la carte',
    'addMethodMapSub': 'Placez un point où vous voulez',
    'addMethodPasteLink': 'Coller un lien Google Maps',
    'addMethodPasteLinkSub': 'Collez un lien Maps copié',
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
    'placePointHint': 'Déplacez la carte, puis confirmez',
    'whatsappOpenFailed': "Impossible d'ouvrir WhatsApp",
    'waInfoBody':
        "Dans WhatsApp, touchez la position partagee et choisissez « Ouvrir avec Laffah » — l'app s'ouvre avec l'arret deja sur votre itineraire. Repetez pour chaque arret ; il s'ajoute aux precedents.",
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
    'deleteAccountIrreversible':
        'Cette action est irréversible. Vous devrez créer un nouveau compte pour vous reconnecter.',
    'deleteAccountAck': 'Je comprends que cette action est définitive',
    'deleteAccountConfirm': 'Supprimer définitivement',
    'deleteAccountDone': 'Votre compte et ses données ont été supprimés.',
    'valTermsRequired':
        'Veuillez accepter les Conditions d\'utilisation et la Politique de confidentialité pour continuer.',
    'legalTitle': 'Documents légaux',
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
    'valCompanyTooLong': 'Le nom de l\'entreprise est trop long.',
    'valPhoneInvalid': 'Veuillez saisir un numéro de téléphone valide.',
    'valPhoneRequired': 'Veuillez saisir votre numéro de téléphone.',
    'valPhoneTooShort': 'Trop court pour {country}. Exemple : {example}',
    'valPhoneTooLong': 'Trop long pour {country}. Exemple : {example}',
    'valPhoneNotMobile':
        'Ce n\'est pas un numéro mobile {country}. Exemple : {example}',
  },
};
