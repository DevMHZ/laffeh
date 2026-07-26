import 'dart:io' show HttpException, SocketException;

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../utils/debug_log.dart';

/// Debug-console unpacking of raw Supabase errors.
///
/// Every repository funnels its `catch` through `AuthErrorMapper.map`, which
/// deliberately collapses the provider error into a stable code — the UI must
/// never show a Postgres string. The cost is that the only fields that say
/// *what actually broke* are dropped on the floor: a failing RPC carries
/// `code` / `details` / `hint`, and none of it ever reached the console. This
/// prints them before the mapping throws them away.
///
/// Read one stream at a time from `flutter run`:
///   flutter run | grep '\[SUPA\]'
class SupabaseErrorDebug {
  SupabaseErrorDebug._();

  /// Prints [error] in full under the `SUPA` tag.
  ///
  /// A no-op unless [DebugLog.enabled] (i.e. `kDebugMode`), so neither the
  /// formatting nor the stack capture costs anything in a release build.
  ///
  /// [context] should name the call that failed — `'save_onboarding'`,
  /// `'device_locations upsert'`. The exception itself never says which RPC or
  /// table produced it, and that is usually the first thing you want to know.
  static void dump(Object error, {String? context, StackTrace? stack}) {
    if (!DebugLog.enabled) return;
    DebugLog.supa('${context == null ? '' : '$context → '}${describe(error)}');
    for (final frame in _appFrames(stack ?? StackTrace.current)) {
      DebugLog.supa('    at $frame');
    }
  }

  /// Renders [error] as a single `Type · key=value · …` line.
  ///
  /// Pure so it can be unit-tested without a console.
  static String describe(Object error) {
    if (error is supa.PostgrestException) {
      return _line('PostgrestException', {
        'code': error.code,
        'message': error.message,
        'details': error.details,
        'hint': error.hint,
        'likely': meaningOf(error.code),
      });
    }
    if (error is supa.AuthException) {
      return _line('AuthException', {
        'code': error.code,
        'status': error.statusCode,
        'message': error.message,
        'likely': meaningOf(error.code),
      });
    }
    if (error is supa.StorageException) {
      return _line('StorageException', {
        'status': error.statusCode,
        'error': error.error,
        'message': error.message,
      });
    }
    if (error is supa.FunctionException) {
      return _line('FunctionException', {
        'status': error.status,
        'reason': error.reasonPhrase,
        'details': error.details,
      });
    }
    if (error is SocketException) {
      return _line('SocketException', {
        'message': error.message,
        'host': error.address?.host ?? error.osError?.message,
        'likely': 'device offline, or SUPABASE_URL unreachable',
      });
    }
    if (error is HttpException) {
      return _line('HttpException', {'message': error.message});
    }
    return _line('${error.runtimeType}', {'toString': '$error'});
  }

  /// Plain-language reading of a Supabase/Postgres error code.
  ///
  /// Only the codes this app can realistically produce — a wrong guess is
  /// worse than no guess when you are chasing something at 2am.
  static String? meaningOf(String? code) => switch (code) {
    // ── PostgREST: the RPC contract ──────────────────────────────────
    'PGRST202' =>
      'no RPC matches that name + argument names — the migration adding it '
          'is probably not applied to this project',
    'PGRST203' =>
      'two overloads match this call — an older version of the function '
          'was never dropped',
    'PGRST204' =>
      'column missing from the schema cache — migration not applied',
    'PGRST301' => 'JWT missing or expired — the caller is not authenticated',
    // ── Postgres: constraints and permissions ────────────────────────
    '42501' => 'RLS denied it — no policy grants this role that row',
    '42883' => 'function does not exist with those argument *types*',
    '42703' => 'column does not exist',
    '23505' => 'unique constraint violation — the row already exists',
    '23503' => 'foreign key violation — the referenced row is missing',
    '23502' => 'not-null violation — a required column was sent as null',
    '22P02' => 'invalid input syntax — a value does not fit its column type',
    'P0001' => "raise exception from inside the function — it's your own check",
    // ── GoTrue ───────────────────────────────────────────────────────
    'phone_provider_disabled' =>
      'phone sign-in is switched off in Supabase → Auth → Providers',
    'signup_disabled' => 'sign-ups are switched off in Supabase → Auth',
    'over_request_rate_limit' => 'rate limited — back off and retry',
    _ => null,
  };

  static String _line(String type, Map<String, Object?> fields) {
    final parts = <String>[type];
    fields.forEach((key, value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return;
      parts.add('$key=$text');
    });
    return parts.join(' · ');
  }

  /// Frames belonging to this app only, minus the two files that report the
  /// error — the Supabase/async plumbing is never where the bug is, and
  /// `dump` / `map` at the top would just push the caller off the first line.
  static List<String> _appFrames(StackTrace stack) => stack
      .toString()
      .split('\n')
      .where(
        (line) =>
            line.contains('package:laffeh/') &&
            !line.contains('supabase_error_debug.dart') &&
            !line.contains('auth_error_mapper.dart'),
      )
      .map((line) => line.trim().replaceFirst(RegExp(r'^#\d+\s+'), ''))
      .take(4)
      .toList(growable: false);
}
