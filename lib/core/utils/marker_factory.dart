import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Visit state of a stop during trip playback — mirrors the stop
/// timeline in the preview/drive headline so map and list speak the
/// same color language.
enum StopVisitState { upcoming, visiting, visited }

class MarkerFactory {
  MarkerFactory._();

  static Widget depot({String? tooltip}) => _MarkerTooltip(
    message: tooltip,
    child: _DotMarker(
      color: AppColors.primary,
      child: const Icon(Icons.flag_rounded, color: AppColors.white, size: 12),
    ),
  );

  /// Stop marker. With a [visit] state it renders the playback look:
  ///   * upcoming — white dot with a green ring (still to do)
  ///   * visiting — orange, slightly bigger, glowing (current target)
  ///   * visited  — green with a white check (done)
  static Widget stop(int index, {String? tooltip, StopVisitState? visit}) {
    final child = switch (visit) {
      null => _DotMarker(
        color: AppColors.accent,
        child: Text('$index', style: _numStyle(AppColors.white)),
      ),
      StopVisitState.upcoming => _DotMarker(
        color: AppColors.white,
        borderColor: AppColors.primary,
        child: Text('$index', style: _numStyle(AppColors.primary)),
      ),
      StopVisitState.visiting => _DotMarker(
        color: AppColors.pinOrange,
        size: 26,
        glow: AppColors.pinOrange,
        child: Text('$index', style: _numStyle(AppColors.white)),
      ),
      StopVisitState.visited => _DotMarker(
        color: AppColors.primary,
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.white,
          size: 13,
        ),
      ),
    };
    return _MarkerTooltip(message: tooltip, child: child);
  }

  static TextStyle _numStyle(Color color) => TextStyle(
    fontFamily: 'Almarai',
    fontWeight: FontWeight.w800,
    fontSize: 11,
    color: color,
    height: 1.0,
  );

  static Widget navigationVehicle({required double bearing}) => _MarkerTooltip(
    message: AppStrings.vehicle,
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Transform.rotate(
        angle: bearing * math.pi / 180,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: AppColors.white,
            size: 17,
          ),
        ),
      ),
    ),
  );

  static Widget userLocation({String? tooltip}) => _MarkerTooltip(
    message: tooltip,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
        ),
      ),
    ),
  );
}

/// Speed lines trailing behind a top-down vehicle (below the tail) — the
/// shared "motion cue" every [VehicleKind] painter uses.
void _paintSpeedLines(Canvas canvas, Offset c, double len, double w) {
  final lines = Paint()
    ..color = AppColors.asphalt.withValues(alpha: 0.45)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (final (dx, l) in [(-w * 0.22, 5.0), (0.0, 7.5), (w * 0.22, 5.0)]) {
    final y0 = c.dy + len * 0.62;
    canvas.drawLine(Offset(c.dx + dx, y0), Offset(c.dx + dx, y0 + l), lines);
  }
}

/// Cute top-view VW-bus-style microbus pointing "up" (north at bearing 0):
/// boxy two-tone body (blue over cream), split-windshield hint, and all
/// four wheel arches peeking out at the corners — the boxier stance that
/// tells it apart from a regular car at a glance.
class TopViewVwBusPainter extends CustomPainter {
  const TopViewVwBusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final len = size.height * 0.68;
    final w = len * 0.62;

    _paintSpeedLines(canvas, c, len, w);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, len * 0.05),
        width: w * 1.2,
        height: len * 1.02,
      ),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.22),
    );

    // Wheel arches at all four corners (boxier stance than a car).
    final wheel = Paint()..color = AppColors.asphalt;
    for (final dy in [-len * 0.32, len * 0.32]) {
      for (final dx in [-w * 0.52, w * 0.52]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(dx, dy),
              width: w * 0.16,
              height: len * 0.22,
            ),
            Radius.circular(w * 0.04),
          ),
          wheel,
        );
      }
    }

    // Body — flat-fronted rounded rectangle (the classic boxy microbus).
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: len),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.pinBlue);
    canvas.drawRRect(
      body,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Classic two-tone waistline: a cream band across the middle.
    canvas.drawRect(
      Rect.fromCenter(center: c, width: w * 0.98, height: len * 0.22),
      Paint()..color = AppColors.white.withValues(alpha: 0.92),
    );

    // Split-windshield hint — two front quarter windows.
    final glass = Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85);
    for (final dx in [-w * 0.19, w * 0.19]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(dx, -len * 0.34),
            width: w * 0.30,
            height: len * 0.14,
          ),
          const Radius.circular(2),
        ),
        glass,
      );
    }
    // Rear window.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, len * 0.34),
          width: w * 0.62,
          height: len * 0.12,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.55),
    );

    // Plain front badge (a roundel, no logo mark).
    canvas.drawCircle(
      c.translate(0, -len * 0.46),
      w * 0.09,
      Paint()..color = AppColors.white,
    );
    canvas.drawCircle(
      c.translate(0, -len * 0.46),
      w * 0.09,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Headlights.
    final light = Paint()..color = AppColors.pinOrange;
    canvas.drawCircle(c.translate(-w * 0.36, -len * 0.46), w * 0.07, light);
    canvas.drawCircle(c.translate(w * 0.36, -len * 0.46), w * 0.07, light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cute top-view Vespa scooter pointing "up" (north at bearing 0): a narrow
/// single-track silhouette (wide front leg-shield tapering to a slim tail),
/// mirror "wings" up front, and a round headlight — the shape alone reads
/// as "scooter", never "car", at a glance.
class TopViewVespaPainter extends CustomPainter {
  const TopViewVespaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final len = size.height * 0.64;
    final w = len * 0.34;

    _paintSpeedLines(canvas, c, len, w * 1.6);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, len * 0.06),
        width: w * 1.8,
        height: len,
      ),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.2),
    );

    // Single front + rear wheel (no paired wheels — a single-track vehicle).
    final wheel = Paint()..color = AppColors.asphalt;
    for (final dy in [-len * 0.42, len * 0.4]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(0, dy),
            width: w * 0.5,
            height: len * 0.13,
          ),
          Radius.circular(w * 0.1),
        ),
        wheel,
      );
    }

    // Body — front leg-shield flares wide, tapering to a narrow tail.
    final body = Path()
      ..moveTo(c.dx - w * 0.75, c.dy - len * 0.30)
      ..quadraticBezierTo(
        c.dx - w * 0.9,
        c.dy - len * 0.05,
        c.dx - w * 0.42,
        c.dy + len * 0.38,
      )
      ..quadraticBezierTo(
        c.dx,
        c.dy + len * 0.48,
        c.dx + w * 0.42,
        c.dy + len * 0.38,
      )
      ..quadraticBezierTo(
        c.dx + w * 0.9,
        c.dy - len * 0.05,
        c.dx + w * 0.75,
        c.dy - len * 0.30,
      )
      ..quadraticBezierTo(
        c.dx,
        c.dy - len * 0.5,
        c.dx - w * 0.75,
        c.dy - len * 0.30,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = AppColors.pinRed);
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Cream seat strip down the spine.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, len * 0.08),
          width: w * 0.5,
          height: len * 0.55,
        ),
        Radius.circular(w * 0.2),
      ),
      Paint()..color = AppColors.white.withValues(alpha: 0.85),
    );

    // Handlebar "wings" — mirrors sticking out to the sides up front.
    final chrome = Paint()..color = AppColors.textMuted;
    for (final side in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c.translate(side * w * 1.05, -len * 0.28),
            width: w * 0.5,
            height: w * 0.22,
          ),
          Radius.circular(w * 0.1),
        ),
        chrome,
      );
    }

    // Round Vespa headlight up front.
    canvas.drawCircle(
      c.translate(0, -len * 0.40),
      w * 0.24,
      Paint()..color = AppColors.pinOrange,
    );
    canvas.drawCircle(
      c.translate(0, -len * 0.40),
      w * 0.24,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotMarker extends StatelessWidget {
  final Color color;
  final Widget child;
  final Color borderColor;
  final double size;

  /// Optional colored halo (used by the "visiting" playback state).
  final Color? glow;

  const _DotMarker({
    required this.color,
    required this.child,
    this.borderColor = AppColors.white,
    this.size = 20,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(alpha: 0.55),
              blurRadius: 12,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _MarkerTooltip extends StatelessWidget {
  final String? message;
  final Widget child;

  const _MarkerTooltip({required this.message, required this.child});

  @override
  Widget build(BuildContext context) {
    final text = message?.trim();
    if (text == null || text.isEmpty) return child;
    return Tooltip(message: text, child: child);
  }
}
