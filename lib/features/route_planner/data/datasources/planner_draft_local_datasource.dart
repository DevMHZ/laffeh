import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_draft_model.dart';

/// Persists the in-progress planner draft to local storage.
///
/// One JSON object under one key. Writes are best-effort and must never
/// throw into the UI: losing a draft is unfortunate, crashing on save is
/// worse. Reads tolerate any corruption by returning null.
class PlannerDraftLocalDataSource {
  static const String _key = 'laffeh.planner_draft.v1';

  final SharedPreferences _prefs;
  const PlannerDraftLocalDataSource(this._prefs);

  PlannerDraftModel? read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final draft = PlannerDraftModel.fromJson(decoded);
      return draft.isEmpty ? null : draft;
    } catch (e, st) {
      developer.log(
        'PlannerDraft read failed',
        error: e,
        stackTrace: st,
        name: '💾 PlannerDraft',
      );
      return null;
    }
  }

  Future<void> write(PlannerDraftModel draft) async {
    try {
      await _prefs.setString(_key, jsonEncode(draft.toJson()));
    } catch (e, st) {
      developer.log(
        'PlannerDraft write failed',
        error: e,
        stackTrace: st,
        name: '💾 PlannerDraft',
      );
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }
}
