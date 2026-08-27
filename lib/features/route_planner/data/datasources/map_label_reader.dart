import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/place_suggestion.dart';
import 'place_category_lexicon.dart';

/// The style's label layers, sorted into the order a tap should consult
/// them. See [MapLabelReader.groupLayers] for why the order is the whole
/// point.
class MapLabelLayers {
  /// Shops, stations, hospitals — the things a driver actually drives *to*.
  final List<String> poi;

  /// Cities, towns, villages, neighbourhoods.
  final List<String> place;

  /// Everything else that carries a name: roads, rivers, parks.
  final List<String> other;

  const MapLabelLayers({
    required this.poi,
    required this.place,
    required this.other,
  });

  static const empty = MapLabelLayers(poi: [], place: [], other: []);

  bool get isEmpty => poi.isEmpty && place.isEmpty && other.isEmpty;
}

/// Reads the label the driver just tapped straight out of the vector tiles
/// already on screen.
///
/// This is the cheapest place lookup in the app by a wide margin: the name,
/// its category and its coordinate are all sitting in the tile the map has
/// already downloaded and drawn, so tapping "صيدلية الشام" on the map costs
/// no request to anybody and works with the radio off. The style is asked
/// what it just rendered under the driver's finger, and that is the answer.
///
/// Everything here is pure: layer names in, features in, a place out. The
/// map plumbing lives in the map widget, so this can be tested without one.
class MapLabelReader {
  MapLabelReader._();

  /// Sorts a style's layer ids into the three tiers a tap consults in turn.
  ///
  /// Matched on the layer *id* rather than a hard-coded list because the
  /// style is configurable (`MAP_STYLE_URL`) and every vendor names its
  /// layers differently: OpenFreeMap Liberty calls them `poi_r1` and
  /// `label_city`, Mapbox Streets calls them `poi-label` and
  /// `settlement-label`. Pattern-matching the ids survives a style swap;
  /// a hard-coded list turns one into a silently dead feature.
  ///
  /// Matching is on whole **words** of the id, split on its separators —
  /// not on raw substrings. Checked against the real Liberty style, a
  /// substring test puts `water_name_point_label` in the POI tier, because
  /// "point" contains "poi", and drags the `road_transit_rail` *geometry*
  /// layers in alongside them. Both are the kind of wrong that shows up as
  /// "tapping the pharmacy selected the river".
  ///
  /// Order matters twice over. A layer lands in the first tier it matches,
  /// and the tiers are consulted in order, so a tap that lands on both a
  /// pharmacy and the city it sits in resolves to the pharmacy — which is
  /// what the finger was pointing at.
  static MapLabelLayers groupLayers(List<String> layerIds) {
    final poi = <String>[];
    final place = <String>[];
    final other = <String>[];

    for (final id in layerIds) {
      final words = _words(id);
      if (!_isLabelLayer(words)) continue;

      if (words.any(_poiWords.contains)) {
        poi.add(id);
      } else if (words.any(_placeWords.contains)) {
        place.add(id);
      } else {
        other.add(id);
      }
    }

    return MapLabelLayers(poi: poi, place: place, other: other);
  }

  static List<String> _words(String layerId) {
    return layerId
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Does this layer draw *names*, as opposed to the roads and rivers the
  /// names sit on? Only label layers are worth querying: a tap is asking
  /// "what is this called", and a layer with nothing to call anything can
  /// only contribute noise — and, in the case of the rail geometry layers,
  /// outrank the answer.
  static bool _isLabelLayer(List<String> words) {
    return words.any(
      (w) =>
          w == 'label' ||
          w == 'labels' ||
          w == 'name' ||
          w == 'names' ||
          _poiWords.contains(w),
    );
  }

  static const _poiWords = {'poi', 'airport', 'aerodrome'};

  /// Words that mark a layer as drawing settlement names. `other` is in
  /// here for Liberty's `label_other`, which is where it files hamlets and
  /// suburbs; it is only ever consulted for ids that already read as label
  /// layers, so it cannot capture anything unrelated.
  static const _placeWords = {
    'place',
    'settlement',
    'city',
    'town',
    'village',
    'hamlet',
    'suburb',
    'neighbourhood',
    'neighborhood',
    'quarter',
    'state',
    'country',
    'capital',
    'admin',
    'other',
  };

  /// Turns one queried feature into a place, or null when it carries no
  /// name worth showing — an unnamed road casing is not somewhere to go.
  ///
  /// [fallback] is where the finger landed, used when the feature's own
  /// geometry is a line or a polygon: tapping a long street should offer
  /// the point on it that was actually touched, not the far end of it.
  static PlaceSuggestion? read(
    dynamic feature, {
    required LatLng fallback,
    required PlaceKind tierKind,
  }) {
    if (feature is! Map) return null;
    final props = feature['properties'];
    if (props is! Map) return null;

    final name = _nameOf(props);
    if (name == null) return null;

    final geometry = feature['geometry'];
    final point = _pointOf(geometry) ?? fallback;
    final kind = _kindOf(props, tierKind: tierKind, geometry: geometry);

    return PlaceSuggestion(
      id: 'map:${feature['id'] ?? '${point.latitude},${point.longitude}'}',
      name: name,
      context: _contextOf(props, kind: kind),
      latLng: point,
      kind: kind,
      source: PlaceSource.mapLabel,
      prominence: prominenceForOsmPlace(props['class']?.toString()),
    );
  }

  /// Reads the best of a queried batch: the first feature that has a name.
  /// The style draws them in its own priority order and the platform hands
  /// them back in it, so first is already "most likely what was tapped".
  static PlaceSuggestion? readBest(
    List<dynamic> features, {
    required LatLng fallback,
    required PlaceKind tierKind,
  }) {
    for (final feature in features) {
      final place = read(feature, fallback: fallback, tierKind: tierKind);
      if (place != null) return place;
    }
    return null;
  }

  /// The name in the driver's language where the tile carries one.
  ///
  /// Vector tiles ship several name fields and which are populated varies
  /// by region, so this walks from the most specific to the most certain:
  /// the app's language, then the local name (which across this app's
  /// region *is* the Arabic one), then the transliterations.
  static String? _nameOf(Map<dynamic, dynamic> props) {
    final lang = AppStrings.languageCode;
    for (final key in [
      'name:$lang',
      'name_$lang',
      'name',
      'name:latin',
      'name_int',
      'name:en',
      'name_en',
    ]) {
      final value = props[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// The second line: what kind of thing this is, in the same words the
  /// search uses for the same category.
  static String? _contextOf(
    Map<dynamic, dynamic> props, {
    required PlaceKind kind,
  }) {
    // `subclass` is the specific one (`pharmacy`), `class` the general one
    // (`shop`); the specific one names the place better when both exist.
    final category =
        PlaceCategoryLexicon.forTagValue(props['subclass']?.toString()) ??
        PlaceCategoryLexicon.forTagValue(props['class']?.toString());
    if (category != null) {
      return AppStrings.placeCategoryLabel(category.labelKey);
    }

    return switch (kind) {
      PlaceKind.city => AppStrings.mapLabelKindCity,
      PlaceKind.area => AppStrings.mapLabelKindArea,
      PlaceKind.region => AppStrings.mapLabelKindRegion,
      PlaceKind.street => AppStrings.mapLabelKindStreet,
      _ => null,
    };
  }

  static PlaceKind _kindOf(
    Map<dynamic, dynamic> props, {
    required PlaceKind tierKind,
    dynamic geometry,
  }) {
    // A named line is a road or a river however the style filed it.
    if (geometry is Map && geometry['type'] == 'LineString') {
      return PlaceKind.street;
    }

    if (tierKind != PlaceKind.city) return tierKind;

    // Within the place tier, `class` says how big a place it is.
    return switch (props['class']?.toString()) {
      'continent' ||
      'country' ||
      'state' ||
      'province' ||
      'region' => PlaceKind.region,
      'city' || 'town' || 'village' || 'hamlet' => PlaceKind.city,
      'suburb' ||
      'neighbourhood' ||
      'quarter' ||
      'borough' ||
      'isolated_dwelling' => PlaceKind.area,
      _ => PlaceKind.area,
    };
  }

  /// The feature's own coordinate, for point geometries only. Lines and
  /// polygons deliberately return null so the caller falls back to the tap
  /// — the middle of a city polygon is not where the driver pointed.
  static LatLng? _pointOf(dynamic geometry) {
    if (geometry is! Map) return null;
    if (geometry['type'] != 'Point') return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }
}
