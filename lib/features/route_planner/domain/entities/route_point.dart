import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'stop_time_window.dart';

/// Role of a point in the planned route.
///
/// The depot is the start/end anchor for VRP. All other points
/// are delivery / waypoint stops. Returning is conceptually the
/// same as visiting the depot at the end.
enum RoutePointKind { depot, stop }

/// Domain entity for a user-selected point on the map.
///
/// Pure Dart, no Flutter / serialization concerns — those live
/// in the data layer.
class RoutePoint extends Equatable {
  /// Stable id (we use a millisecond timestamp + index suffix).
  final String id;

  final double latitude;
  final double longitude;

  /// Optional Arabic label (`نقطة الانطلاق`, `نقطة 1`...).
  final String label;

  /// Optional human address. Set after reverse-geocoding.
  final String? address;

  /// Contact number for whoever is waiting at this stop.
  ///
  /// Stored exactly as the driver typed it (or as the CSV carried it), not
  /// normalised to E.164 — a local `0944 123 456` has to read back the way
  /// it was entered. `PhoneUtils` canonicalises only at dial / WhatsApp time.
  final String? phone;

  /// Default payload weight for VRP, defaulted from `RoutingConfig`.
  final int weight;

  final RoutePointKind kind;

  /// Server-assigned index after optimization (null beforehand).
  final int? sequence;

  /// Whether the user flagged this as an *optional* stop — one that the
  /// optimizer may include or skip. Optional points can be toggled
  /// [active]/inactive without being deleted. Depots are never optional.
  final bool optional;

  /// Whether this point currently participates in routing / optimization.
  /// Always true for mandatory stops and the depot. An optional point that
  /// the user deactivated has `active == false`, so it stays in the list
  /// (and on the map, dimmed) but is excluded from the optimize request.
  final bool active;

  /// Clock window the driver must arrive in, or null when the stop can be
  /// visited whenever the optimizer likes. Sent to the VRP solver as
  /// `time_window_start` / `time_window_end` (converted to minutes after
  /// departure first — see [StopTimeWindow.relativeTo]).
  final StopTimeWindow? timeWindow;

  /// Estimated arrival, in minutes after departure. Computed from the road
  /// legs after optimization — the backend's own `arrival_time` is always
  /// 0, so we never rely on it. Null before optimizing.
  final int? etaMinutesFromDeparture;

  /// True when this stop's [timeWindow] can't actually be honoured: either
  /// the solver dropped it as infeasible, or the road-time estimate puts
  /// arrival past the window. The stop stays in the route regardless — the
  /// UI just flags it so the user can adjust the time or the trip.
  ///
  /// Meaningless without a [timeWindow], and never set without one: a stop
  /// the user gave no arrival time to has no deadline to miss, so it must
  /// never be flagged (see `_applyArrivalTimes`).
  final bool timeWindowMissed;

  /// How many minutes past the window's end the driver would arrive.
  ///
  /// This is the number that makes a missed window actionable — "late by 25
  /// minutes" tells the user whether to nudge the deadline or drop the stop,
  /// where a red highlight alone doesn't. Null when the stop is on time, or
  /// when there's no ETA to measure against (the solver dropped it without
  /// us being able to compute road time).
  final int? latenessMinutes;

  const RoutePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.weight,
    required this.kind,
    this.address,
    this.phone,
    this.sequence,
    this.optional = false,
    this.active = true,
    this.timeWindow,
    this.etaMinutesFromDeparture,
    this.timeWindowMissed = false,
    this.latenessMinutes,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isDepot => kind == RoutePointKind.depot;

  /// True when this point should be sent to the optimizer: every mandatory
  /// point, plus optional points the user left active.
  bool get isRoutable => !optional || active;

  /// True for an optional point the user has switched off.
  bool get isDeactivated => optional && !active;

  /// True when the user pinned a clock time to this stop.
  bool get hasTimeWindow => timeWindow != null;

  /// True when there is a number to call or message.
  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  RoutePoint copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? label,
    String? address,
    String? phone,
    int? weight,
    RoutePointKind? kind,
    int? sequence,
    bool? optional,
    bool? active,
    StopTimeWindow? timeWindow,
    int? etaMinutesFromDeparture,
    bool? timeWindowMissed,
    int? latenessMinutes,
    bool clearSequence = false,
    bool clearAddress = false,
    bool clearPhone = false,
    bool clearTimeWindow = false,
    bool clearEta = false,
    bool clearLateness = false,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      address: clearAddress ? null : (address ?? this.address),
      phone: clearPhone ? null : (phone ?? this.phone),
      weight: weight ?? this.weight,
      kind: kind ?? this.kind,
      sequence: clearSequence ? null : (sequence ?? this.sequence),
      optional: optional ?? this.optional,
      active: active ?? this.active,
      timeWindow: clearTimeWindow ? null : (timeWindow ?? this.timeWindow),
      etaMinutesFromDeparture: clearEta
          ? null
          : (etaMinutesFromDeparture ?? this.etaMinutesFromDeparture),
      // Clearing the window clears the "can't make it" verdict with it.
      timeWindowMissed: clearTimeWindow
          ? false
          : (timeWindowMissed ?? this.timeWindowMissed),
      latenessMinutes: (clearTimeWindow || clearEta || clearLateness)
          ? null
          : (latenessMinutes ?? this.latenessMinutes),
    );
  }

  @override
  List<Object?> get props => [
    id,
    latitude,
    longitude,
    label,
    address,
    phone,
    weight,
    kind,
    sequence,
    optional,
    active,
    timeWindow,
    etaMinutesFromDeparture,
    timeWindowMissed,
    latenessMinutes,
  ];
}
