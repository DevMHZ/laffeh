import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/theme/app_colors.dart';

/// A small compass ("boussole") that fades in whenever the map is turned away
/// from north — like Google Maps. Its red needle always points to true north;
/// tapping it spins the map back to north-up. During navigation / chase the
/// tap also asks the map to *hold* north via [onResetNorth], so it sticks
/// instead of snapping back to the heading.
class MapCompass extends StatefulWidget {
  final MapController controller;

  /// Called on tap so the host can hold north-up in auto-rotating modes.
  final VoidCallback onResetNorth;

  const MapCompass({
    super.key,
    required this.controller,
    required this.onResetNorth,
  });

  @override
  State<MapCompass> createState() => _MapCompassState();
}

class _MapCompassState extends State<MapCompass>
    with SingleTickerProviderStateMixin {
  StreamSubscription<MapEvent>? _sub;
  late final AnimationController _spin;

  /// Current map rotation in degrees (updated from map events).
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Don't read `controller.camera` here — it isn't available until the map
    // is laid out. Map events fill it in.
    _sub = widget.controller.mapEventStream.listen((_) {
      final r = widget.controller.camera.rotation;
      if (r != _rotation && mounted) setState(() => _rotation = r);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spin.dispose();
    super.dispose();
  }

  /// Normalised to (-180, 180].
  double get _normalized {
    var r = _rotation % 360;
    if (r > 180) r -= 360;
    if (r < -180) r += 360;
    return r;
  }

  void _resetNorth() {
    HapticFeedback.selectionClick();
    widget.onResetNorth();

    final start = _normalized;
    _spin.stop();
    final anim = Tween<double>(begin: start, end: 0).animate(
      CurvedAnimation(parent: _spin, curve: Curves.easeInOutCubic),
    );
    void tick() => widget.controller.rotate(anim.value);
    anim.addListener(tick);
    _spin.forward(from: 0).whenComplete(() {
      anim.removeListener(tick);
      widget.controller.rotate(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _normalized;
    final visible = r.abs() > 0.6;
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: AppColors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 5,
                shadowColor: AppColors.shadow,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _resetNorth,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      child: Transform.rotate(
                        // Counter-rotate so the red needle holds true north.
                        angle: -r * math.pi / 180,
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

    canvas.drawPath(needle(1), Paint()..color = AppColors.danger); // north
    canvas.drawPath(needle(-1), Paint()..color = AppColors.textMuted); // south

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
