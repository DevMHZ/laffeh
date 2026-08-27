import '../entities/saved_route.dart';

/// Persistence contract for the route history feature.
///
/// All methods are idempotent on errors — if storage is missing or
/// corrupt the repo returns sensible defaults (empty list, false)
/// rather than throwing.
///
/// Reads are always local: the history opens instantly and works with no
/// signal. When a session exists the same records are mirrored to the
/// account, which is what [sync] reconciles.
abstract class SavedRoutesRepository {
  /// All saved routes, newest first.
  Future<List<SavedRoute>> list();

  Future<SavedRoute?> getById(String id);

  /// Insert or upsert. Returns the saved entity (with a fresh id if
  /// the input had none).
  Future<SavedRoute> upsert(SavedRoute route);

  /// Rename by id. Returns true if the route existed.
  Future<bool> rename(String id, String newName);

  Future<bool> delete(String id);

  Future<void> clearAll();

  /// Reconciles the on-device history with the signed-in account: replays
  /// deletions that never landed, pulls the account's routes down, and pushes
  /// up anything the account is missing — including trips saved before the
  /// driver had an account at all.
  ///
  /// Best-effort and safe to call often: signed out, or with no backend
  /// configured, it does nothing. Returns true when the local list actually
  /// changed, so callers know whether a reload is worth it.
  Future<bool> sync();

  /// Wipes the on-device history and the record of whose account it was — the
  /// local half of deleting an account. The account-side rows are removed by
  /// the backend's own cascade, so this never touches the network.
  Future<void> forgetAccount();
}
