import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// A small compass that fades in whenever the map is turned away from north.
/// Its red needle always points to true north; tapping it snaps the map back
/// to north-up. [bearing] is a [ValueNotifier] updated by the map widget on
/// every camera move; [onTap] is called so the host can animate the camera
/// back to north and lock it (e.g. during navigation).
class MapCompass extends StatefulWidget {
  final ValueNotifier<double> bearing;
  final VoidCallback onTap;

  const MapCompass({super.key, required this.bearing, required this.onTap});

  @override
  State<MapCompass> createState() => _MapCompassState();
}

class _MapCompassState extends State<MapCompass> {
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    widget.bearing.addListener(_onBearingChanged);
  }

  @override
  void didUpdateWidget(MapCompass old) {
    super.didUpdateWidget(old);
    if (old.bearing != widget.bearing) {
      old.bearing.removeListener(_onBearingChanged);
      widget.bearing.addListener(_onBearingChanged);
    }
  }

  @override
  void dispose() {
    widget.bearing.removeListener(_onBearingChanged);
    super.dispose();
  }

  void _onBearingChanged() {
    final r = widget.bearing.value;
    if (r != _rotation && mounted) setState(() => _rotation = r);
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap();
                  },
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Center(
                      child: Transform.rotate(
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
