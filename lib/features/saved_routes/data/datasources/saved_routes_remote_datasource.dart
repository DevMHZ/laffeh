import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_route_model.dart';

/// Supabase access for `saved_routes` — the account-side copy of the route
/// history.
///
/// The whole record travels as one `payload` document: exactly the JSON the
/// local store already writes, so the two copies can never drift apart and a
/// route saved by an older build still decodes through the same reader. The
/// flat columns are denormalised for whoever queries the table by hand; the
/// app reads nothing but `payload`.
///
/// RLS is owner-only, so every statement here is implicitly scoped to the
/// session. `user_id` is still written and filtered on explicitly — the policy
/// is the guard, not the query, and a query that says what it means survives a
/// policy being edited later.
class SavedRoutesRemoteDataSource {
  SavedRoutesRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _table = 'saved_routes';

  String? get _uid => _client.auth.currentUser?.id;

  /// Every route on the account, newest first. Empty when signed out.
  Future<List<SavedRouteModel>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return const [];

    final rows = await _client
        .from(_table)
        .select('payload')
        .eq('user_id', uid)
        .order('saved_at', ascending: false);

    final out = <SavedRouteModel>[];
    for (final row in rows) {
      final payload = row['payload'];
      // One malformed row must not cost the driver the rest of their history.
      if (payload is Map<String, dynamic>) {
        out.add(SavedRouteModel.fromJson(payload));
      }
    }
    return out;
  }

  /// Inserts or overwrites [models] in one round trip. No-op when signed out
  /// or when there is nothing to send.
  Future<void> upsertAll(List<SavedRouteModel> models) async {
    final uid = _uid;
    if (uid == null || models.isEmpty) return;

    await _client.from(_table).upsert([
      for (final m in models) _rowFor(m, uid),
    ], onConflict: 'user_id,id');
  }

  Future<void> deleteAll(List<String> ids) async {
    final uid = _uid;
    if (uid == null || ids.isEmpty) return;

    await _client.from(_table).delete().eq('user_id', uid).inFilter('id', ids);
  }

  /// Wipes the account's history — the cloud half of "clear all".
  Future<void> deleteEverything() async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from(_table).delete().eq('user_id', uid);
  }

  Map<String, dynamic> _rowFor(SavedRouteModel m, String uid) {
    final entity = m.toEntity();
    return {
      'user_id': uid,
      'id': m.id,
      // The table refuses a blank name; a record from a build that allowed one
      // should still sync rather than fail the whole batch.
      'name': m.name.trim().isEmpty ? '—' : m.name.trim(),
      // `timestamptz` with no offset in the string would be read as the
      // server's zone, quietly shifting the stamp by the driver's own offset.
      'saved_at': entity.savedAt.toUtc().toIso8601String(),
      'routing_mode': m.routingMode,
      'stops_count': entity.stopsCount,
      'distance_km': m.metrics.totalDistanceKm,
      'payload': m.toJson(),
    };
  }
}
