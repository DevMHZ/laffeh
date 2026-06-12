import 'dart:developer' as developer;

import '../../domain/entities/saved_route.dart';
import '../../domain/repositories/saved_routes_repository.dart';
import '../datasources/saved_routes_local_datasource.dart';
import '../models/saved_route_model.dart';

class SavedRoutesRepositoryImpl implements SavedRoutesRepository {
  final SavedRoutesLocalDataSource _ds;
  const SavedRoutesRepositoryImpl(this._ds);

  static const String _tag = '💾 SavedRoutesRepo';

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

    return updated;
  }

  @override
  Future<bool> rename(String id, String newName) async {
    final all = (await _ds.readAll()).toList();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx < 0) return false;
    final entity = all[idx].toEntity().copyWith(name: newName.trim());
    all[idx] = SavedRouteModel.fromEntity(entity);
    await _ds.writeAll(all);
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    final all = (await _ds.readAll()).toList();
    final before = all.length;
    all.removeWhere((m) => m.id == id);
    if (all.length == before) return false;
    await _ds.writeAll(all);
    return true;
  }

  @override
  Future<void> clearAll() => _ds.clear();
}
