import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../../core/error/exceptions.dart' as core;
import '../../../../core/error/supabase_error_debug.dart';

/// Translates provider (Supabase) auth errors into stable, provider-agnostic
/// codes. The presentation layer maps these codes to localized copy — the raw
/// Supabase message is never shown to the user.
class AuthErrorMapper {
  AuthErrorMapper._();

  // Stable codes (also used as AppStrings keys for the messages).
  static const invalidCredentials = 'invalidCredentials';
  static const phoneInUse = 'phoneInUse';
  static const weakPassword = 'weakPassword';
  static const rateLimited = 'rateLimited';
  static const network = 'network';
  static const signupsDisabled = 'signupsDisabled';
  static const backendUnavailable = 'backendUnavailable';
  static const unknown = 'unknown';

  /// Maps [error] to a stable code, printing the raw provider error to the
  /// debug console on the way through — this is the single funnel every
  /// repository `catch` goes through, so logging here covers all of them.
  ///
  /// [context] names the failing call (`'save_onboarding'`) in that log line.
  static core.AuthException map(Object error, {String? context}) {
    SupabaseErrorDebug.dump(error, context: context);

    if (error is core.AuthException) return error;

    if (error is SocketException || error is HttpException) {
      return const core.AuthException(network, 'connectivity');
    }

    if (error is supa.AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      final status = error.statusCode ?? '';

      if (code == 'invalid_credentials' ||
          msg.contains('invalid login') ||
          msg.contains('invalid phone or password')) {
        return core.AuthException(invalidCredentials, error.message);
      }
      if (code == 'user_already_exists' ||
          code == 'phone_exists' ||
          msg.contains('already registered') ||
          msg.contains('already been registered')) {
        return core.AuthException(phoneInUse, error.message);
      }
      if (code == 'weak_password' || msg.contains('password should be')) {
        return core.AuthException(weakPassword, error.message);
      }
      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          status == '429') {
        return core.AuthException(rateLimited, error.message);
      }
      if (code == 'signup_disabled' ||
          msg.contains('signups not allowed') ||
          msg.contains('signup is disabled')) {
        return core.AuthException(signupsDisabled, error.message);
      }
      return core.AuthException(unknown, error.message);
    }

    return core.AuthException(unknown, error.toString());
  }
}
