import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/vehicle_kind.dart';
import '../theme/vehicle_nav_sheet.dart';
import '../theme/vehicle_sprites.dart';

/// The map vehicle avatar as a pseudo-3D nav-sheet frame: picks the baked
/// heading nearest [rotationDegrees] (clockwise from screen-up, i.e. the
/// vehicle-minus-camera bearing the map pucks already compute) plus the
/// distance-driven animation [phase], and applies only the ±3.75° residual
/// as a real rotation so turning stays smooth.
///
/// While the sheet is still decoding — and permanently for painter-drawn
/// vehicles (the arrow) or a missing baked asset — falls back to the flat
/// avatar rotated by the full angle, exactly the pre-3D look.
class VehicleNavFrame extends StatefulWidget {
  final VehicleKind kind;
  final double size;

  /// Clockwise degrees from screen-up (vehicle bearing − camera bearing).
  final double rotationDegrees;

  /// Animation phase (0..[VehicleNavSheet.phases)-1), from travel distance.
  final int phase;

  const VehicleNavFrame({
    super.key,
    required this.kind,
    required this.size,
    required this.rotationDegrees,
    this.phase = 0,
  });

  @override
  State<VehicleNavFrame> createState() => _VehicleNavFrameState();
}

class _VehicleNavFrameState extends State<VehicleNavFrame> {
  ui.Image? _sheet;

  @override
  void initState() {
    super.initState();
    _loadSheet();
  }

  @override
  void didUpdateWidget(covariant VehicleNavFrame old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      _sheet = null;
      _loadSheet();
    }
  }

  Future<void> _loadSheet() async {
    final kind = widget.kind;
    final sheet = await VehicleSprites.navOf(kind);
    if (mounted && widget.kind == kind) setState(() => _sheet = sheet);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null) {
      return Transform.rotate(
        angle: widget.rotationDegrees * math.pi / 180.0,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: widget.kind.avatar(size: widget.size)),
        ),
      );
    }
    return Transform.rotate(
      angle:
          VehicleNavSheet.residualDeg(widget.rotationDegrees) *
          math.pi /
          180.0,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _NavFramePainter(
          sheet: sheet,
          heading: VehicleNavSheet.headingIndex(widget.rotationDegrees),
          phase: widget.phase % VehicleNavSheet.phases,
        ),
      ),
    );
  }
}

class _NavFramePainter extends CustomPainter {
  final ui.Image sheet;
  final int heading;
  final int phase;

  const _NavFramePainter({
    required this.sheet,
    required this.heading,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      sheet,
      VehicleNavSheet.frameRect(sheet, heading, phase),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _NavFramePainter old) =>
      old.heading != heading || old.phase != phase || old.sheet != sheet;
}
