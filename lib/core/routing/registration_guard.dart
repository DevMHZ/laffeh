import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../di/service_locator.dart';
import '../services/registration_gate.dart';

/// Enforces the "an account is required now" rule outside of [AuthGate].
///
/// [AuthGate] covers the launch path, but a trial can also run out while the
/// app is open — a user who skipped on day 6 and left the app in the
/// background crosses the line without ever relaunching. The planner re-checks
/// on entry and on resume and calls [enforce] when it does.
class RegistrationGuard {
  RegistrationGuard._();

  /// True when this user has no account and no trial left.
  static bool blocks(BuildContext context) =>
      !context.read<AuthCubit>().isAuthenticated &&
      sl<RegistrationGate>().isRequired;

  /// Replaces the whole navigation stack with the welcome screen in its
  /// "account required" shape. Clearing the stack is the point: there is no
  /// screen behind the wall to go back to.
  static void enforce(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const WelcomePage(registrationRequired: true),
      ),
      (_) => false,
    );
  }

  /// [blocks] + [enforce] in one call. Returns true when it took over, so the
  /// caller can skip whatever it was about to do.
  static bool enforceIfBlocked(BuildContext context) {
    if (!blocks(context)) return false;
    enforce(context);
    return true;
  }
}
