import 'dart:developer' as developer;

import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_metrics.dart';
import '../../domain/entities/route_point.dart';
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
    String routingMode = AppConfig.defaultRoutingMode,
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

    final request = RouteRequestModel(
      numVehicles: AppConfig.defaultNumVehicles,
      vehicleCapacity: AppConfig.defaultVehicleCapacity,
      depotLat: depot.latitude,
      depotLon: depot.longitude,
      routingMode: routingMode,
      timeLimitSeconds: AppConfig.defaultTimeLimitSeconds,
      maxVehicleTimeMinutes: AppConfig.defaultMaxVehicleTimeMinutes,
      deliveries: stops
          .map(
            (s) => RoutePointModel(
              address: s.address?.isNotEmpty == true ? s.address! : s.label,
              lat: s.latitude,
              lon: s.longitude,
              weight: s.weight,
            ),
          )
          .toList(),
    );

    try {
      final response = await _ai.optimize(request);

      if (response.routes.isEmpty) {
        return ApiFailure(ServerFailure(AppStrings.errEmptyOptimizedRoute));
      }

      final ordered = _reorderPoints(
        depot: depot,
        userStops: stops,
        responseStops: response.routes.first.stops,
      );

      final polylines = await _buildPolylines(ordered, mode: routingMode);

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

  /// Re-build the ordered RoutePoint list using the response sequence.
  ///
  /// The Afdal VRP response lists stops by `address`. We match each
  /// response stop back to the original user point by address first,
  /// then fall back to lat/lon proximity (≈10 m).
  List<RoutePoint> _reorderPoints({
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
        result.add(matched.copyWith(
          label: AppStrings.stopLabel(result.length + 1),
          sequence: result.length + 1,
        ));
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
          result.add(remaining.removeAt(looseIdx).copyWith(
            label: AppStrings.stopLabel(result.length + 1),
            sequence: result.length + 1,
          ));
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

    // Append any stops the API didn't return (safety net).
    for (final r in remaining) {
      result.add(r.copyWith(
        label: AppStrings.stopLabel(result.length + 1),
        sequence: result.length + 1,
      ));
    }

    return [
      depot.copyWith(sequence: 0),
      ...result,
      depot.copyWith(id: '${depot.id}_return', sequence: result.length + 1),
    ];
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

    final osrmProfile = _mapModeToOsrmProfile(mode);

    final fullRoute = await _routing.fetchRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: osrmProfile,
    );
    final full = fullRoute.polyline;

    if (full.isEmpty) {
      // Fallback: straight segments.
      final fallback = ordered.map((p) => p.latLng).toList();
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

    final savedDistance =
        base.savedDistanceKm ??
        (baselineKm > totalKm ? (baselineKm - totalKm) : null);

    // ~40 km/h urban average — used only when no duration was provided.
    final estimatedDuration =
        base.estimatedDurationMinutes ??
        roadDurationMinutes ??
        ((totalKm / 40.0) * 60);
    final savedDuration =
        base.savedDurationMinutes ??
        (savedDistance != null ? (savedDistance / 40.0) * 60 : null);

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

class _PolylineBundle {
  final List<LatLng> fullPolyline;
  final List<LatLng> goPolyline;
  final List<LatLng> returnPolyline;
  final bool hasRoadGeometry;
  final double? fullDistanceKm;
  final double? fullDurationMinutes;

  const _PolylineBundle({
    required this.fullPolyline,
    required this.goPolyline,
    required this.returnPolyline,
    required this.hasRoadGeometry,
    required this.fullDistanceKm,
    required this.fullDurationMinutes,
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
