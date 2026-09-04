import 'dart:math' as math;

import 'map_chrome_blur.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// "Put the map back": a small control that fades in whenever the map is
/// turned away from north **or** tilted off flat, and returns it to both on
/// a tap.
///
/// It is a compass rose because heading is what it started as, and the rose
/// still counter-rotates so its red needle holds true north. But the angle
/// belongs here too: once the planning map can be tilted by hand, a driver
/// who has leaned it over needs one obvious way back, and a second button
/// beside this one saying almost the same thing would be the wrong answer.
/// The rose tips forward with the map, so a tilted map has a tilted compass
/// — the control looks like the state it undoes.
///
/// [bearing] and [tilt] are [ValueNotifier]s updated by the map widget on
/// every camera move; [onTap] is called so the host can animate the camera
/// back to north-up and flat (and lock it, e.g. during navigation).
class MapCompass extends StatefulWidget {
  final ValueNotifier<double> bearing;
  final ValueNotifier<double> tilt;
  final VoidCallback onTap;

  const MapCompass({
    super.key,
    required this.bearing,
    required this.tilt,
    required this.onTap,
  });

  @override
  State<MapCompass> createState() => _MapCompassState();
}

class _MapCompassState extends State<MapCompass> {
  // Seeded from the notifiers, not assumed flat. A listener only fires on
  // the *next* camera move, so a compass mounted onto a map that is already
  // turned or tilted — coming back from drive mode, say — would otherwise
  // sit invisible until the driver happened to move the camera again, which
  // is exactly when they would be looking for the way back.
  late double _rotation = widget.bearing.value;
  late double _tilt = widget.tilt.value;

  @override
  void initState() {
    super.initState();
    widget.bearing.addListener(_onBearingChanged);
    widget.tilt.addListener(_onTiltChanged);
  }

  @override
  void didUpdateWidget(MapCompass old) {
    super.didUpdateWidget(old);
    if (old.bearing != widget.bearing) {
      old.bearing.removeListener(_onBearingChanged);
      widget.bearing.addListener(_onBearingChanged);
      _rotation = widget.bearing.value;
    }
    if (old.tilt != widget.tilt) {
      old.tilt.removeListener(_onTiltChanged);
      widget.tilt.addListener(_onTiltChanged);
      _tilt = widget.tilt.value;
    }
  }

  @override
  void dispose() {
    widget.bearing.removeListener(_onBearingChanged);
    widget.tilt.removeListener(_onTiltChanged);
    super.dispose();
  }

  void _onBearingChanged() {
    final r = widget.bearing.value;
    if (r != _rotation && mounted) setState(() => _rotation = r);
  }

  void _onTiltChanged() {
    final t = widget.tilt.value;
    if (t != _tilt && mounted) setState(() => _tilt = t);
  }

  double get _normalized {
    var r = _rotation % 360;
    if (r > 180) r -= 360;
    if (r < -180) r += 360;
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final r = _normalized;
    // A degree of either is camera noise, not a driver's decision.
    final visible = r.abs() > 0.6 || _tilt.abs() > 1;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: visible ? 1 : 0.7,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: ClipOval(
            // Shares one backdrop blur pass with the other map chrome via the
            // screen's [BackdropGroup] (graceful standalone fallback otherwise).
            child: maybeBlurChrome(
              sigma: 14,
              child: Material(
                color: AppColors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 5,
                shadowColor: AppColors.shadow,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap();
                  },
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      // Leaned back by the map's own tilt (perspective first,
                      // then heading — the same order the camera applies
                      // them), so the rose reads as a flat disc seen at an
                      // angle. It is the cheapest possible way to say "the
                      // map is tilted, and this is the button that isn't".
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0016)
                          ..rotateX(_tilt.clamp(0, 60) * math.pi / 180)
                          ..rotateZ(-r * math.pi / 180),
                        child: CustomPaint(
                          size: const Size(26, 26),
                          painter: _CompassRosePainter(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    Path needle(double dir) => Path()
      ..moveTo(c.dx, c.dy - r * dir)
      ..lineTo(c.dx - r * 0.32, c.dy)
      ..lineTo(c.dx + r * 0.32, c.dy)
      ..close();

    canvas.drawPath(needle(1), Paint()..color = AppColors.danger);
    canvas.drawPath(needle(-1), Paint()..color = AppColors.textMuted);

    canvas.drawCircle(c, r * 0.15, Paint()..color = AppColors.white);
    canvas.drawCircle(
      c,
      r * 0.15,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassRosePainter old) => false;
}
