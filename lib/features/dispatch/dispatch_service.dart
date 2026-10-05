import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/domain/repositories/auth_repository.dart';
import '../auth/domain/entities/auth_user.dart';
import 'dispatch_strings.dart';

class ReceivedTrip {
  final String id, driverId, name, sender, company;
  final DateTime receivedAt;
  final bool opened;
  final Map<String, dynamic>? document;
  ReceivedTrip.fromJson(Map<String, dynamic> data)
    : id = data['id'] as String,
      driverId = data['driver_id'] as String,
      name = data['trip_name'] as String,
      sender = data['sender_name'] as String,
      company = data['company_name'] as String,
      receivedAt = DateTime.parse(data['created_at'] as String),
      opened = data['opened_at'] != null,
      document = data['document'] == null
          ? null
          : Map<String, dynamic>.from(data['document'] as Map);
}

/// Account-scoped inbox. Never merges dispatch payloads into another user's
/// local history, and discards responses that arrive after a session switch.
class DispatchService extends ChangeNotifier {
  DispatchService(this.auth, this.dio, this.accessToken);
  final AuthRepository auth;
  final Dio dio;
  final String? Function() accessToken;
  StreamSubscription<AuthUser?>? _authSub;
  Timer? _timer;
  String? _userId;
  int _generation = 0;
  bool loading = false, hasMore = false;
  String? error;
  int unread = 0;
  List<ReceivedTrip> trips = [];
  bool get signedIn => auth.currentUser != null;

  void start() {
    if (_authSub != null) return;
    _authSub = auth.authStateChanges().listen((user) => _switchUser(user?.id));
    _switchUser(auth.currentUser?.id);
    resume();
  }

  void _switchUser(String? id) {
    if (id == _userId) return;
    _userId = id;
    _generation++;
    trips = [];
    unread = 0;
    loading = false;
    error = null;
    hasMore = false;
    notifyListeners();
    if (id != null) unawaited(refresh());
  }

  void resume() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    unawaited(refresh());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  Options _options() {
    final token = accessToken();
    if (token == null || auth.currentUser == null) {
      throw StateError(DispatchStrings.sessionChanged);
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> refresh({bool more = false}) async {
    if (!signedIn || loading) return;
    final generation = _generation, id = auth.currentUser!.id;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await dio.get<Map<String, dynamic>>(
        '/dispatch/inbox',
        queryParameters: {'offset': more ? trips.length : 0, 'limit': 50},
        options: _options(),
      );
      if (generation != _generation || id != auth.currentUser?.id) return;
      final data = result.data!;
      final received = (data['trips'] as List)
          .map(
            (r) => ReceivedTrip.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
      trips = more
          ? {
              for (final t in trips) t.id: t,
              for (final t in received) t.id: t,
            }.values.toList()
          : received;
      unread = data['unread_count'] as int;
      hasMore = data['has_more'] == true;
    } catch (_) {
      if (generation == _generation) error = DispatchStrings.failed;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<ReceivedTrip> fetchTrip(String id) async {
    final user = auth.currentUser?.id, generation = _generation;
    final result = await dio.get<Map<String, dynamic>>(
      '/dispatch/inbox/$id',
      options: _options(),
    );
    if (generation != _generation || user != auth.currentUser?.id) {
      throw StateError(DispatchStrings.sessionChanged);
    }
    return ReceivedTrip.fromJson(result.data!);
  }

  Future<void> markOpened(ReceivedTrip trip) async {
    if (auth.currentUser?.id != trip.driverId) return;
    try {
      await dio.post('/dispatch/inbox/${trip.id}/opened', options: _options());
      await refresh();
    } catch (_) {
      /* Retain unread on failure; retrying open is safe. */
    }
  }

  @override
  void dispose() {
    pause();
    _authSub?.cancel();
    super.dispose();
  }
}
