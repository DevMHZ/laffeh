import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/network/network_info.dart';

void main() {
  final routeService = Uri.parse('https://route.example.test');
  final mapService = Uri.parse('https://map.example.test');

  test(
    'can check connectivity before environment configuration is loaded',
    () async {
      final endpoints = <Uri>[];
      final network = NetworkInfo(
        probe: (endpoint) async {
          endpoints.add(endpoint);
          return true;
        },
      );

      expect(await network.isConnected, isTrue);
      expect(endpoints, hasLength(2));
      expect(endpoints.every((uri) => uri.scheme == 'https'), isTrue);
    },
  );

  test(
    'a routing-service failure does not imply the device is offline',
    () async {
      final network = NetworkInfo(
        endpoints: [routeService, mapService],
        probe: (endpoint) async {
          if (endpoint == routeService) {
            throw const SocketException('unreachable');
          }
          return true;
        },
      );

      expect(await network.isConnected, isTrue);
    },
  );

  test('returns offline when neither service can be reached', () async {
    final network = NetworkInfo(
      endpoints: [routeService, mapService],
      probe: (endpoint) async {
        if (endpoint == mapService) throw const SocketException('no network');
        return false;
      },
    );

    expect(await network.isConnected, isFalse);
  });

  test(
    'does not wait for a stalled service when another one responds',
    () async {
      final stalled = Completer<bool>();
      final network = NetworkInfo(
        endpoints: [routeService, mapService],
        probe: (endpoint) =>
            endpoint == routeService ? stalled.future : Future.value(true),
      );

      expect(await network.isConnected, isTrue);
      expect(stalled.isCompleted, isFalse);
      stalled.complete(false);
    },
  );

  test('coalesces concurrent checks but probes again after a result', () async {
    var calls = 0;
    var pending = Completer<bool>();
    final network = NetworkInfo(
      endpoints: [routeService],
      probe: (_) {
        calls++;
        return pending.future;
      },
    );

    final first = network.isConnected;
    final same = network.isConnected;
    expect(identical(first, same), isTrue);
    expect(calls, 1);
    pending.complete(false);
    expect(await first, isFalse);

    pending = Completer<bool>();
    final reconnected = network.isConnected;
    expect(calls, 2);
    pending.complete(true);
    expect(await reconnected, isTrue);
  });

  testWidgets('a silent connection times out and a retry remains possible', (
    tester,
  ) async {
    var pending = Completer<bool>();
    final network = NetworkInfo(
      endpoints: [routeService, mapService],
      timeout: const Duration(milliseconds: 50),
      probe: (_) => pending.future,
    );
    final first = network.isConnected;
    await tester.pump(const Duration(milliseconds: 51));
    expect(await first, isFalse);

    // A late answer from the old probe must not overwrite a fresh retry.
    final timedOut = pending;
    pending = Completer<bool>();
    final retry = network.isConnected;
    timedOut.complete(false);
    pending.complete(true);
    await tester.pump();
    expect(await retry, isTrue);
  });
}
