import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/error/supabase_error_debug.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

void main() {
  group('SupabaseErrorDebug.describe', () {
    test('surfaces every PostgrestException field', () {
      final line = SupabaseErrorDebug.describe(
        const supa.PostgrestException(
          message: 'Could not find the function public.save_onboarding',
          code: 'PGRST202',
          details: 'Searched for the function with parameter names …',
          hint: 'Perhaps you meant to call save_onboarding(p_full_name)',
        ),
      );

      // The whole point: none of these reach the UI, so all must reach here.
      expect(line, contains('PostgrestException'));
      expect(line, contains('code=PGRST202'));
      expect(line, contains('Could not find the function'));
      expect(line, contains('Searched for the function'));
      expect(line, contains('Perhaps you meant'));
      // …plus the reading of the code that saves a round of guessing.
      expect(line, contains('migration'));
    });

    test('surfaces AuthException code and status', () {
      final line = SupabaseErrorDebug.describe(
        const supa.AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
          statusCode: '400',
        ),
      );

      expect(line, contains('AuthException'));
      expect(line, contains('code=invalid_credentials'));
      expect(line, contains('status=400'));
    });

    test('omits absent fields instead of printing nulls', () {
      final line = SupabaseErrorDebug.describe(
        const supa.PostgrestException(message: 'boom'),
      );

      expect(line, 'PostgrestException · message=boom');
      expect(line, isNot(contains('null')));
    });

    test(
      'reads a connectivity failure as offline rather than a backend bug',
      () {
        final line = SupabaseErrorDebug.describe(
          const SocketException('Failed host lookup'),
        );

        expect(line, contains('SocketException'));
        expect(line, contains('offline'));
      },
    );

    test('falls back to the runtime type for anything unrecognised', () {
      final line = SupabaseErrorDebug.describe(StateError('unexpected'));

      expect(line, contains('StateError'));
      expect(line, contains('unexpected'));
    });
  });

  group('SupabaseErrorDebug.meaningOf', () {
    test('explains the two ways a stale RPC contract fails', () {
      // Migration never applied vs. old overload never dropped — the same
      // symptom in the UI, different fixes.
      expect(SupabaseErrorDebug.meaningOf('PGRST202'), contains('not applied'));
      expect(SupabaseErrorDebug.meaningOf('PGRST203'), contains('dropped'));
    });

    test('explains an RLS denial', () {
      expect(SupabaseErrorDebug.meaningOf('42501'), contains('RLS'));
    });

    test('stays silent on codes it does not know', () {
      expect(SupabaseErrorDebug.meaningOf('PGRST999'), isNull);
      expect(SupabaseErrorDebug.meaningOf(null), isNull);
    });
  });
}
