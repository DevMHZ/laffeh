import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The map's aim reticle — a "Wide Duplex" rifle-scope: a thin outer ring with
/// four thick tapered posts that stop short of the centre, leaving a fine inner
/// crosshair and a precise centre dot. A soft ring pulses (zooms in/out and
/// fades) around it, and a small downward chevron bobs just above it as a
/// "look here" marker. Light enough not to hide the map, obvious enough for a
/// driver with the phone mounted.
///
/// The centre of this widget is the exact aim point; the map projects the
/// LatLng beneath it (see `RouteMapViewState.mapCenter`).
class CenterPinWidget extends StatefulWidget {
  final Color color;
  const CenterPinWidget({super.key, required this.color});

  /// Box side. The reticle is drawn centred inside it.
  static const double size = 116;

  @override
  State<CenterPinWidget> createState() => _CenterPinWidgetState();
}

class _CenterPinWidgetState extends State<CenterPinWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CenterPinWidget.size,
      height: CenterPinWidget.size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => CustomPaint(
          painter: _CrosshairPainter(color: widget.color, pulse: _pulse.value),
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color color;
  final double pulse; // 0→1, reverses

  _CrosshairPainter({required this.color, required this.pulse});

  static const _white = AppColors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Soft shadow so it reads on light *and* dark tiles.
    canvas.drawCircle(
      c,
      40,
      Paint()
        ..color = AppColors.asphaltDark.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Pulsing ring — zooms in/out and fades (kept from before).
    canvas.drawCircle(
      c,
      44 + pulse * 9,
      Paint()
        ..color = color.withValues(alpha: 0.30 * (1 - pulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // ── Wide Duplex ──
    const ringR = 38.0;

    // Thin outer ring (white halo + colour).
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..color = _white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Four thick tapered posts (edge → near centre).
    for (final u in const [
      Offset(0, -1),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(1, 0),
    ]) {
      _post(canvas, c, u);
    }

    // Fine inner crosshair: post tip → centre.
    final fineHalo = Paint()
      ..color = _white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final fine = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (final u in const [
      Offset(0, -1),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(1, 0),
    ]) {
      final a = c + u * 11.0;
      final b = c + u * 2.5;
      canvas.drawLine(a, b, fineHalo);
    }
    for (final u in const [
      Offset(0, -1),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(1, 0),
    ]) {
      canvas.drawLine(c + u * 11.0, c + u * 2.5, fine);
    }

    // Precise centre aim dot.
    canvas.drawCircle(c, 4, Paint()..color = _white);
    canvas.drawCircle(c, 2.4, Paint()..color = color);

    // Downward chevron ("reversed ^") bobbing above the ring — a clear
    // "drop here" marker.
    final bob = (pulse - 0.5) * 3.0;
    final apex = Offset(c.dx, c.dy - 40 + bob);
    final chev = Path()
      ..moveTo(apex.dx - 7, apex.dy - 7)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(apex.dx + 7, apex.dy - 7);
    canvas.drawPath(
      chev,
      Paint()
        ..color = _white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      chev,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// One tapered duplex post along unit direction [u].
  void _post(Canvas canvas, Offset c, Offset u) {
    const ro = 37.0, ri = 11.0, wo = 3.6, wi = 0.9;
    final p = Offset(-u.dy, u.dx); // perpendicular
    final path = Path()
      ..moveTo((c + u * ro + p * wo).dx, (c + u * ro + p * wo).dy)
      ..lineTo((c + u * ro - p * wo).dx, (c + u * ro - p * wo).dy)
      ..lineTo((c + u * ri - p * wi).dx, (c + u * ri - p * wi).dy)
      ..lineTo((c + u * ri + p * wi).dx, (c + u * ri + p * wi).dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.pulse != pulse || old.color != color;
}
