/// Wire model for a delivery stop sent to the Afdal VRP API.
///
/// Matches the `Delivery` schema published by the backend:
/// ```json
/// {"address": "...", "lat": 24.7034, "lon": 46.6921, "weight": 15,
///  "time_window_start": 0, "time_window_end": 480}
/// ```
class RoutePointModel {
  final String address;
  final double lat;
  final double lon;
  final int weight;

  /// Earliest / latest arrival the solver may schedule, in **minutes after
  /// departure** (not clock time). Both null means "any time" — we then omit
  /// the keys so the backend applies its own `0 .. driver_hours * 60`
  /// defaults rather than us hard-coding them.
  final int? timeWindowStart;
  final int? timeWindowEnd;

  /// Sequence in the optimized itinerary (response-only).
  final int? sequence;

  /// What the backend says this stop is: `depot`, `delivery`, or `finish`
  /// (the driver's own end point). Response-only. Older backends omit it, so
  /// null means "assume a delivery" and fall back to the address checks.
  final String? kind;

  bool get isTerminal => kind == 'depot' || kind == 'finish';

  /// The solver's own arrival estimate, minutes after departure
  /// (response-only). The deployed backend always reports `0` here, so the
  /// repository computes ETAs from the road legs instead and only falls back
  /// to this field if a future version starts filling it in.
  final int? arrivalTimeMinutes;

  const RoutePointModel({
    required this.address,
    required this.lat,
    required this.lon,
    required this.weight,
    this.timeWindowStart,
    this.timeWindowEnd,
    this.sequence,
    this.kind,
    this.arrivalTimeMinutes,
  });

  bool get hasTimeWindow => timeWindowStart != null || timeWindowEnd != null;

  Map<String, dynamic> toJson() => {
    'address': address,
    'lat': lat,
    'lon': lon,
    'weight': weight,
    if (timeWindowStart != null) 'time_window_start': timeWindowStart,
    if (timeWindowEnd != null) 'time_window_end': timeWindowEnd,
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
      kind: json['kind']?.toString(),
      arrivalTimeMinutes: json['arrival_time'] is num
          ? (json['arrival_time'] as num).toInt()
          : null,
    );
  }
}
