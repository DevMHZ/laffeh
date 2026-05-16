/// Arabic copy used across the app.
///
/// Keeping all user-facing strings here makes future localization
/// trivial — swap this class for a generated translation table.
class AppStrings {
  AppStrings._();

  // App
  static const appName = 'لفّة';
  static const appTagline = 'مسارك الأذكى';

  // Map / Planner
  static const planRouteTitle = 'خطط مسارك';
  static const routePointsTitle = 'نقاط المسار';
  static const bestRouteTitle = 'المسار الأفضل';
  static const tapToAddPoint = 'اضغط على الخريطة لإضافة نقطة';
  static const noPointsYet =
      'لم تختر أي نقطة بعد. ابدأ بتحديد نقطة الانطلاق ثم أضف الوجهات.';
  static const departure = 'نقطة الانطلاق';
  static const returnPoint = 'نقطة العودة';
  static const stop = 'نقطة';
  static const yourLocation = 'موقعك الحالي';

  // CTAs
  static const optimizeRoute = 'ابدأ';
  static const startNewRoute = 'بدء مسار جديد';
  static const clearAll = 'مسح الكل';
  static const showGo = 'عرض الذهاب';
  static const showReturn = 'عرض العودة';
  static const showFull = 'المسار الكامل';
  static const rename = 'إعادة تسمية';
  static const remove = 'حذف';
  static const setAsDeparture = 'تعيين كنقطة انطلاق';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const retry = 'إعادة المحاولة';
  static const close = 'إغلاق';

  // Metrics
  static const estimatedTime = 'الوقت المتوقع';
  static const totalDistance = 'إجمالي المسافة';
  static const savings = 'التوفير';
  static const fuelEstimate = 'استهلاك الوقود التقريبي';
  static const savedDistance = 'مسافة موفّرة';
  static const savedTime = 'وقت موفّر';
  static const unavailable = 'غير متاح من الخادم';

  // Errors / status (used in cubit + views)
  static const errMinTwoPoints = 'يرجى اختيار نقطتين على الأقل';
  static const errLocationUnavailable = 'تعذر تحديد موقعك الحالي';
  static const errOptimize = 'حدث خطأ أثناء تحسين المسار';
  static const errNoInternet = 'تحقق من الاتصال بالإنترنت';
  static const errCannotDrawRoute = 'لا يمكن رسم المسار حالياً';
  static const errMissingApiKey =
      'مفتاح خرائط Google غير مهيّأ. الرجاء إضافة GOOGLE_MAPS_API_KEY في ملف .env';
  static const errLocationPermissionDenied =
      'تم رفض إذن الموقع. الرجاء السماح بالوصول من إعدادات الجهاز.';
  static const errLocationServiceDisabled =
      'خدمة الموقع غير مفعّلة. يرجى تفعيل GPS وإعادة المحاولة.';
  static const errInvalidResponse = 'استجابة غير صالحة من الخادم';
  static const errEmptyOptimizedRoute = 'لم يُرجِع النموذج أي مسار مُحسَّن';
  static const errTimeout = 'انتهت مهلة الاتصال بالخادم';

  // Empty states
  static const emptyPointsHint = 'ابدأ بإضافة نقاط على الخريطة';

  // Splash
  static const initializing = 'جاري التحضير...';
  static const poweredBy = 'مدعوم من';

  // Simulation
  static const simulationTitle = 'محاكاة المسار';
  static const startSimulation = 'تشغيل المحاكاة';
  static const playSimulation = 'تشغيل';
  static const pauseSimulation = 'إيقاف مؤقت';
  static const resumeSimulation = 'استئناف';
  static const resetSimulation = 'إعادة';
  static const exitSimulation = 'إنهاء المحاكاة';
  static const simSpeedHalfX = '×0.5';
  static const simSpeed1x = '×1';
  static const simSpeed2x = '×2';
  static const simSpeed4x = '×4';

  // Camera modes
  static const cameraMode = 'وضع الكاميرا';
  static const cameraOverview = 'بانورامي';
  static const cameraFollow = 'متابعة';
  static const cameraChase = 'سينمائي';
  static const headedTo = 'متجه إلى';
  static const departingFrom = 'الانطلاق من';
  static const arrived = 'وصلنا!';
  static const progress = 'التقدّم';
  static const remainingDistance = 'المسافة المتبقية';
  static const remainingTime = 'الوقت المتبقي';

  // Saved routes
  static const savedRoutes = 'مساراتي';
  static const savedRoutesEmpty = 'لا توجد مسارات محفوظة بعد';
  static const savedRoutesEmptyHint =
      'بعد ما تحسّن مسار، تقدر تحفظه هنا للرجوع له لاحقاً';
  static const saveRouteTitle = 'حفظ المسار';
  static const saveRouteHint = 'اختر اسماً مميزاً للمسار';
  static const defaultRouteName = 'مسار جديد';
  static const askKeepCurrentRoute =
      'حفظ المسار الحالي قبل البدء من جديد؟';
  static const saveAndContinue = 'حفظ';
  static const discardAndContinue = 'بدون حفظ';
  static const dontSave = 'بدون حفظ';
  static const saved = 'تم الحفظ';
  static const routeSavedMsg = 'تم حفظ المسار في «مساراتي»';
  static const deleteRouteTitle = 'حذف المسار';
  static const deleteRouteConfirm = 'هل تريد حذف هذا المسار نهائياً؟';
  static const renameRouteTitle = 'إعادة تسمية المسار';
  static const openRoute = 'فتح المسار';
  static const sortNewest = 'الأحدث';

  // Settings
  static const settings = 'الإعدادات';
  static const about = 'عن التطبيق';
  static const apiBaseUrl = 'عنوان واجهة الذكاء الاصطناعي';
  static const officialWebsite = 'الموقع الرسمي';
  static const visitWebsite = 'زيارة الموقع';
  static const afdalWebsiteUrl = 'https://www.afdal.tech/';
}

/// Unit suffix helpers.
class AppUnits {
  AppUnits._();
  static const km = 'كم';
  static const min = 'دقيقة';
  static const liter = 'لتر';
}
