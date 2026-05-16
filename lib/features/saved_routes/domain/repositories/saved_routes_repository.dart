import '../entities/saved_route.dart';

/// Persistence contract for the route history feature.
///
/// All methods are idempotent on errors — if storage is missing or
/// corrupt the repo returns sensible defaults (empty list, false)
/// rather than throwing.
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
}
