import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/saved_route_model.dart';

/// Storage backend for the route history.
///
/// We persist a single JSON array under one key. The list is small
/// (rarely more than a few dozen entries) and reads happen only on
/// the history page, so the simple "read whole list / write whole
/// list" pattern beats a full DB for this use case.
class SavedRoutesLocalDataSource {
  static const String _key = 'laffeh.saved_routes.v1';

  final SharedPreferences _prefs;
  const SavedRoutesLocalDataSource(this._prefs);

  Future<List<SavedRouteModel>> readAll() async {
    final raw = _prefs.getString(_key);
    // IMPORTANT: always return a *growable* list. The repository
    // calls `.insert()` / `[idx] = ...` on it, which throws on
    // fixed-length lists (the old bug behind the silent save-failure).
    if (raw == null || raw.isEmpty) return <SavedRouteModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SavedRouteModel>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedRouteModel.fromJson)
          .toList(); // growable by default
    } catch (e, st) {
      developer.log(
        'readAll() decode failed',
        error: e,
        stackTrace: st,
        name: '💾 SavedRoutesDS',
      );
      return <SavedRouteModel>[];
    }
  }

  Future<void> writeAll(List<SavedRouteModel> items) async {
    final json = jsonEncode(items.map((m) => m.toJson()).toList());
    final ok = await _prefs.setString(_key, json);
    developer.log(
      'writeAll: ${items.length} entries → ${json.length} chars, '
      'SharedPreferences.setString returned $ok',
      name: '💾 SavedRoutesDS',
    );
    if (!ok) {
      throw SharedPrefsWriteException(AppStrings.errLocalStorageWrite);
    }
  }

  Future<void> clear() => _prefs.remove(_key);
}

class SharedPrefsWriteException implements Exception {
  final String message;
  const SharedPrefsWriteException(this.message);

  @override
  String toString() => 'SharedPrefsWriteException: $message';
}
