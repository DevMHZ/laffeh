import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../config/env_config.dart';

/// Two named Dio instances:
///
///   * [aiRouteDio]   → talks to the Afdal VRP optimizer
///                       (carries the `X-API-Key` header by default).
///   * [osrmDio]      → talks to the public OSRM router
///                       (OpenStreetMap-based; no key).
///   * [nominatimDio] → reverse-geocodes coordinates through OSM's
///                       Nominatim-compatible API.
class DioClient {
  DioClient._();

  static Dio? _aiRouteDio;
  static Dio? _osrmDio;
  static Dio? _nominatimDio;

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

  static Dio _buildAiRouteDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.aiRouteBaseUrl,
        connectTimeout: AppConfig.networkTimeout,
        receiveTimeout: AppConfig.networkTimeout,
        sendTimeout: AppConfig.networkTimeout,
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
        connectTimeout: AppConfig.networkTimeout,
        receiveTimeout: AppConfig.networkTimeout,
        sendTimeout: AppConfig.networkTimeout,
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
        connectTimeout: AppConfig.networkTimeout,
        receiveTimeout: AppConfig.networkTimeout,
        sendTimeout: AppConfig.networkTimeout,
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
  }
}
