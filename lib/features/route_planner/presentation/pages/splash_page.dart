import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../core/services/location_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../onboarding/presentation/pages/onboarding_page.dart';
import '../widgets/laffa_road_loader.dart';

part 'splash_page_widgets.dart';

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
///
/// It is also where the location question gets settled ([LocationGate]): the
/// splash does not hand off until access is granted, or the driver has been
/// asked and chosen to go in without it. The planner used to be the first
/// place that asked, which meant a driver could be looking at a map centred on
/// a fallback city before anything explained why.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  /// Whether this launch goes through the location gate at all. A first run
  /// does not: the walkthrough's own location slide asks a moment later, right
  /// after explaining why. Prompting here, before the app has said a word
  /// about itself, is worse for the driver and is exactly the context-free
  /// permission request App Store review objects to.
  late final bool _seenOnboarding;

  /// `null` until the gate has an answer; the dots keep spinning meanwhile.
  LocationAccess? _access;
  bool _showOver = false;
  bool _wentInWithout = false;
  bool _resolving = false;
  bool _navigated = false;

  bool get _locationSettled =>
      !_seenOnboarding || _wentInWithout || _access == LocationAccess.granted;

  bool get _showsGate => _showOver && !_locationSettled && _access != null;

  @override
  void initState() {
    super.initState();
    // Let Flutter draw behind status + nav bars.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_splashOverlay);

    // Shared show window: the road-logo car and the bottom-strip car both run
    // over this exact span so they start and finish together.
    _intro = AnimationController(vsync: this, duration: _showDuration)
      ..forward();
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

    // Guarded because the splash is also pumped bare in a widget preview,
    // with no service locator behind it — there the gate simply sits out.
    _seenOnboarding =
        sl.isRegistered<SharedPreferences>() &&
        (sl<SharedPreferences>().getBool(AppStrings.onboardingDoneKey) ??
            false);
    if (_seenOnboarding) {
      // Observed so a driver sent out to the system settings is re-checked
      // when they come back, without having to tap anything again.
      WidgetsBinding.instance.addObserver(this);
      unawaited(_resolveLocation());
    }

    // Both cars finish at _showDuration; give the pins a beat to settle, then
    // hand off — or show the gate, if location is still unanswered.
    Timer(_showDuration + const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _showOver = true);
      _handOff();
    });
  }

  Future<void> _resolveLocation() async {
    final access = await LocationGate.resolve();
    if (!mounted) return;
    setState(() {
      _access = access;
      _resolving = false;
    });
    _handOff();
  }

  /// Backs the gate's "Enable location" button. [LocationUtils.resolveAccess]
  /// picks the right remedy for whatever is actually blocking access; when it
  /// returns false the driver is now in the system settings, and
  /// [didChangeAppLifecycleState] takes it from there.
  Future<void> _enableLocation() async {
    setState(() => _resolving = true);
    final granted = await LocationUtils.resolveAccess();
    if (!mounted) return;
    if (!granted) {
      setState(() => _resolving = false);
      return;
    }
    await _resolveLocation();
  }

  void _goInWithoutLocation() {
    setState(() => _wentInWithout = true);
    _handOff();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_navigated || _wentInWithout || _resolving || _locationSettled) return;
    if (_access == null) return;
    unawaited(_recheckLocation());
  }

  Future<void> _recheckLocation() async {
    final access = await LocationGate.status();
    if (!mounted) return;
    if (access == LocationAccess.granted) {
      // Granted while we were away — pick up a fix before going in.
      await _resolveLocation();
    } else {
      setState(() => _access = access);
    }
  }

  /// Leaves for the app once the show is over *and* location has an answer.
  void _handOff() {
    if (!mounted || _navigated || !_showOver || !_locationSettled) return;
    _navigated = true;
    _go();
  }

  void _go() {
    if (!mounted) return;
    // First launch goes through onboarding; afterwards routing is decided by
    // [AuthGate] (session / profile / welcome state).
    final Widget next = _seenOnboarding
        ? const AuthGate()
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
    if (_seenOnboarding) WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    _loop.dispose();
    // Restore the rest-of-app overlay style.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  /// Name + tagline, rising in — shared by the show and the gate.
  Widget _brandName() {
    return FadeTransition(
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
                    color: AppColors.asphaltDark.withValues(alpha: 0.22),
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
    );
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
            const LaffaRoadLoader(driveDuration: _showDuration),

            // Everything below sits in the remaining space, bottom-safe.
            // Two layouts, not one with holes punched in it: the show, and
            // the gate that replaces it. The gate drops the flourish and the
            // Spacers — the panel needs that room, and it scrolls rather than
            // overflowing on a short screen.
            Expanded(
              child: SafeArea(
                top: false,
                child: _showsGate
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _brandName(),
                              const SizedBox(height: 26),
                              _LocationGatePanel(
                                access: _access!,
                                busy: _resolving,
                                onEnable: _enableLocation,
                                onContinue: _goInWithoutLocation,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          const Spacer(flex: 2),
                          _brandName(),
                          const Spacer(flex: 2),

                          // The original brand flourish, kept: a little car
                          // drives a straight road, popping its own pins.
                          SizedBox(
                            height: 110,
                            width: double.infinity,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([_intro, _loop]),
                              builder: (_, __) => CustomPaint(
                                painter: _RoadTripPainter(
                                  // Full window so it travels in lock-step
                                  // with the road-logo car above (both start
                                  // and end together).
                                  trip: Curves.easeInOutCubic.transform(
                                    _intro.value,
                                  ),
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
