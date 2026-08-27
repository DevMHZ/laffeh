import 'dart:developer' as developer;

import '../../../../core/error/supabase_error_debug.dart';
import '../../domain/entities/saved_route.dart';
import '../../domain/repositories/saved_routes_repository.dart';
import '../datasources/saved_routes_local_datasource.dart';
import '../datasources/saved_routes_remote_datasource.dart';
import '../models/saved_route_model.dart';

/// Local-first route history with an optional account mirror.
///
/// The on-device copy stays the one the UI reads: it is instant, it works with
/// no signal, and it is all a driver on the no-account trial has. Every
/// mutation is written there first and only then echoed to the account, so a
/// failed or absent network never costs the driver a save.
///
/// The mirror is deliberately not transactional. A push that fails leaves the
/// account one revision behind, and [sync] closes the gap the next time it
/// runs; a *delete* that fails is remembered as a tombstone, because that is
/// the one direction where losing the message resurrects data the driver
/// meant to be rid of.
class SavedRoutesRepositoryImpl implements SavedRoutesRepository {
  SavedRoutesRepositoryImpl(
    this._ds, {
    SavedRoutesRemoteDataSource? remote,
    String? Function()? currentUserId,
  }) : _remote = remote,
       _currentUserId = currentUserId;

  final SavedRoutesLocalDataSource _ds;
  final SavedRoutesRemoteDataSource? _remote;
  final String? Function()? _currentUserId;

  static const String _tag = '💾 SavedRoutesRepo';

  /// The remote, but only while there is a session to mirror into.
  SavedRoutesRemoteDataSource? get _mirror {
    final remote = _remote;
    if (remote == null) return null;
    final uid = _currentUserId?.call();
    return (uid == null || uid.isEmpty) ? null : remote;
  }

  @override
  Future<List<SavedRoute>> list() async {
    final all = await _ds.readAll();
    final entities = all.map((m) => m.toEntity()).toList();
    entities.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    developer.log('list(): ${entities.length} saved route(s)', name: _tag);
    return entities;
  }

  @override
  Future<SavedRoute?> getById(String id) async {
    final all = await _ds.readAll();
    for (final m in all) {
      if (m.id == id) return m.toEntity();
    }
    return null;
  }

  @override
  Future<SavedRoute> upsert(SavedRoute route) async {
    developer.log('upsert: ▶ start, incoming id="${route.id}"', name: _tag);

    final List<SavedRouteModel> all;
    try {
      all = (await _ds.readAll()).toList(); // mutable copy
      developer.log(
        'upsert: read existing → ${all.length} entries',
        name: _tag,
      );
    } catch (e, st) {
      developer.log(
        'upsert: ❌ readAll failed',
        error: e,
        stackTrace: st,
        name: _tag,
      );
      rethrow;
    }

    final ensuredId = route.id.isEmpty
        ? 'r_${DateTime.now().microsecondsSinceEpoch}'
        : route.id;
    final updated = route.copyWith(id: ensuredId);

    final SavedRouteModel model;
    try {
      model = SavedRouteModel.fromEntity(updated);
      developer.log('upsert: model built (id=$ensuredId)', name: _tag);
    } catch (e, st) {
      developer.log(
        'upsert: ❌ SavedRouteModel.fromEntity threw',
        error: e,
        stackTrace: st,
        name: _tag,
      );
      rethrow;
    }

    final idx = all.indexWhere((m) => m.id == ensuredId);
    if (idx >= 0) {
      all[idx] = model;
      developer.log('upsert: updating existing id=$ensuredId', name: _tag);
    } else {
      all.insert(0, model);
      developer.log(
        'upsert: inserting new id=$ensuredId, total=${all.length}',
        name: _tag,
      );
    }

    try {
      await _ds.writeAll(all);
      developer.log('upsert: ✅ persisted to SharedPreferences', name: _tag);
    } catch (e, st) {
      developer.log(
        'upsert: ❌ writeAll failed',
        error: e,
        stackTrace: st,
        name: _tag,
      );
      rethrow;
    }

    await _push([model]);
    return updated;
  }

  @override
  Future<bool> rename(String id, String newName) async {
    final all = (await _ds.readAll()).toList();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx < 0) return false;
    final entity = all[idx].toEntity().copyWith(name: newName.trim());
    final model = SavedRouteModel.fromEntity(entity);
    all[idx] = model;
    await _ds.writeAll(all);
    await _push([model]);
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    final all = (await _ds.readAll()).toList();
    final before = all.length;
    all.removeWhere((m) => m.id == id);
    if (all.length == before) return false;
    await _ds.writeAll(all);
    await _deleteRemotely([id]);
    return true;
  }

  @override
  Future<void> clearAll() async {
    // Read the ids *before* wiping, so a failed remote wipe still leaves
    // tombstones behind to replay.
    final ids = (await _ds.readAll()).map((m) => m.id).toList();
    await _ds.clear();

    final remote = _mirror;
    if (remote == null) return;
    try {
      await remote.deleteEverything();
      await _ds.writeDeletedIds(const []);
      developer.log('clearAll: ✅ account history wiped too', name: _tag);
    } catch (e) {
      developer.log(
        'clearAll: account wipe failed — ${ids.length} tombstone(s) kept',
        name: _tag,
      );
      SupabaseErrorDebug.dump(e, context: 'saved_routes delete (clear all)');
      for (final id in ids) {
        await _ds.rememberDeleted(id);
      }
    }
  }

  @override
  Future<void> forgetAccount() async {
    await _ds.clear();
    await _ds.writeDeletedIds(const []);
    await _ds.writeOwner(null);
    developer.log('forgetAccount: local history cleared', name: _tag);
  }

  @override
  Future<bool> sync() async {
    final remote = _remote;
    final uid = _currentUserId?.call();
    if (remote == null || uid == null || uid.isEmpty) return false;

    try {
      // A different account on the same handset. The previous driver's trips
      // are not this driver's to read, and their unsynced ones are gone — the
      // cost of not leaving one person's route history on another's screen.
      final owner = _ds.readOwner();
      if (owner != null && owner != uid) {
        developer.log(
          'sync: account changed ($owner → $uid) — dropping local history',
          name: _tag,
        );
        await _ds.writeAll(const []);
        await _ds.writeDeletedIds(const []);
      }

      // Replay deletions first: pulling before them would hand the driver
      // back the very trips they threw away while offline.
      final tombstones = _ds.readDeletedIds();
      if (tombstones.isNotEmpty) {
        await remote.deleteAll(tombstones);
        await _ds.writeDeletedIds(const []);
        developer.log(
          'sync: replayed ${tombstones.length} deletion(s)',
          name: _tag,
        );
      }

      final local = await _ds.readAll();
      final signatureBefore = _signature(local);
      final localIds = {for (final m in local) m.id};

      // Merge by id, newest save wins. Anything deleted a moment ago is
      // dropped on the way in: the delete and the read are two round trips,
      // and a row that survives the first (a lagging replica, a delete that
      // matched nothing) must not come back through the second.
      final justDeleted = tombstones.toSet();
      final merged = <String, SavedRouteModel>{};
      for (final m in await remote.fetchAll()) {
        if (m.id.isNotEmpty && !justDeleted.contains(m.id)) merged[m.id] = m;
      }

      // Anything the account is missing or holds an older copy of goes up —
      // which is also how trips saved during the no-account trial are adopted
      // the first time the driver signs in.
      final push = <SavedRouteModel>[];
      for (final m in local) {
        if (m.id.isEmpty) continue;
        final theirs = merged[m.id];
        if (theirs == null || _savedAt(m).isAfter(_savedAt(theirs))) {
          merged[m.id] = m;
          push.add(m);
        }
      }
      if (push.isNotEmpty) await remote.upsertAll(push);

      final all = merged.values.toList()
        ..sort((a, b) => _savedAt(b).compareTo(_savedAt(a)));
      await _ds.writeAll(all);
      await _ds.writeOwner(uid);

      final pulled = all.where((m) => !localIds.contains(m.id)).length;
      developer.log(
        'sync: ✅ ${all.length} route(s) on the account — '
        'pushed ${push.length}, pulled $pulled',
        name: _tag,
      );
      return _signature(all) != signatureBefore;
    } catch (e, st) {
      // Never fatal: the local history is intact and the next sync retries.
      developer.log('sync: ❌ failed', error: e, stackTrace: st, name: _tag);
      SupabaseErrorDebug.dump(e, context: 'saved_routes sync', stack: st);
      return false;
    }
  }

  // ── Mirroring ─────────────────────────────────────────

  /// Echoes a local write to the account. A failure is logged and dropped —
  /// [sync] finds the gap later, because the local record is newer than the
  /// account's copy (or missing from it entirely).
  Future<void> _push(List<SavedRouteModel> models) async {
    final remote = _mirror;
    if (remote == null) return;
    try {
      await remote.upsertAll(models);
      developer.log('push: ✅ ${models.length} route(s) mirrored', name: _tag);
    } catch (e) {
      developer.log('push: mirror failed (retried on next sync)', name: _tag);
      SupabaseErrorDebug.dump(e, context: 'saved_routes upsert');
    }
  }

  /// Echoes a local delete. Unlike a push this cannot simply be dropped: with
  /// no record of the deletion the next pull would restore the route.
  Future<void> _deleteRemotely(List<String> ids) async {
    final remote = _mirror;
    if (remote == null) return;
    try {
      await remote.deleteAll(ids);
      developer.log('delete: ✅ ${ids.length} removed from account', name: _tag);
    } catch (e) {
      developer.log('delete: account copy survived, tombstoned', name: _tag);
      SupabaseErrorDebug.dump(e, context: 'saved_routes delete');
      for (final id in ids) {
        await _ds.rememberDeleted(id);
      }
    }
  }

  static DateTime _savedAt(SavedRouteModel m) =>
      DateTime.tryParse(m.savedAtIso) ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Cheap "did the list change" fingerprint: ids plus their save stamps.
  static String _signature(List<SavedRouteModel> models) {
    final parts = [for (final m in models) '${m.id}@${m.savedAtIso}']..sort();
    return parts.join('|');
  }
}
