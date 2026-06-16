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

  /// Playback vehicle: a hand-painted top-view car (the same little
  /// character as the splash screen) drawn pointing north and rotated
  /// to [bearing], so it genuinely faces where it's driving — with
  /// speed lines trailing behind for fun.
  static Widget vehicle({required double bearing}) => _MarkerTooltip(
    message: AppStrings.vehicle,
    child: Transform.rotate(
      angle: bearing * math.pi / 180,
      child: const CustomPaint(
        size: Size(40, 40),
        painter: TopViewCarPainter(),
      ),
    ),
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

/// Cute top-view car pointing "up" (north at bearing 0): rounded white
/// body with an asphalt outline so it pops on any map style, blue
/// windshield, orange headlights, and motion lines behind the tail.
/// Top-view car (points up at bearing 0). Reused by the simulation
/// scrubber as the scrub playhead.
class TopViewCarPainter extends CustomPainter {
  const TopViewCarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final len = size.height * 0.62;
    final w = len * 0.56;

    // Speed lines trailing behind (below the tail).
    final lines = Paint()
      ..color = AppColors.asphalt.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (dx, l) in [(-w * 0.22, 5.0), (0.0, 7.5), (w * 0.22, 5.0)]) {
      final y0 = c.dy + len * 0.62;
      canvas.drawLine(
        Offset(c.dx + dx, y0),
        Offset(c.dx + dx, y0 + l),
        lines,
      );
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, len * 0.06),
        width: w * 1.25,
        height: len * 1.05,
      ),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.22),
    );

    // Body.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: len),
      Radius.circular(w * 0.34),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.white);
    canvas.drawRRect(
      body,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Roof (a touch of brand green so it reads as "ours").
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, len * 0.04),
          width: w * 0.74,
          height: len * 0.30,
        ),
        Radius.circular(w * 0.2),
      ),
      Paint()..color = AppColors.primarySoft,
    );

    // Windshield + rear window.
    final glass = Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, -len * 0.20),
          width: w * 0.72,
          height: len * 0.18,
        ),
        const Radius.circular(2.5),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, len * 0.28),
          width: w * 0.66,
          height: len * 0.13,
        ),
        const Radius.circular(2.5),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.55),
    );

    // Headlights up front.
    final light = Paint()..color = AppColors.pinOrange;
    canvas.drawCircle(
      c.translate(-w * 0.26, -len * 0.45),
      w * 0.11,
      light,
    );
    canvas.drawCircle(
      c.translate(w * 0.26, -len * 0.45),
      w * 0.11,
      light,
    );
  }

  @override
  bool shouldRepaint(TopViewCarPainter oldDelegate) => false;
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
