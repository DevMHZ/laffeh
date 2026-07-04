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

/// Classic minimal navigation dart pointing "up" (north at bearing 0):
/// a white-rimmed chevron in the brand green over a soft drop shadow —
/// the "basic" avatar option alongside the pre-rendered 3D sprites.
class TopViewArrowPainter extends CustomPainter {
  const TopViewArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.50, h * 0.08) // nose
      ..lineTo(w * 0.88, h * 0.88) // rear right
      ..lineTo(w * 0.50, h * 0.66) // tail notch
      ..lineTo(w * 0.12, h * 0.88) // rear left
      ..close();

    canvas.drawPath(
      path.shift(Offset(0, h * 0.045)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(path, Paint()..color = AppColors.primary);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
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
