import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/route_planner/data/datasources/ai_route_remote_datasource.dart';
import '../../features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import '../../features/route_planner/data/datasources/osrm_routing_datasource.dart';
import '../../features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import '../../features/route_planner/data/repositories/route_repository_impl.dart';
import '../../features/route_planner/domain/repositories/route_repository.dart';
import '../../features/route_planner/domain/usecases/get_directions_usecase.dart';
import '../../features/route_planner/domain/usecases/optimize_route_usecase.dart';
import '../../features/route_planner/presentation/cubit/route_planner_cubit.dart';
import '../../features/saved_routes/data/datasources/saved_routes_local_datasource.dart';
import '../../features/saved_routes/data/repositories/saved_routes_repository_impl.dart';
import '../../features/saved_routes/domain/repositories/saved_routes_repository.dart';
import '../../features/saved_routes/presentation/cubit/saved_routes_cubit.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';

/// Public service locator entry-point.
final GetIt sl = GetIt.instance;

/// Register every dependency. Call once from `main()` before
/// `runApp`. Idempotent — safe to call again in tests after
/// `sl.reset()`.
Future<void> setupServiceLocator() async {
  // ── Core ───────────────────────────────────────────────
  if (!sl.isRegistered<NetworkInfo>()) {
    sl.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  }

  // SharedPreferences must be awaited at startup so all dependents
  // can grab it synchronously.
  if (!sl.isRegistered<SharedPreferences>()) {
    final prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(prefs);
  }

  // ── Data sources ───────────────────────────────────────
  if (!sl.isRegistered<AiRouteRemoteDataSource>()) {
    sl.registerLazySingleton<AiRouteRemoteDataSource>(
      () => AiRouteRemoteDataSource(DioClient.aiRouteDio),
    );
  }
  if (!sl.isRegistered<OsrmRoutingDataSource>()) {
    sl.registerLazySingleton<OsrmRoutingDataSource>(
      () => OsrmRoutingDataSource(DioClient.osrmDio),
    );
  }
  if (!sl.isRegistered<OsmGeocodingDataSource>()) {
    sl.registerLazySingleton<OsmGeocodingDataSource>(
      () => OsmGeocodingDataSource(DioClient.nominatimDio),
    );
  }
  if (!sl.isRegistered<PlannerDraftLocalDataSource>()) {
    sl.registerLazySingleton<PlannerDraftLocalDataSource>(
      () => PlannerDraftLocalDataSource(sl<SharedPreferences>()),
    );
  }

  // ── Repositories ───────────────────────────────────────
  if (!sl.isRegistered<RouteRepository>()) {
    sl.registerLazySingleton<RouteRepository>(
      () => RouteRepositoryImpl(
        ai: sl<AiRouteRemoteDataSource>(),
        routing: sl<OsrmRoutingDataSource>(),
        network: sl<NetworkInfo>(),
      ),
    );
  }

  // ── Use cases ──────────────────────────────────────────
  if (!sl.isRegistered<OptimizeRouteUseCase>()) {
    sl.registerLazySingleton<OptimizeRouteUseCase>(
      () => OptimizeRouteUseCase(sl<RouteRepository>()),
    );
  }
  if (!sl.isRegistered<GetDirectionsUseCase>()) {
    sl.registerLazySingleton<GetDirectionsUseCase>(
      () => GetDirectionsUseCase(sl<OsrmRoutingDataSource>()),
    );
  }

  // ── Saved routes (local history) ───────────────────────
  if (!sl.isRegistered<SavedRoutesLocalDataSource>()) {
    sl.registerLazySingleton<SavedRoutesLocalDataSource>(
      () => SavedRoutesLocalDataSource(sl<SharedPreferences>()),
    );
  }
  if (!sl.isRegistered<SavedRoutesRepository>()) {
    sl.registerLazySingleton<SavedRoutesRepository>(
      () => SavedRoutesRepositoryImpl(sl<SavedRoutesLocalDataSource>()),
    );
  }

  // ── Cubits ─────────────────────────────────────────────
  // Factories so each navigation gets a fresh instance.
  if (!sl.isRegistered<RoutePlannerCubit>()) {
    sl.registerFactory<RoutePlannerCubit>(
      () => RoutePlannerCubit(
        sl<OptimizeRouteUseCase>(),
        sl<SavedRoutesRepository>(),
        sl<OsmGeocodingDataSource>(),
        sl<PlannerDraftLocalDataSource>(),
        sl<NetworkInfo>(),
      ),
    );
  }
  if (!sl.isRegistered<SavedRoutesCubit>()) {
    sl.registerFactory<SavedRoutesCubit>(
      () => SavedRoutesCubit(sl<SavedRoutesRepository>()),
    );
  }
}
