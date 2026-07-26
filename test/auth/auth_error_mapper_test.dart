import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/auth/data/error/auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

void main() {
  group('AuthErrorMapper.map', () {
    test('invalid credentials by code and by message', () {
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('bad', code: 'invalid_credentials'),
        ).code,
        AuthErrorMapper.invalidCredentials,
      );
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('Invalid login credentials'),
        ).code,
        AuthErrorMapper.invalidCredentials,
      );
    });

    test('phone already registered', () {
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('x', code: 'phone_exists'),
        ).code,
        AuthErrorMapper.phoneInUse,
      );
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('User already registered'),
        ).code,
        AuthErrorMapper.phoneInUse,
      );
    });

    test('weak password / rate limit / signups disabled', () {
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('weak', code: 'weak_password'),
        ).code,
        AuthErrorMapper.weakPassword,
      );
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('too many', statusCode: '429'),
        ).code,
        AuthErrorMapper.rateLimited,
      );
      expect(
        AuthErrorMapper.map(
          const supa.AuthException('nope', code: 'signup_disabled'),
        ).code,
        AuthErrorMapper.signupsDisabled,
      );
    });

    test('network from SocketException', () {
      expect(
        AuthErrorMapper.map(const SocketException('offline')).code,
        AuthErrorMapper.network,
      );
    });

    test('falls back to unknown', () {
      expect(
        AuthErrorMapper.map(const supa.AuthException('weird thing')).code,
        AuthErrorMapper.unknown,
      );
      expect(
        AuthErrorMapper.map(Exception('???')).code,
        AuthErrorMapper.unknown,
      );
    });
  });
}
