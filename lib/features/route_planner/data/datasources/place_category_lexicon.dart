import '../../../../core/utils/search_text_utils.dart';

/// One searchable category of place, and the OSM tags that hold it.
class PlaceCategory {
  /// What to call the category on a result that has no name of its own —
  /// an unnamed fuel station shows as "محطة وقود", not as a blank tile.
  final String labelKey;

  /// OSM `key=value` pairs, any of which qualifies. Several because one
  /// idea is rarely one tag: "supermarket" is `shop=supermarket` and
  /// `shop=convenience` and, in practice, `shop=grocery`.
  final List<String> tags;

  const PlaceCategory({required this.labelKey, required this.tags});
}

/// Maps what a driver *types* onto what OpenStreetMap *stores*.
///
/// This layer exists because of a gap no text search can close. Ask for
/// "بنزين" around Damascus and the text index returns a station in Yanbu,
/// because not one of the twelve fuel stations within six kilometres has
/// the word "بنزين" in its name — they are all called "كازية". The word
/// the driver knows and the word the mapper typed are different words for
/// the same thing, and only a category lookup bridges them.
///
/// Colloquial spellings are matched on purpose. The app *speaks* plain
/// MSA, but it must *listen* to whatever the driver actually types, and
/// nobody types "محطة وقود" when they mean كازية.
class PlaceCategoryLexicon {
  PlaceCategoryLexicon._();

  static const _fuel = PlaceCategory(
    labelKey: 'catFuel',
    tags: ['amenity=fuel'],
  );
  static const _pharmacy = PlaceCategory(
    labelKey: 'catPharmacy',
    tags: ['amenity=pharmacy', 'healthcare=pharmacy'],
  );
  static const _hospital = PlaceCategory(
    labelKey: 'catHospital',
    tags: ['amenity=hospital', 'amenity=clinic', 'amenity=doctors'],
  );
  static const _bank = PlaceCategory(
    labelKey: 'catBank',
    tags: ['amenity=bank', 'amenity=bureau_de_change'],
  );
  static const _atm = PlaceCategory(labelKey: 'catAtm', tags: ['amenity=atm']);
  static const _restaurant = PlaceCategory(
    labelKey: 'catRestaurant',
    tags: ['amenity=restaurant', 'amenity=fast_food'],
  );
  static const _cafe = PlaceCategory(
    labelKey: 'catCafe',
    tags: ['amenity=cafe'],
  );
  static const _supermarket = PlaceCategory(
    labelKey: 'catSupermarket',
    tags: ['shop=supermarket', 'shop=convenience', 'shop=grocery'],
  );
  static const _bakery = PlaceCategory(
    labelKey: 'catBakery',
    tags: ['shop=bakery', 'shop=pastry'],
  );
  static const _mosque = PlaceCategory(
    labelKey: 'catMosque',
    tags: ['amenity=place_of_worship'],
  );
  static const _school = PlaceCategory(
    labelKey: 'catSchool',
    tags: ['amenity=school', 'amenity=kindergarten'],
  );
  static const _university = PlaceCategory(
    labelKey: 'catUniversity',
    tags: ['amenity=university', 'amenity=college'],
  );
  static const _hotel = PlaceCategory(
    labelKey: 'catHotel',
    tags: ['tourism=hotel', 'tourism=guest_house', 'tourism=motel'],
  );
  static const _parking = PlaceCategory(
    labelKey: 'catParking',
    tags: ['amenity=parking'],
  );
  static const _police = PlaceCategory(
    labelKey: 'catPolice',
    tags: ['amenity=police'],
  );
  static const _post = PlaceCategory(
    labelKey: 'catPost',
    tags: ['amenity=post_office'],
  );
  static const _carRepair = PlaceCategory(
    labelKey: 'catCarRepair',
    tags: ['shop=car_repair', 'shop=tyres', 'shop=car_parts'],
  );
  static const _busStation = PlaceCategory(
    labelKey: 'catBusStation',
    tags: ['amenity=bus_station', 'highway=bus_stop'],
  );
  static const _park = PlaceCategory(
    labelKey: 'catPark',
    tags: ['leisure=park', 'leisure=garden', 'leisure=playground'],
  );
  static const _market = PlaceCategory(
    labelKey: 'catMarket',
    tags: ['amenity=marketplace', 'shop=mall', 'shop=department_store'],
  );

  /// Folded trigger word → category. Keys must already be [SearchTextUtils]
  /// -folded, since that is what they are looked up with.
  static final Map<String, PlaceCategory> _triggers = _build({
    _fuel: [
      'بنزين',
      'بانزين',
      'كازية',
      'كازيه',
      'قازية',
      'محطة وقود',
      'محطه وقود',
      'وقود',
      'محروقات',
      'مازوت',
      'ديزل',
      'فيول',
      'بترول',
      'fuel',
      'gas',
      'gas station',
      'petrol',
      'diesel',
      'benzin',
    ],
    _pharmacy: [
      'صيدلية',
      'صيدليه',
      'صيدلة',
      'اجزخانة',
      'اجزخانه',
      'فرمشية',
      'دواء',
      'pharmacy',
      'chemist',
      'drugstore',
    ],
    _hospital: [
      'مشفى',
      'مستشفى',
      'مستوصف',
      'عيادة',
      'عياده',
      'طبيب',
      'دكتور',
      'اسعاف',
      'hospital',
      'clinic',
      'doctor',
      'emergency',
    ],
    _bank: ['بنك', 'مصرف', 'صرافة', 'صرافه', 'bank', 'exchange'],
    _atm: ['صراف', 'صراف الي', 'atm', 'cash machine'],
    _restaurant: [
      'مطعم',
      'مطاعم',
      'اكل',
      'شاورما',
      'فلافل',
      'بروستد',
      'وجبات',
      'restaurant',
      'food',
      'fast food',
    ],
    _cafe: ['كافيه', 'مقهى', 'قهوة', 'كوفي', 'cafe', 'coffee', 'coffee shop'],
    _supermarket: [
      'سوبرماركت',
      'سوبر ماركت',
      'ماركت',
      'بقالة',
      'بقاله',
      'دكان',
      'مينى ماركت',
      'supermarket',
      'market',
      'grocery',
      'minimarket',
    ],
    _bakery: ['فرن', 'مخبز', 'افران', 'خبز', 'حلويات', 'bakery', 'bread'],
    _mosque: ['جامع', 'مسجد', 'كنيسة', 'كنيسه', 'مصلى', 'mosque', 'church'],
    _school: [
      'مدرسة',
      'مدرسه',
      'مدارس',
      'روضة',
      'حضانة',
      'school',
      'kindergarten',
    ],
    _university: [
      'جامعة',
      'جامعه',
      'كلية',
      'كليه',
      'معهد',
      'university',
      'college',
    ],
    _hotel: ['فندق', 'فنادق', 'نزل', 'شاليه', 'hotel', 'motel', 'hostel'],
    _parking: ['موقف', 'مواقف', 'كراج', 'كاراج', 'parking', 'garage'],
    _police: ['شرطة', 'شرطه', 'مخفر', 'امن', 'police'],
    _post: ['بريد', 'مكتب بريد', 'post', 'post office'],
    _carRepair: [
      'ميكانيكي',
      'كهربجي سيارات',
      'تصليح سيارات',
      'كوتشي',
      'دواليب',
      'بنشر',
      'قطع غيار',
      'car repair',
      'mechanic',
      'tyres',
      'tires',
    ],
    _busStation: [
      'كراج باصات',
      'محطة باصات',
      'موقف باصات',
      'bus station',
      'bus stop',
    ],
    _market: ['سوق', 'اسواق', 'مول', 'مجمع تجاري', 'mall', 'bazaar', 'souq'],
    _park: [
      'حديقة',
      'حديقه',
      'حدائق',
      'منتزه',
      'ملعب اطفال',
      'park',
      'garden',
      'playground',
    ],
  });

  /// OSM tag *value* → category, e.g. `fuel` → the fuel category.
  ///
  /// The reverse of [_triggers]: that maps what a driver types onto a tag,
  /// this maps a tag the map is already rendering back onto a category, so
  /// a POI tapped on the map can be named ("محطة وقود") in the same words
  /// the search uses. Built from the same tag lists, so the two directions
  /// cannot drift apart.
  static final Map<String, PlaceCategory> _byTagValue = () {
    final map = <String, PlaceCategory>{};
    for (final category in _triggers.values.toSet()) {
      for (final tag in category.tags) {
        final value = tag.split('=').last;
        map.putIfAbsent(value, () => category);
      }
    }
    return map;
  }();

  /// The category for an OSM `class`/`subclass` value carried by a rendered
  /// map feature, or null when it is something with no category of its own.
  static PlaceCategory? forTagValue(String? value) {
    if (value == null || value.isEmpty) return null;
    return _byTagValue[value];
  }

  static Map<String, PlaceCategory> _build(
    Map<PlaceCategory, List<String>> spec,
  ) {
    final map = <String, PlaceCategory>{};
    spec.forEach((category, words) {
      for (final word in words) {
        final folded = SearchTextUtils.foldLoose(word);
        if (folded.isNotEmpty) map.putIfAbsent(folded, () => category);
      }
    });
    return map;
  }

  /// The category a query is asking for, or null when it is asking for a
  /// specific place by name.
  ///
  /// Matches the whole query first, then its individual words — "صيدلية
  /// قريبة" and "اقرب صيدلية" are both a pharmacy search, and the extra
  /// word only says out loud what the proximity ranking already does.
  static PlaceCategory? match(String query) {
    final whole = SearchTextUtils.foldLoose(query);
    if (whole.isEmpty) return null;

    final direct = _triggers[whole];
    if (direct != null) return direct;

    // A two-word trigger ("محطة وقود", "gas station") inside a longer query.
    for (final entry in _triggers.entries) {
      if (entry.key.contains(' ') && whole.contains(entry.key)) {
        return entry.value;
      }
    }

    for (final word in whole.split(' ')) {
      final hit = _triggers[word];
      if (hit != null) return hit;
    }
    return null;
  }
}
