import 'dart:async';

import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/saved_routes/domain/repositories/saved_routes_repository.dart';
import '../utils/debug_log.dart';

/// Keeps the route history and the signed-in account in step.
///
/// The repository does the actual reconciling; this only decides *when*. Two
/// moments matter:
///
///   * **Sign-in.** The whole point of the feature — a driver who signs in on
///     a new phone should find their trips there, and trips saved during the
///     no-account trial should follow them into the account they just made.
///   * **App resume.** Cheap insurance for the other phone: a route saved on
///     the handset in the van shows up on the one at the desk without the
///     driver signing out and back in.
///
/// Everything is best-effort. A failed sync is a log line — the local history
/// is untouched and the next trigger tries again.
///
/// [changes] fires after a sync that actually altered the list, so an open
/// history page can refresh itself.
class SavedRoutesSyncService {
  SavedRoutesSyncService(this._repo, this._auth);

  final SavedRoutesRepository _repo;
  final AuthRepository _auth;

  StreamSubscription<AuthUser?>? _sub;
  final _changes = StreamController<void>.broadcast();
  bool _inFlight = false;
  String? _lastUserId;

  /// Emits when a sync changed what is stored on this device.
  Stream<void> get changes => _changes.stream;

  /// Begins watching the session. Idempotent — a second call is ignored, so
  /// this is safe to call from startup paths that may run twice in tests.
  void start() {
    if (_sub != null) return;
    _lastUserId = _auth.currentUser?.id;
    // Already signed in at launch (the common case — the session is restored
    // from disk before the first frame).
    if (_lastUserId != null) unawaited(syncNow());

    _sub = _auth.authStateChanges().listen((user) {
      final id = user?.id;
      // The stream also fires on token refresh, which is not a new session
      // and does not need a round trip.
      if (id == _lastUserId) return;
      _lastUserId = id;
      if (id == null) {
        DebugLog.supa('savedRoutes sync: signed out — history stays local');
        return;
      }
      DebugLog.supa('savedRoutes sync: signed in — reconciling history');
      unawaited(syncNow());
    });
  }

  /// Runs one reconciliation. Overlapping calls collapse into the first.
  Future<void> syncNow() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final changed = await _repo.sync();
      if (changed && !_changes.isClosed) _changes.add(null);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _changes.close();
  }
}
