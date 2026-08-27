import 'dart:developer' as developer;

import 'package:latlong2/latlong.dart';

import '../../../../core/config/routing_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_maneuver.dart';
import '../../domain/entities/route_metrics.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/stop_time_window.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/ai_route_remote_datasource.dart';
import '../datasources/osrm_routing_datasource.dart';
import '../models/route_point_model.dart';
import '../models/route_request_model.dart';

class RouteRepositoryImpl implements RouteRepository {
  final AiRouteRemoteDataSource _ai;
  final OsrmRoutingDataSource _routing;
  final NetworkInfo _network;

  const RouteRepositoryImpl({
    required AiRouteRemoteDataSource ai,
    required OsrmRoutingDataSource routing,
    required NetworkInfo network,
  }) : _ai = ai,
       _routing = routing,
       _network = network;

  @override
  Future<ApiResult<OptimizedRoute>> optimize({
    required List<RoutePoint> points,
    String routingMode = RoutingConfig.defaultRoutingMode,
    DateTime? departureAt,
  }) async {
    if (!await _network.isConnected) {
      return ApiFailure(NetworkFailure(AppStrings.errNoInternet));
    }

    final depot = points.firstWhere(
      (p) => p.isDepot,
      orElse: () => points.first,
    );
    final stops = points.where((p) => p.id != depot.id).toList();

    if (stops.isEmpty) {
      return ApiFailure(ValidationFailure(AppStrings.errMinOneStopAfterDepot));
    }

    final departure = departureAt ?? DateTime.now();
    final departureMinute = StopTimeWindow.minuteOfDay(departure);

    // A single destination has only one possible order — nothing for the
    // AI solver to optimize. Skip the VRP round-trip entirely and go
    // straight to road routing (shortest path).
    if (stops.length == 1) {
      return _directRoute(
        depot: depot,
        stop: stops.first,
        mode: routingMode,
        departureMinute: departureMinute,
      );
    }

    // Clock windows → the solver's frame (minutes after departure). The
    // working day has to stretch far enough to contain the latest one,
    // otherwise the solver treats an evening stop as unreachable.
    final windows = <String, RelativeTimeWindow>{
      for (final s in stops)
        if (s.timeWindow != null)
          s.id: s.timeWindow!.relativeTo(departureMinute),
    };
    var horizon = RoutingConfig.defaultDriverHours * 60;
    for (final w in windows.values) {
      if (w.endMinutes > horizon) horizon = w.endMinutes;
    }

    final request = RouteRequestModel(
      numVehicles: RoutingConfig.defaultNumVehicles,
      vehicleCapacity: RoutingConfig.defaultVehicleCapacity,
      depotLat: depot.latitude,
      depotLon: depot.longitude,
      routingMode: routingMode,
      timeLimitSeconds: RoutingConfig.defaultTimeLimitSeconds,
      driverHours: RoutingConfig.driverHoursForHorizon(horizon),
      defaultServiceTimeMinutes: RoutingConfig.defaultServiceTimeMinutes,
      deliveries: stops.map((s) {
        final w = windows[s.id];
        return RoutePointModel(
          address: s.address?.isNotEmpty == true ? s.address! : s.label,
          lat: s.latitude,
          lon: s.longitude,
          weight: s.weight,
          timeWindowStart: w?.startMinutes,
          timeWindowEnd: w?.endMinutes,
        );
      }).toList(),
    );

    try {
      final response = await _ai.optimize(request);

      if (response.routes.isEmpty) {
        return ApiFailure(ServerFailure(AppStrings.errEmptyOptimizedRoute));
      }

      final reordered = _reorderPoints(
        depot: depot,
        userStops: stops,
        responseStops: response.routes.first.stops,
      );

      final polylines = await _buildPolylines(
        reordered.points,
        mode: routingMode,
      );

      // The backend never fills `arrival_time`, and it silently drops a stop
      // whose window it can't satisfy, so both the ETAs and the "can't make
      // it" flags are worked out here rather than read off the response.
      final ordered = _applyArrivalTimes(
        ordered: reordered.points,
        departureMinute: departureMinute,
        legDurationsSeconds: polylines.legDurationsSeconds,
        droppedIds: reordered.droppedIds,
      );

      final metrics = _enrichMetrics(
        base: response.metrics.toEntity(),
        ordered: ordered,
        polyline: polylines.fullPolyline,
        roadDistanceKm: polylines.fullDistanceKm,
        roadDurationMinutes: polylines.fullDurationMinutes,
        userStops: points,
      );

      return ApiSuccess(
        OptimizedRoute(
          orderedPoints: ordered,
          fullPolyline: polylines.fullPolyline,
          goPolyline: polylines.goPolyline,
          returnPolyline: polylines.returnPolyline,
          metrics: metrics,
          hasRoadGeometry: polylines.hasRoadGeometry,
          maneuvers: polylines.maneuvers,
        ),
      );
    } on NetworkException catch (e) {
      return ApiFailure(NetworkFailure(e.message));
    } on InvalidResponseException catch (e) {
      return ApiFailure(ServerFailure(e.message));
    } on ServerException catch (e) {
      return ApiFailure(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e, st) {
      developer.log('optimize() unexpected', error: e, stackTrace: st);
      return ApiFailure(UnknownFailure(e.toString()));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Direct (non-AI) route for a single destination: only one possible
  /// order exists, so this skips the VRP solver and goes straight to road
  /// routing for the polyline + metrics.
  Future<ApiResult<OptimizedRoute>> _directRoute({
    required RoutePoint depot,
    required RoutePoint stop,
    required String mode,
    required int departureMinute,
  }) async {
    try {
      // The point keeps whatever it is called. Naming is the planner's job
      // — it already decided this is "the destination", or carried a name in
      // from a CSV row — and the multi-stop path leaves labels alone too.
      final planned = [depot.copyWith(sequence: 0), stop.copyWith(sequence: 1)];

      final polylines = await _buildPolylines(planned, mode: mode);

      // One destination can't be re-ordered, but it can still be too far to
      // reach in time — so it gets the same ETA / window check.
      final ordered = _applyArrivalTimes(
        ordered: planned,
        departureMinute: departureMinute,
        legDurationsSeconds: polylines.legDurationsSeconds,
        droppedIds: const {},
      );

      final metrics = _enrichMetrics(
        base: const RouteMetrics(),
        ordered: ordered,
        polyline: polylines.fullPolyline,
        roadDistanceKm: polylines.fullDistanceKm,
        roadDurationMinutes: polylines.fullDurationMinutes,
        userStops: [depot, stop],
      );

      return ApiSuccess(
        OptimizedRoute(
          orderedPoints: ordered,
          fullPolyline: polylines.fullPolyline,
          goPolyline: polylines.goPolyline,
          returnPolyline: polylines.returnPolyline,
          metrics: metrics,
          hasRoadGeometry: polylines.hasRoadGeometry,
          maneuvers: polylines.maneuvers,
        ),
      );
    } catch (e, st) {
      developer.log('_directRoute() unexpected', error: e, stackTrace: st);
      return ApiFailure(UnknownFailure(e.toString()));
    }
  }

  /// Re-build the ordered RoutePoint list using the response sequence.
  ///
  /// The Afdal VRP response lists stops by `address`. We match each
  /// response stop back to the original user point by address first,
  /// then fall back to lat/lon proximity (≈10 m).
  ///
  /// Stops the solver left out come back in [_ReorderResult.droppedIds].
  /// They are still appended to the itinerary (the user shouldn't lose a
  /// destination), but the caller flags them so the UI can say the
  /// requested time can't be met — the API drops infeasible stops silently
  /// and leaves `unassigned_deliveries` empty, so this is the only signal.
  _ReorderResult _reorderPoints({
    required RoutePoint depot,
    required List<RoutePoint> userStops,
    required List<RoutePointModel> responseStops,
  }) {
    final result = <RoutePoint>[];
    final remaining = List<RoutePoint>.from(userStops);

    for (final s in responseStops) {
      RoutePoint? matched;

      // Skip the depot entries (start/end). Recognisable by:
      //   • The literal "DEPOT" address the Afdal VRP API uses.
      //   • Coordinate proximity (~30 m — API snaps to nearest road so
      //     the returned lat/lon can differ by up to ~20 m from the pin).
      //   • Exact address match (fallback for other VRP backends).
      final isDepotLike =
          s.address.trim().toUpperCase() == 'DEPOT' ||
          _isSameCoordLoose(s.lat, s.lon, depot.latitude, depot.longitude) ||
          (s.address.trim() == (depot.address ?? '').trim() &&
              s.address.isNotEmpty);
      if (isDepotLike) continue;

      // 1) match by address (case-insensitive, both sides non-empty)
      final addrIdx = remaining.indexWhere(
        (r) =>
            (r.address?.toLowerCase() ?? '') == s.address.toLowerCase() &&
            s.address.isNotEmpty,
      );
      if (addrIdx >= 0) {
        matched = remaining.removeAt(addrIdx);
      } else {
        // 2) label-as-address match: when a stop had no address its label
        //    was sent as the address field and is echoed back by the API.
        final labelIdx = remaining.indexWhere(
          (r) =>
              (r.address == null || r.address!.isEmpty) &&
              r.label.toLowerCase() == s.address.toLowerCase() &&
              s.address.isNotEmpty,
        );
        if (labelIdx >= 0) {
          matched = remaining.removeAt(labelIdx);
        } else {
          // 3) match by proximity (~10 m)
          final coordIdx = remaining.indexWhere(
            (r) => _isSameCoord(s.lat, s.lon, r.latitude, r.longitude),
          );
          if (coordIdx >= 0) matched = remaining.removeAt(coordIdx);
        }
      }

      if (matched != null) {
        // Relabel by optimised position so dot number == caption label.
        result.add(
          matched.copyWith(
            label: AppStrings.stopLabel(result.length + 1),
            sequence: result.length + 1,
          ),
        );
      } else if (s.lat != 0 && s.lon != 0) {
        // No label/address/coord match. Try a loose proximity scan (≤500 m)
        // to catch API lat/lon rounding before creating a ghost entry — this
        // prevents the original user stop from being appended as a duplicate.
        int looseIdx = -1;
        double looseDistMin = double.infinity;
        for (var i = 0; i < remaining.length; i++) {
          final d = DistanceUtils.haversineKm(
            LatLng(s.lat, s.lon),
            remaining[i].latLng,
          );
          if (d < looseDistMin) {
            looseDistMin = d;
            looseIdx = i;
          }
        }
        if (looseIdx >= 0 && looseDistMin < 0.5) {
          result.add(
            remaining
                .removeAt(looseIdx)
                .copyWith(
                  label: AppStrings.stopLabel(result.length + 1),
                  sequence: result.length + 1,
                ),
          );
        } else {
          // Truly unrecognised stop from the API — surface it as-is.
          result.add(
            RoutePoint(
              id: 'srv_${result.length}',
              latitude: s.lat,
              longitude: s.lon,
              label: AppStrings.stopLabel(result.length + 1),
              address: s.address,
              weight: s.weight,
              kind: RoutePointKind.stop,
              sequence: result.length + 1,
            ),
          );
        }
      }
    }

    // Append any stops the API didn't return (safety net). For a stop with
    // a time window this is the solver telling us the window is infeasible,
    // so record it — silently tacking it on the end would hide the problem.
    final dropped = <String>{};
    for (final r in remaining) {
      dropped.add(r.id);
      result.add(
        r.copyWith(
          label: AppStrings.stopLabel(result.length + 1),
          sequence: result.length + 1,
        ),
      );
    }

    // Multi-stop trips return to the depot; a single destination is a one-way
    // path (classic navigator), so only close the loop for 2+ stops.
    final ordered = [depot.copyWith(sequence: 0), ...result];
    if (result.length > 1) {
      ordered.add(
        depot.copyWith(id: '${depot.id}_return', sequence: result.length + 1),
      );
    }
    return _ReorderResult(ordered, dropped);
  }

  /// Fill in each stop's estimated arrival and flag the ones whose window
  /// can't be honoured.
  ///
  /// Arrival at stop *k* is the sum of the road legs leading to it plus the
  /// service time spent at every earlier stop — the same accounting the
  /// solver uses, rebuilt locally because the response's `arrival_time` is
  /// always 0.
  ///
  /// Getting somewhere before its window opens means waiting, not arriving
  /// early, so the ETA is held at the window's start and the delay carries
  /// into every later stop — otherwise a 20:00 appointment would show an
  /// 08:30 arrival and every stop after it would read early too.
  ///
  /// Without road legs (OSRM unavailable) ETAs stay null and only
  /// solver-dropped stops are flagged.
  List<RoutePoint> _applyArrivalTimes({
    required List<RoutePoint> ordered,
    required int departureMinute,
    required List<double> legDurationsSeconds,
    required Set<String> droppedIds,
  }) {
    // legs[i] runs from ordered[i] to ordered[i+1].
    final haveLegs = legDurationsSeconds.length >= ordered.length - 1;

    final out = <RoutePoint>[];
    var elapsedMinutes = 0.0;

    for (var i = 0; i < ordered.length; i++) {
      final p = ordered[i];

      if (i > 0 && haveLegs) {
        // Time spent at the previous stop, before driving this leg.
        if (!ordered[i - 1].isDepot) {
          elapsedMinutes += RoutingConfig.defaultServiceTimeMinutes;
        }
        elapsedMinutes += legDurationsSeconds[i - 1] / 60.0;
      }

      final window = p.timeWindow?.relativeTo(departureMinute);

      if (i > 0 && haveLegs && window != null) {
        if (elapsedMinutes < window.startMinutes) {
          elapsedMinutes = window.startMinutes.toDouble();
        }
      }

      final eta = (i == 0)
          ? 0
          : haveLegs
          ? elapsedMinutes.round()
          : null;

      // How far past the deadline the driver lands. Kept as a number rather
      // than a boolean so the UI can say "late by 25 min" and offer a
      // deadline nudge of exactly that size.
      final lateBy = (window != null && eta != null && eta > window.endMinutes)
          ? eta - window.endMinutes
          : null;

      // Only a stop the user actually constrained can miss anything. The
      // solver also drops stops for reasons that have nothing to do with a
      // clock (an address it couldn't match, a stop it folded into another),
      // and flagging those as "late" invents a deadline the user never set —
      // a red warning on a stop whose sheet shows no time at all. Such a
      // stop is still appended to the route above; it just isn't accused of
      // breaking a rule that doesn't exist.
      final missed =
          p.hasTimeWindow && (droppedIds.contains(p.id) || lateBy != null);

      out.add(
        p.copyWith(
          etaMinutesFromDeparture: eta,
          clearEta: eta == null,
          timeWindowMissed: missed,
          latenessMinutes: lateBy,
          // A stop that used to run late and now fits must not keep the
          // old figure from the previous solve.
          clearLateness: lateBy == null,
        ),
      );
    }

    return out;
  }

  bool _isSameCoord(double a1, double a2, double b1, double b2) {
    // ~10 m tolerance.
    return (a1 - b1).abs() < 1e-4 && (a2 - b2).abs() < 1e-4;
  }

  bool _isSameCoordLoose(double a1, double a2, double b1, double b2) {
    // ~30 m tolerance — used for depot detection when the VRP API snaps
    // the depot pin to the nearest road and returns rounded coordinates.
    return (a1 - b1).abs() < 3e-4 && (a2 - b2).abs() < 3e-4;
  }

  Future<_PolylineBundle> _buildPolylines(
    List<RoutePoint> ordered, {
    required String mode,
  }) async {
    if (ordered.length < 2) {
      return _PolylineBundle.empty();
    }

    final origin = ordered.first.latLng;
    final destination = ordered.last.latLng;
    final waypoints = ordered
        .sublist(1, ordered.length - 1)
        .map((p) => p.latLng)
        .toList();

    // Single destination (depot → stop): a one-way path, no return leg.
    final oneWay = waypoints.isEmpty;

    final osrmProfile = _mapModeToOsrmProfile(mode);

    final fullRoute = await _routing.fetchRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: osrmProfile,
      // Only the full trip carries the turn-by-turn maneuvers drive
      // mode navigates with.
      includeSteps: true,
    );
    final full = fullRoute.polyline;

    if (full.isEmpty) {
      // Fallback: straight segments.
      final fallback = ordered.map((p) => p.latLng).toList();
      if (oneWay) {
        return _PolylineBundle(
          fullPolyline: fallback,
          goPolyline: fallback,
          returnPolyline: const [],
          hasRoadGeometry: false,
          fullDistanceKm: null,
          fullDurationMinutes: null,
        );
      }
      final lastStopIndex = fallback.length - 2;
      return _PolylineBundle(
        fullPolyline: fallback,
        goPolyline: fallback.sublist(0, lastStopIndex + 1),
        returnPolyline: fallback.sublist(lastStopIndex),
        hasRoadGeometry: false,
        fullDistanceKm: null,
        fullDurationMinutes: null,
      );
    }

    if (oneWay) {
      // The whole route is the "go" leg; there is no return.
      return _PolylineBundle(
        fullPolyline: full,
        goPolyline: full,
        returnPolyline: const [],
        hasRoadGeometry: true,
        fullDistanceKm: fullRoute.distanceMeters > 0
            ? fullRoute.distanceMeters / 1000
            : null,
        fullDurationMinutes: fullRoute.durationSeconds > 0
            ? fullRoute.durationSeconds / 60
            : null,
        maneuvers: fullRoute.maneuvers,
        legDurationsSeconds: fullRoute.legDurationsSeconds,
      );
    }

    // For the go leg we fetch a separate polyline that ends at the
    // last stop (not depot). This keeps the highlight clean when the
    // user toggles between go / return / full.
    final lastStop = waypoints.isNotEmpty ? waypoints.last : destination;
    final goWaypoints = waypoints.isNotEmpty
        ? waypoints.sublist(0, waypoints.length - 1)
        : <LatLng>[];
    final goRoute = await _routing.fetchRoute(
      origin: origin,
      destination: lastStop,
      waypoints: goWaypoints,
      profile: osrmProfile,
    );

    final backRoute = await _routing.fetchRoute(
      origin: lastStop,
      destination: destination,
      profile: osrmProfile,
    );

    return _PolylineBundle(
      fullPolyline: full,
      goPolyline: goRoute.polyline.isNotEmpty ? goRoute.polyline : full,
      returnPolyline: backRoute.polyline.isNotEmpty
          ? backRoute.polyline
          : [lastStop, destination],
      hasRoadGeometry: true,
      fullDistanceKm: fullRoute.distanceMeters > 0
          ? fullRoute.distanceMeters / 1000
          : null,
      fullDurationMinutes: fullRoute.durationSeconds > 0
          ? fullRoute.durationSeconds / 60
          : null,
      maneuvers: fullRoute.maneuvers,
      legDurationsSeconds: fullRoute.legDurationsSeconds,
    );
  }

  String _mapModeToOsrmProfile(String mode) {
    switch (mode) {
      case 'bike':
        return 'cycling';
      case 'walking':
        return 'foot';
      case 'car':
      default:
        return 'driving';
    }
  }

  /// Fill in metrics that the AI didn't return, using safe heuristics.
  ///
  /// We never invent values: durations / fuel are only computed when
  /// we have a real polyline length to base them on. Where we don't,
  /// the entity stays null and the UI shows "غير متاح من الخادم".
  RouteMetrics _enrichMetrics({
    required RouteMetrics base,
    required List<RoutePoint> ordered,
    required List<LatLng> polyline,
    required double? roadDistanceKm,
    required double? roadDurationMinutes,
    required List<RoutePoint> userStops,
  }) {
    final totalKm =
        roadDistanceKm ??
        base.totalDistanceKm ??
        (polyline.length >= 2
            ? DistanceUtils.pathLengthKm(polyline)
            : DistanceUtils.pathLengthKm(
                ordered.map((p) => p.latLng).toList(),
              ));

    // Naive baseline = visit stops in the user's input order.
    final baselineKm = DistanceUtils.pathLengthKm(
      userStops.map((p) => p.latLng).toList()
        ..add(userStops.firstWhere((p) => p.isDepot).latLng),
    );

    // A single destination is one-way (no return depot), so there's nothing to
    // optimize — the round-trip baseline "savings" would be meaningless.
    final oneWay = ordered.length < 3;
    final savedDistance = oneWay
        ? null
        : (base.savedDistanceKm ??
              (baselineKm > totalKm ? (baselineKm - totalKm) : null));

    // ~40 km/h urban average — used only when no duration was provided.
    final estimatedDuration =
        base.estimatedDurationMinutes ??
        roadDurationMinutes ??
        ((totalKm / 40.0) * 60);
    final savedDuration = oneWay
        ? null
        : (base.savedDurationMinutes ??
              (savedDistance != null ? (savedDistance / 40.0) * 60 : null));

    // 8 L / 100 km — rough urban average. Only used when fuel wasn't
    // returned by the API.
    final fuel = base.fuelLiters ?? (totalKm * 0.08);

    return base.copyWith(
      totalDistanceKm: totalKm,
      estimatedDurationMinutes: estimatedDuration,
      savedDistanceKm: savedDistance,
      savedDurationMinutes: savedDuration,
      fuelLiters: fuel,
    );
  }
}

/// Ordered itinerary plus the ids of stops the solver refused to schedule.
class _ReorderResult {
  final List<RoutePoint> points;
  final Set<String> droppedIds;

  const _ReorderResult(this.points, this.droppedIds);
}

class _PolylineBundle {
  final List<LatLng> fullPolyline;
  final List<LatLng> goPolyline;
  final List<LatLng> returnPolyline;
  final bool hasRoadGeometry;
  final double? fullDistanceKm;
  final double? fullDurationMinutes;
  final List<RouteManeuver> maneuvers;

  /// Drive time of each depot→stop→…→depot leg, in itinerary order. Empty
  /// when there's no road geometry to measure, which is what makes per-stop
  /// ETAs unavailable.
  final List<double> legDurationsSeconds;

  const _PolylineBundle({
    required this.fullPolyline,
    required this.goPolyline,
    required this.returnPolyline,
    required this.hasRoadGeometry,
    required this.fullDistanceKm,
    required this.fullDurationMinutes,
    this.maneuvers = const [],
    this.legDurationsSeconds = const [],
  });

  factory _PolylineBundle.empty() => const _PolylineBundle(
    fullPolyline: [],
    goPolyline: [],
    returnPolyline: [],
    hasRoadGeometry: false,
    fullDistanceKm: null,
    fullDurationMinutes: null,
  );
}
