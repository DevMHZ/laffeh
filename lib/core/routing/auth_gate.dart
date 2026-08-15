import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/pages/account_onboarding_page.dart';
import '../../features/route_planner/presentation/pages/route_planner_page.dart';
import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../services/registration_gate.dart';
import '../theme/app_colors.dart';

/// Decides where to send the user after the splash / walkthrough, based on the
/// session and profile state. Login is optional *for a week*, so an
/// unauthenticated user who has already seen the welcome screen still lands in
/// the planner — until the trial they started by skipping runs out.
///
///   * signed in + onboarding complete   → planner
///   * signed in + onboarding incomplete → resume account onboarding
///   * signed out + trial expired        → welcome, account required
///   * signed out + welcome already seen → planner (nudge shows there)
///   * signed out + first time           → welcome
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final auth = sl<AuthCubit>();
    final prefs = sl<SharedPreferences>();

    Widget destination;
    if (auth.isAuthenticated) {
      final complete = await sl<ProfileRepository>().isOnboardingComplete();
      destination = complete
          ? const RoutePlannerPage()
          : const AccountOnboardingPage(startStep: 1, credentialsDone: true);
    } else if (sl<RegistrationGate>().isRequired) {
      // Skipped, and the week that bought is over.
      destination = const WelcomePage(registrationRequired: true);
    } else {
      final welcomeSeen = prefs.getBool(AppStrings.welcomeSeenKey) ?? false;
      destination = welcomeSeen
          ? const RoutePlannerPage()
          : const WelcomePage();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
