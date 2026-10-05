import 'dart:async';
import 'dart:io';

import '../config/env_config.dart';

/// Checks actual reachability instead of DNS, which can keep succeeding from
/// the OS cache after the driver loses their connection. A response from
/// either of the app's existing services is enough: a routing-server outage
/// must not disable online features backed by another service.
///
/// No result is cached between checks, so a retry or app resume sees a newly
/// restored connection. Concurre nt callers share the same bounded probe.
class NetworkInfo {
  NetworkInfo({
    Future<bool> Function(Uri)? probe,
    List<Uri>? endpoints,
    this.timeout = const Duration(seconds: 4),
  }) : _probe = probe,
       _endpoints = endpoints;

  final Future<bool> Function(Uri)? _probe;
  final List<Uri>? _endpoints;
  final Duration timeout;
  Future<bool>? _inFlight;

  Future<bool> get isConnected =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  List<Uri> _serviceEndpoints() {
    try {
      return [
        Uri.parse(EnvConfig.aiRouteBaseUrl),
        Uri.parse(EnvConfig.mapStyleUrl),
      ];
    } catch (_) {
      // The connectivity notice must also work if the optional environment
      // asset failed to load during startup.
      return [
        Uri.parse('https://back.laffa.afdal.tech/api/mobile'),
        Uri.parse('https://tiles.openfreemap.org/styles/liberty'),
      ];
    }
  }

  Future<bool> _check() async {
    final endpoints = _endpoints ?? _serviceEndpoints();
    if (endpoints.isEmpty) return false;

    final result = Completer<bool>();
    var pending = endpoints.length;
    for (final endpoint in endpoints) {
      unawaited(() async {
        var connected = false;
        try {
          connected = await (_probe?.call(endpoint) ?? _request(endpoint))
              .timeout(timeout);
        } catch (_) {
          // Includes no network, captive portals, TLS errors and timeouts.
        }
        if (connected && !result.isCompleted) result.complete(true);
        pending--;
        if (pending == 0 && !result.isCompleted) result.complete(false);
      }());
    }
    return result.future;
  }

  Future<bool> _request(Uri endpoint) async {
    final client = HttpClient()..connectionTimeout = timeout;
    // The whole request has a deadline, including a server that accepts a
    // connection but never responds. Close the socket at that deadline too.
    final deadline = Timer(timeout, () => client.close(force: true));
    try {
      final request = await client.openUrl('HEAD', endpoint);
      request.followRedirects = false;
      await request.close();
      // Even an HTTP error confirms connectivity. Repository error handling
      // owns service availability and authentication, not this status banner.
      return true;
    } finally {
      deadline.cancel();
      client.close(force: true);
    }
  }
}
