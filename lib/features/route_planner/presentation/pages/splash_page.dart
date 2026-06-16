import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/presentation/pages/onboarding_page.dart';
import '../widgets/laffa_road_loader.dart';
import 'route_planner_page.dart';

/// Edge-to-edge brand splash.
///
/// Painted on the exact logo green ([AppColors.leaf]) so it blends
/// seamlessly with the native launch screen (iOS storyboard and
/// Android `launch_background` use the same color + logo image).
///
/// The show, in order:
///   1. The road-logo fills the top of the screen (its road starting at the
///      very top edge) and a top-down car drives the whole winding road,
///      popping up a blue / red / orange pin at each stop and trailing exhaust —
///      see [LaffaRoadLoader].
///   2. App name + tagline rise in beneath it.
///   3. A second little car drives a straight asphalt road lower down,
///      popping its own pins — the original brand flourish, kept.
///   4. Pin-colored dots bounce as the loading indicator.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  /// One-shot: entrance, shine sweep, car trip.
  late final AnimationController _intro;

  /// Repeating: road dashes, logo breath, loading dots.
  late final AnimationController _loop;

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

  /// The window both cars share, so they begin and end in lock-step.
  static const Duration _showDuration = Duration(milliseconds: 3800);

  @override
  void initState() {
    super.initState();
    // Let Flutter draw behind status + nav bars.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_splashOverlay);

    // Shared show window: the road-logo car and the bottom-strip car both run
    // over this exact span so they start and finish together.
    _intro = AnimationController(
      vsync: this,
      duration: _showDuration,
    )..forward();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.10, 0.45, curve: Curves.easeOutCubic),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(_fadeIn);

    // Both cars finish at _showDuration; give the pins a beat to settle, then
    // hand off.
    Timer(_showDuration + const Duration(milliseconds: 450), _go);
  }

  void _go() {
    if (!mounted) return;
    // First launch goes through onboarding; afterwards straight to the
    // planner. The flag is written when onboarding finishes.
    final prefs = sl<SharedPreferences>();
    final seenOnboarding = prefs.getBool(AppStrings.onboardingDoneKey) ?? false;
    final Widget next = seenOnboarding
        ? const RoutePlannerPage()
        : const OnboardingPage();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, anim, __, child) {
          final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: Tween(begin: 1.03, end: 1.0).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
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
        backgroundColor: AppColors.leaf,
        // Flat logo green on purpose: the logo image carries the same
        // background, so it floats seamlessly with no visible edges.
        body: Column(
          children: [
            // The road-logo scene, flush against the very top edge so its
            // road begins at the top of the phone screen — edge-to-edge,
            // running up behind the status bar. A top-down car drives the
            // whole winding road and pops the three pins as it passes.
            const LaffaRoadLoader(
              driveDuration: _showDuration,
            ),

            // Everything below sits in the remaining space, bottom-safe.
            Expanded(
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Name + tagline rise in.
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideIn,
                        child: Column(
                          children: [
                            Text(
                              AppStrings.appName,
                              style: AppTextStyles.display.copyWith(
                                color: AppColors.white,
                                shadows: [
                                  Shadow(
                                    color: AppColors.asphaltDark.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppStrings.appTagline,
                              style: AppTextStyles.bodyLg.copyWith(
                                color: AppColors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // The original brand flourish, kept: a little car drives
                    // a straight road, popping its own pins.
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_intro, _loop]),
                        builder: (_, __) => CustomPaint(
                          painter: _RoadTripPainter(
                            // Full window so it travels in lock-step with the
                            // road-logo car above (both start and end together).
                            trip: Curves.easeInOutCubic.transform(_intro.value),
                            dashPhase: _loop.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Loading dots in the three pin colors.
                    AnimatedBuilder(
                      animation: _loop,
                      builder: (_, __) => _PinDots(phase: _loop.value),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.initializing,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 28),
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

/// Three bouncing dots in the logo-pin colors.
class _PinDots extends StatelessWidget {
  final double phase;
  const _PinDots({required this.phase});

  static const _colors = [AppColors.pinBlue, AppColors.pinRed, AppColors.pinOrange];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = (phase + i * 0.18) % 1.0;
        // Quick hop with a soft landing.
        final hop = math.sin((t.clamp(0.0, 0.5) / 0.5) * math.pi);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.translate(
            offset: Offset(0, -7 * hop),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.asphaltDark.withValues(alpha: 0.25),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A miniature of the product: a car drives along an asphalt road and
/// a pin pops up (with a bounce) at every stop it passes.
///
/// [trip] 0→1 is the car's journey across the screen; [dashPhase]
/// continuously scrolls the lane dashes so the road feels alive even
/// while the car eases.
class _RoadTripPainter extends CustomPainter {
  final double trip;
  final double dashPhase;

  _RoadTripPainter({required this.trip, required this.dashPhase});

  static const _pinColors = [AppColors.pinBlue, AppColors.pinRed, AppColors.pinOrange];
  // Stops along the road (fraction of width).
  static const _stops = [0.28, 0.52, 0.76];

  @override
  void paint(Canvas canvas, Size size) {
    final roadY = size.height - 34;
    const roadH = 30.0;

    // ── Road bed ──
    final roadRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-4, roadY - roadH / 2, size.width + 8, roadH),
      const Radius.circular(15),
    );
    canvas.drawRRect(
      roadRect.shift(const Offset(0, 3)),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.25),
    );
    canvas.drawRRect(roadRect, Paint()..color = AppColors.asphalt);

    // ── Scrolling center dashes ──
    final dashPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.92)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashLen = 16.0, gap = 14.0, period = dashLen + gap;
    final offset = -dashPhase * period;
    for (var x = offset - period; x < size.width + period; x += period) {
      canvas.drawLine(Offset(x, roadY), Offset(x + dashLen, roadY), dashPaint);
    }

    // ── Pins pop up after the car passes their stop ──
    final carX = _carX(size.width);
    for (var i = 0; i < _stops.length; i++) {
      final stopX = _stops[i] * size.width;
      if (carX < stopX) continue;
      // 0→1 pop driven by how far past the stop the car is.
      final pop = ((carX - stopX) / 60).clamp(0.0, 1.0);
      final bounce = Curves.elasticOut.transform(pop);
      _drawPin(canvas, Offset(stopX, roadY - roadH / 2 - 6), bounce, _pinColors[i]);
    }

    // ── The car ──
    if (trip > 0 && trip < 1) {
      final bob = math.sin(dashPhase * 6 * math.pi) * 1.2;
      _drawCar(canvas, Offset(carX, roadY - roadH / 2 - 1 + bob));
    }
  }

  double _carX(double width) => trip * (width + 160) - 80;

  void _drawPin(Canvas canvas, Offset base, double t, Color color) {
    if (t <= 0.01) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(t);

    const h = 26.0, r = 9.0;
    final body = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-r * 1.15, -h * 0.45, -r, -h + r)
      ..arcTo(
        Rect.fromCircle(center: const Offset(0, -h + r), radius: r),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(r * 1.15, -h * 0.45, 0, 0)
      ..close();

    canvas.drawPath(
      body.shift(const Offset(0, 2)),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.2),
    );
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      const Offset(0, -h + r),
      r * 0.42,
      Paint()..color = AppColors.white,
    );
    canvas.restore();
  }

  void _drawCar(Canvas canvas, Offset ground) {
    canvas.save();
    canvas.translate(ground.dx, ground.dy);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 46, height: 6),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.25),
    );

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -11), width: 44, height: 14),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.white);

    // Cabin
    final cabin = RRect.fromRectAndCorners(
      Rect.fromCenter(center: const Offset(-2, -21), width: 24, height: 11),
      topLeft: const Radius.circular(7),
      topRight: const Radius.circular(7),
    );
    canvas.drawRRect(cabin, Paint()..color = AppColors.white);

    // Windows
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-8, -20.5), width: 9, height: 7),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(3, -20.5), width: 9, height: 7),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85),
    );

    // Headlight
    canvas.drawCircle(
      const Offset(20, -12),
      2.2,
      Paint()..color = AppColors.pinOrange,
    );

    // Wheels (spin with the dashes)
    for (final wx in const [-13.0, 13.0]) {
      canvas.drawCircle(Offset(wx, -3), 5.5, Paint()..color = AppColors.asphaltDark);
      canvas.drawCircle(Offset(wx, -3), 2.4, Paint()..color = AppColors.white);
      final spoke = dashPhase * 2 * math.pi * 3;
      canvas.drawLine(
        Offset(wx + 2.4 * math.cos(spoke), -3 + 2.4 * math.sin(spoke)),
        Offset(wx - 2.4 * math.cos(spoke), -3 - 2.4 * math.sin(spoke)),
        Paint()
          ..color = AppColors.asphaltDark
          ..strokeWidth = 1.2,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoadTripPainter old) =>
      old.trip != trip || old.dashPhase != dashPhase;
}
