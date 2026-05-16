import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/afdal_logo.dart';
import 'route_planner_page.dart';

/// Edge-to-edge brand splash.
///
/// The gradient must cover the full physical screen — including
/// behind the status bar and the system nav bar — otherwise the
/// system gives us their default white backgrounds and the splash
/// looks "cropped in half". We achieve this by:
///   * using `SystemChrome.setEnabledSystemUIMode(.edgeToEdge)`
///     so Flutter draws under the system bars, AND
///   * wrapping in an `AnnotatedRegion<SystemUiOverlayStyle>` that
///     makes both bars transparent with light icons.
///
/// On dispose we restore the default UI overlay style so the rest
/// of the app gets the dark icons defined in [AppTheme.systemUi].
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  static const _splashOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    // Let Flutter draw behind status + nav bars.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_splashOverlay);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fadeIn);

    _ctrl.forward();
    Timer(const Duration(milliseconds: 1200), _go);
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const RoutePlannerPage(),
        transitionsBuilder: (_, anim, __, child) {
          final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: Tween(begin: 1.02, end: 1.0).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    // Restore the rest-of-app overlay style.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _splashOverlay,
      child: Scaffold(
        // No SafeArea wrapping: we WANT the gradient under the bars.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                    Color(0xFF0F1B25),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
            // Decorative glow blob — adds depth, costs ~nothing.
            Positioned(
              top: -120,
              right: -100,
              child: _GlowBlob(
                color: AppColors.accent.withOpacity(0.18),
                size: 320,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: _GlowBlob(
                color: AppColors.primary.withOpacity(0.35),
                size: 260,
              ),
            ),

            // Content — uses SafeArea only for the children layout,
            // never for the background.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Spacer(),
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideIn,
                        child: Column(
                          children: [
                            AfdalLogo.full(height: 82),
                            const SizedBox(height: 28),
                            Text(
                              AppStrings.appName,
                              style: AppTextStyles.display
                                  .copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.appTagline,
                              style: AppTextStyles.bodyLg.copyWith(
                                color: AppColors.white.withOpacity(0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          AppStrings.initializing,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.white.withOpacity(0.65),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
