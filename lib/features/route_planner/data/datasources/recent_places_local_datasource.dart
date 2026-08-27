import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/geocoding_config.dart';
import '../../domain/entities/place_suggestion.dart';

/// The places this driver has actually chosen, most recent first.
///
/// The highest-signal source in the whole search, and the only one that
/// costs nothing and works with the radio off. A delivery round is the same
/// twenty addresses most weeks; a driver who typed "مخزن" once and picked
/// the right warehouse should get that warehouse first, instantly, every
/// time after — before any server has been asked anything.
///
/// One JSON list under one key, capped at [GeocodingConfig.maxRecents].
/// Writes are best-effort: losing a recent is a small inconvenience,
/// throwing out of a tap handler is not.
class RecentPlacesLocalDataSource {
  static const String _key = 'laffeh.recent_places.v1';

  final SharedPreferences _prefs;
  const RecentPlacesLocalDataSource(this._prefs);

  List<PlaceSuggestion> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PlaceSuggestion.tryFromJson)
          .whereType<PlaceSuggestion>()
          .toList();
    } catch (e, st) {
      developer.log(
        'Recent places read failed',
        error: e,
        stackTrace: st,
        name: '📍 RecentPlaces',
      );
      return const [];
    }
  }

  /// Records a pick. Re-picking a place moves it to the front rather than
  /// duplicating it — the list is a memory of *where*, not of how often.
  Future<void> remember(PlaceSuggestion place) async {
    try {
      final current = read()
          .where((p) => p.id != place.id && !_sameSpot(p, place))
          .take(GeocodingConfig.maxRecents - 1)
          .toList();
      final updated = [place, ...current];
      await _prefs.setString(
        _key,
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );
    } catch (e, st) {
      developer.log(
        'Recent places write failed',
        error: e,
        stackTrace: st,
        name: '📍 RecentPlaces',
      );
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {
      // Nothing useful to do; the list is a convenience, not a record.
    }
  }

  /// The same place picked twice through two different providers carries
  /// two different ids, so identity here is "within a few metres of".
  static bool _sameSpot(PlaceSuggestion a, PlaceSuggestion b) {
    return (a.latLng.latitude - b.latLng.latitude).abs() < 0.0002 &&
        (a.latLng.longitude - b.latLng.longitude).abs() < 0.0002;
  }
}
