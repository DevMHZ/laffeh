/// Wire model for a delivery stop sent to the Afdal VRP API.
///
/// Matches the schema from `api_test/25_orders.json`:
/// ```json
/// {"address": "...", "lat": 24.7034, "lon": 46.6921, "weight": 15}
/// ```
class RoutePointModel {
  final String address;
  final double lat;
  final double lon;
  final int weight;

  /// Sequence in the optimized itinerary (response-only).
  final int? sequence;

  const RoutePointModel({
    required this.address,
    required this.lat,
    required this.lon,
    required this.weight,
    this.sequence,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'lat': lat,
    'lon': lon,
    'weight': weight,
  };

  /// Defensive parser — the response payload is not fully spec'd
  /// in the Python sample. We accept multiple aliases that VRP
  /// services tend to use (`lon`/`lng`/`longitude`, etc.).
  factory RoutePointModel.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] ?? json['latitude'] ?? 0).toDouble();
    final lon =
        (json['lon'] ?? json['lng'] ?? json['long'] ?? json['longitude'] ?? 0)
            .toDouble();

    final weightRaw = json['weight'] ?? json['load'] ?? 0;
    final weight = weightRaw is num ? weightRaw.toInt() : 0;

    return RoutePointModel(
      address: (json['address'] ?? '').toString(),
      lat: lat,
      lon: lon,
      weight: weight,
      sequence: json['sequence'] is num
          ? (json['sequence'] as num).toInt()
          : null,
    );
  }
}
