import '../../core/constants/app_constants.dart';

class DispatchStrings {
  static String t(String en, String fr, String ar) =>
      switch (AppStrings.localeNotifier.value.languageCode) {
        'fr' => fr,
        'ar' => ar,
        _ => en,
      };
  static String get inbox =>
      t('Received trips', 'Tournées reçues', 'الجولات المستلمة');
  static String get driverId =>
      t('Driver code', 'Code du chauffeur', 'رمز السائق');
  static String get empty => t(
    'No trips received yet.',
    'Aucune tournée reçue.',
    'لا توجد جولات مستلمة بعد.',
  );
  static String get newTrip => t(
    'New round ready. Tap My routes to open it.',
    'Nouvelle tournée prête. Touchez Mes tournées pour l’ouvrir.',
    'جولة جديدة جاهزة. اضغط على جولاتي لفتحها.',
  );
  static String get signIn => t(
    'Sign in to receive trips from your dispatcher.',
    'Connectez-vous pour recevoir vos tournées.',
    'سجّل الدخول لاستلام جولاتك.',
  );
  static String get retry => t('Refresh', 'Actualiser', 'تحديث');
  static String get loadMore =>
      t('Earlier trips', 'Tournées précédentes', 'الجولات السابقة');
  static String get open => t('Open round', 'Ouvrir la tournée', 'فتح الجولة');
  static String get unread => t('New', 'Nouveau', 'جديد');
  static String get failed => t(
    'Could not load trips. Check your connection and try again.',
    'Impossible de charger les tournées. Vérifiez la connexion et réessayez.',
    'تعذّر تحميل الجولات. تحقّق من الاتصال وحاول مجدداً.',
  );
  static String get sessionChanged => t(
    'Sign in again to open this round.',
    'Reconnectez-vous pour ouvrir cette tournée.',
    'سجّل الدخول مجدداً لفتح الجولة.',
  );
  static String get preparing => t(
    'Preparing your round…',
    'Préparation de la tournée…',
    'جارٍ تجهيز الجولة…',
  );
  static String get roadFailed => t(
    'Could not prepare road directions. The round is still in your inbox; try again when connected.',
    'Impossible de préparer le trajet. La tournée reste dans votre boîte de réception ; réessayez avec une connexion.',
    'تعذّر تجهيز المسار. الجولة محفوظة في الوارد؛ حاول مجدداً عند الاتصال.',
  );
}
