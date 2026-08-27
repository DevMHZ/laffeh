import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// What kind of thing a search result is. Drives both the icon on the tile
/// and — more importantly — how fast the result's score decays with
/// distance. A shop 200 km away is the wrong shop; a *city* 200 km away is
/// still the city the driver named.
enum PlaceKind {
  /// A named business or facility: pharmacy, fuel station, restaurant.
  poi,

  /// A street address, house number included.
  address,

  /// A road or street, no number.
  street,

  /// A neighbourhood, quarter, or suburb.
  area,

  /// A city, town, or village.
  city,

  /// A governorate, state, or country.
  region,

  /// Raw coordinates, or a map link the driver pasted.
  coordinate,
}

/// Where a suggestion came from. Kept on the result so the ranker can break
/// ties, the UI can label a recent as a recent, and a provider that starts
/// misbehaving can be identified from a log line.
enum PlaceSource {
  photon,
  nominatim,
  overpass,
  category,
  recent,
  routePoint,
  coordinate,

  /// A label the driver tapped on the map itself — read straight out of
  /// the vector tiles already on screen, no request to anyone.
  mapLabel,
}

/// One ranked answer to "where do you want to go?".
///
/// Deliberately flatter than what any single provider returns: the point of
/// this type is that a Photon feature, a Nominatim row, an Overpass node, a
/// place the driver visited last Tuesday and a pasted pair of coordinates
/// all arrive at the list as the same shape, so the ranker can compare them
/// on merit instead of on which service happened to answer first.
class PlaceSuggestion extends Equatable {
  /// The line the driver reads first — "صيدلية الشفاء", "شارع الثورة".
  final String name;

  /// The line under it: neighbourhood, city, whatever narrows down *which*
  /// one this is. Null when the provider gave nothing worth showing.
  final String? context;

  final LatLng latLng;
  final PlaceKind kind;
  final PlaceSource source;

  /// Straight-line km from wherever the search was biased. Null when the
  /// search had no location to bias against (permission off, no fix yet).
  final double? distanceKm;

  /// 0..1, assigned by the local ranker. The list is sorted on this and
  /// nothing else — provider order is an opinion about a different question.
  final double score;

  /// How big a deal this place is, 0..1, when the provider said something
  /// about it. Aleppo and a village called حلبون are both `PlaceKind.city`
  /// to the type system; only this tells them apart, and without it the
  /// village wins on being seventeen kilometres away. Null when the
  /// provider offered nothing, in which case the kind's default stands.
  final double? prominence;

  /// Stable identity for de-duplication and for the recents store.
  /// Provider ids where there is one, coordinates where there is not.
  final String id;

  const PlaceSuggestion({
    required this.id,
    required this.name,
    required this.latLng,
    required this.kind,
    required this.source,
    this.context,
    this.distanceKm,
    this.score = 0,
    this.prominence,
  });

  /// The full label written onto the route point when this is picked —
  /// what the driver will see in the stop list and on the map.
  String get fullLabel {
    final ctx = context?.trim();
    if (ctx == null || ctx.isEmpty) return name;
    return '$name، $ctx';
  }

  PlaceSuggestion copyWith({
    double? score,
    double? distanceKm,
    String? context,
    PlaceSource? source,
  }) {
    return PlaceSuggestion(
      id: id,
      name: name,
      latLng: latLng,
      kind: kind,
      source: source ?? this.source,
      context: context ?? this.context,
      distanceKm: distanceKm ?? this.distanceKm,
      score: score ?? this.score,
      prominence: prominence,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (context != null) 'context': context,
    'lat': latLng.latitude,
    'lng': latLng.longitude,
    'kind': kind.name,
  };

  static PlaceSuggestion? tryFromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final name = json['name']?.toString();
    if (lat == null || lng == null || name == null || name.isEmpty) return null;
    return PlaceSuggestion(
      id: json['id']?.toString() ?? '$lat,$lng',
      name: name,
      context: json['context']?.toString(),
      latLng: LatLng(lat, lng),
      kind: PlaceKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => PlaceKind.poi,
      ),
      source: PlaceSource.recent,
    );
  }

  @override
  List<Object?> get props => [id, name, context, latLng, kind, source];
}

/// How much a named place matters, from the OSM `place=*` value both text
/// providers report — Photon as `osm_value`, Nominatim as `type`.
///
/// One shared table on purpose. Each provider also ships its own relevance
/// number, but they are on different scales and mixing them makes results
/// from two services incomparable — which is exactly what the ranker has
/// to do. A tag both of them copy from the same map data does not have
/// that problem.
double? prominenceForOsmPlace(String? placeValue) {
  return switch (placeValue) {
    'country' => 1.0,
    'state' => 0.90,
    'region' || 'province' => 0.85,
    'city' => 0.95,
    'municipality' => 0.82,
    'town' => 0.78,
    'borough' || 'suburb' => 0.62,
    'quarter' || 'neighbourhood' => 0.58,
    'village' => 0.55,
    'hamlet' => 0.42,
    'isolated_dwelling' || 'locality' => 0.35,
    _ => null,
  };
}
