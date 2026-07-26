import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase wrapper: upserts this device's single row in
/// `device_locations`.
///
/// The table holds the *last known* fix, one row per device — not a history.
/// `device_id` is the conflict target, so a launch either creates the row or
/// overwrites it in place.
///
/// RLS allows anon + authenticated insert and update (see the migrations), so
/// this works whether or not the user is signed in.
class LocationPingRemoteDataSource {
  LocationPingRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<void> insert({
    required String deviceId,
    String? userId,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    // Every column is sent unconditionally (nulls included) so the stored row
    // always mirrors the current state — e.g. `user_id` clears after sign-out
    // instead of keeping a stale stamp. `updated_at` is left to the DB default
    // on insert and to the trigger on update.
    await _client.from('device_locations').upsert({
      'device_id': deviceId,
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
    }, onConflict: 'device_id');
  }
}
