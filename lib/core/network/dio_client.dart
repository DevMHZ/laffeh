import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env_config.dart';
import '../config/geocoding_config.dart';
import '../config/network_config.dart';

/// Two named Dio instances:
///
///   * [aiRouteDio]   → talks to the Afdal VRP optimizer
///                       (carries the `X-API-Key` header by default).
///   * [osrmDio]      → talks to the public OSRM router
///                       (OpenStreetMap-based; no key).
///   * [nominatimDio] → structured addresses + reverse geocoding through
///                       OSM's Nominatim-compatible API.
///   * [photonDio]    → the autocomplete geocoder (typo-tolerant, biased
///                       to where the driver is).
///   * [overpassDio]  → queries OSM by tag, for "every pharmacy near me".
class DioClient {
  DioClient._();

  static Dio? _aiRouteDio;
  static Dio? _osrmDio;
  static Dio? _nominatimDio;
  static Dio? _photonDio;
  static Dio? _overpassDio;

  static Dio get aiRouteDio {
    _aiRouteDio ??= _buildAiRouteDio();
    return _aiRouteDio!;
  }

  static Dio get osrmDio {
    _osrmDio ??= _buildOsrmDio();
    return _osrmDio!;
  }

  static Dio get nominatimDio {
    _nominatimDio ??= _buildNominatimDio();
    return _nominatimDio!;
  }

  static Dio get photonDio {
    _photonDio ??= _buildPhotonDio();
    return _photonDio!;
  }

  static Dio get overpassDio {
    _overpassDio ??= _buildOverpassDio();
    return _overpassDio!;
  }

  static Dio _buildAiRouteDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.aiRouteBaseUrl,
        connectTimeout: NetworkConfig.timeout,
        receiveTimeout: NetworkConfig.timeout,
        sendTimeout: NetworkConfig.timeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': EnvConfig.aiRouteApiKey,
        },
        responseType: ResponseType.json,
      ),
    );

    _attachAdapter(dio);
    if (kDebugMode) dio.interceptors.add(_logger());
    return dio;
  }

  static Dio _buildOsrmDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://router.project-osrm.org',
        connectTimeout: NetworkConfig.timeout,
        receiveTimeout: NetworkConfig.timeout,
        sendTimeout: NetworkConfig.timeout,
        headers: const {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    _attachAdapter(dio);
    if (kDebugMode) dio.interceptors.add(_logger());
    return dio;
  }

  static Dio _buildNominatimDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.nominatimBaseUrl,
        connectTimeout: NetworkConfig.timeout,
        receiveTimeout: NetworkConfig.timeout,
        sendTimeout: NetworkConfig.timeout,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'LaffehRoutePlanner/1.0 (https://www.afdal.tech/)',
        },
        responseType: ResponseType.json,
      ),
    );

    _attachAdapter(dio);
    if (kDebugMode) dio.interceptors.add(_logger());
    return dio;
  }

  static Dio _buildPhotonDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.photonBaseUrl,
        connectTimeout: NetworkConfig.timeout,
        // Short on purpose: this one runs while the driver is typing, and a
        // stalled autocomplete request has to get out of the way rather
        // than hold the list hostage for a minute.
        receiveTimeout: GeocodingConfig.providerTimeout,
        sendTimeout: GeocodingConfig.providerTimeout,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'LaffehRoutePlanner/1.0 (https://www.afdal.tech/)',
        },
        responseType: ResponseType.json,
      ),
    );

    _attachAdapter(dio);
    if (kDebugMode) dio.interceptors.add(_logger());
    return dio;
  }

  static Dio _buildOverpassDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.overpassBaseUrl,
        connectTimeout: NetworkConfig.timeout,
        receiveTimeout: GeocodingConfig.categoryTimeout,
        sendTimeout: GeocodingConfig.categoryTimeout,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'LaffehRoutePlanner/1.0 (https://www.afdal.tech/)',
        },
        responseType: ResponseType.json,
      ),
    );

    _attachAdapter(dio);
    if (kDebugMode) dio.interceptors.add(_logger());
    return dio;
  }

  static void _attachAdapter(Dio dio) {
    if (kIsWeb) return;

    final adapter = dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) return;

    adapter.createHttpClient = () {
      final client = HttpClient()
        ..idleTimeout = const Duration(seconds: 10)
        ..connectionTimeout = const Duration(seconds: 30);
      // In debug, tolerate self-signed certs while testing local proxies.
      client.badCertificateCallback = (cert, host, port) => kDebugMode;
      return client;
    };
  }

  static PrettyDioLogger _logger() => PrettyDioLogger(
    requestHeader: true,
    requestBody: true,
    responseBody: true,
    error: true,
    compact: true,
    maxWidth: 120,
  );

  static void reset() {
    _aiRouteDio = null;
    _osrmDio = null;
    _nominatimDio = null;
    _photonDio = null;
    _overpassDio = null;
  }
}
