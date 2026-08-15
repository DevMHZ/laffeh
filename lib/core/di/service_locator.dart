import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Hide Supabase's AuthUser so our domain entity (used by the disabled repo) wins.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

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
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/error/auth_error_mapper.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/location_tracking/data/datasources/location_ping_remote_datasource.dart';
import '../../features/location_tracking/data/repositories/location_ping_repository_impl.dart';
import '../../features/location_tracking/domain/repositories/location_ping_repository.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/entities/profile.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../config/supabase_config.dart';
import '../error/failures.dart';
import '../network/api_result.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../services/consent_store.dart';
import '../services/location_ping_service.dart';
import '../services/registration_gate.dart';

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
        sl<OsrmRoutingDataSource>(),
      ),
    );
  }
  if (!sl.isRegistered<SavedRoutesCubit>()) {
    sl.registerFactory<SavedRoutesCubit>(
      () => SavedRoutesCubit(sl<SavedRoutesRepository>()),
    );
  }

  // ── Supabase (auth + database) ─────────────────────────
  // Only wired when credentials are present; otherwise the location
  // tracking chain falls back to a no-op so the offline planner still runs.
  if (SupabaseConfig.isReady) {
    if (!sl.isRegistered<SupabaseClient>()) {
      sl.registerLazySingleton<SupabaseClient>(() => SupabaseConfig.client);
    }
    if (!sl.isRegistered<LocationPingRemoteDataSource>()) {
      sl.registerLazySingleton<LocationPingRemoteDataSource>(
        () => LocationPingRemoteDataSource(sl<SupabaseClient>()),
      );
    }
    if (!sl.isRegistered<LocationPingRepository>()) {
      sl.registerLazySingleton<LocationPingRepository>(
        () => LocationPingRepositoryImpl(sl<LocationPingRemoteDataSource>()),
      );
    }
    if (!sl.isRegistered<AuthRemoteDataSource>()) {
      sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSource(sl<SupabaseClient>()),
      );
    }
    if (!sl.isRegistered<AuthRepository>()) {
      sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
      );
    }
    if (!sl.isRegistered<ProfileRemoteDataSource>()) {
      sl.registerLazySingleton<ProfileRemoteDataSource>(
        () => ProfileRemoteDataSource(sl<SupabaseClient>()),
      );
    }
    if (!sl.isRegistered<ProfileRepository>()) {
      sl.registerLazySingleton<ProfileRepository>(
        () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
      );
    }
  } else {
    if (!sl.isRegistered<LocationPingRepository>()) {
      sl.registerLazySingleton<LocationPingRepository>(
        () => _DisabledLocationPingRepository(),
      );
    }
    if (!sl.isRegistered<AuthRepository>()) {
      sl.registerLazySingleton<AuthRepository>(() => _DisabledAuthRepository());
    }
    if (!sl.isRegistered<ProfileRepository>()) {
      sl.registerLazySingleton<ProfileRepository>(
        () => _DisabledProfileRepository(),
      );
    }
  }

  // AuthCubit is app-global (singleton): the whole app reacts to sign-in /
  // sign-out. Always available — backed by the disabled repo when Supabase
  // isn't configured.
  if (!sl.isRegistered<AuthCubit>()) {
    sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
  }

  if (!sl.isRegistered<LocationPingService>()) {
    sl.registerLazySingleton<LocationPingService>(
      () => LocationPingService(
        sl<SharedPreferences>(),
        sl<LocationPingRepository>(),
      ),
    );
  }

  // Local record of policy acceptance (the server copy lives in `profiles`).
  if (!sl.isRegistered<ConsentStore>()) {
    sl.registerLazySingleton<ConsentStore>(
      () => ConsentStore(sl<SharedPreferences>()),
    );
  }

  // Clock on the "use the app without an account" trial.
  if (!sl.isRegistered<RegistrationGate>()) {
    sl.registerLazySingleton<RegistrationGate>(
      () => RegistrationGate(sl<SharedPreferences>()),
    );
  }
}

/// Stand-in used when Supabase isn't configured. Never actually called
/// (`LocationPingService.ping` short-circuits on `SupabaseConfig.isReady`),
/// but keeps the dependency graph resolvable.
class _DisabledLocationPingRepository implements LocationPingRepository {
  @override
  Future<ApiResult<void>> recordPing({
    required String deviceId,
    String? userId,
    required double lat,
    required double lng,
    double? accuracy,
  }) async => const ApiSuccess<void>(null);
}

/// Stand-in auth repo used when Supabase isn't configured: no session, and any
/// sign-in / sign-up attempt fails with a "backend unavailable" message.
class _DisabledAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();

  @override
  Future<ApiResult<AuthUser>> signUp({
    required String phone,
    required String password,
  }) async => const ApiFailure<AuthUser>(
    AuthFailure(AuthErrorMapper.backendUnavailable),
  );

  @override
  Future<ApiResult<AuthUser>> signIn({
    required String phone,
    required String password,
  }) async => const ApiFailure<AuthUser>(
    AuthFailure(AuthErrorMapper.backendUnavailable),
  );

  @override
  Future<ApiResult<void>> signOut() async => const ApiSuccess<void>(null);

  @override
  Future<ApiResult<void>> deleteAccount() async =>
      const ApiFailure<void>(AuthFailure(AuthErrorMapper.backendUnavailable));
}

/// Stand-in profile repo used when Supabase isn't configured.
class _DisabledProfileRepository implements ProfileRepository {
  @override
  Future<ApiResult<Profile?>> fetchMyProfile() async =>
      const ApiSuccess<Profile?>(null);

  @override
  Future<bool> isOnboardingComplete() async => false;

  @override
  Future<ApiResult<void>> recordTermsAcceptance(String termsVersion) async =>
      const ApiFailure<void>(AuthFailure(AuthErrorMapper.backendUnavailable));

  @override
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
    String? termsVersion,
  }) async =>
      const ApiFailure<void>(AuthFailure(AuthErrorMapper.backendUnavailable));
}
