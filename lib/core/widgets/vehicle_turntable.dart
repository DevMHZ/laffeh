import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/vehicle_kind.dart';
import '../theme/vehicle_sprites.dart';

/// Car-game turntable preview of a [VehicleKind]: plays the pre-rendered
/// 72-frame garage-view sheet (one full revolution, 5° per frame) so the
/// vehicle spins in 3D. With [animate] off it holds a single
/// three-quarter frame — the static thumbnail used on the picker tiles.
///
/// Painter-drawn vehicles (the arrow) have no sheet; they spin flat
/// instead, which suits their minimal look.
class VehicleTurntable extends StatefulWidget {
  final VehicleKind kind;
  final double size;
  final bool animate;

  /// Sheet frame shown when not animating (0..71; 5° per frame).
  /// Frame 0 faces away from the camera; 36 faces it head-on — 42 is a
  /// front three-quarter, the classic garage thumbnail.
  final int staticFrame;

  /// Time for one full revolution.
  final Duration period;

  const VehicleTurntable({
    super.key,
    required this.kind,
    required this.size,
    this.animate = true,
    this.staticFrame = 42,
    this.period = const Duration(milliseconds: 4600),
  });

  static const int frames = 72;
  static const int cols = 9;

  @override
  State<VehicleTurntable> createState() => _VehicleTurntableState();
}

class _VehicleTurntableState extends State<VehicleTurntable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  ui.Image? _sheet;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _spin.repeat();
    _loadSheet();
  }

  @override
  void didUpdateWidget(covariant VehicleTurntable old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      _sheet = null;
      _loadSheet();
    }
    if (old.animate != widget.animate) {
      widget.animate ? _spin.repeat() : _spin.stop();
    }
  }

  Future<void> _loadSheet() async {
    final kind = widget.kind;
    final sheet = await VehicleSprites.turntableOf(kind);
    if (mounted && widget.kind == kind) setState(() => _sheet = sheet);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null) {
      final avatar = widget.kind.avatar(size: widget.size * 0.82);
      // Sprite sheet still decoding: hold the avatar perfectly still —
      // a spinning placeholder here read as glitchy flicker.
      if (widget.kind.spriteAsset != null) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: avatar),
        );
      }
      // Painter-drawn vehicle (the arrow): no sheet exists — flat spin.
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: widget.animate
              ? RotationTransition(turns: _spin, child: avatar)
              : Transform.rotate(angle: -math.pi / 4, child: avatar),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (_, __) {
          final frame = widget.animate
              ? (_spin.value * VehicleTurntable.frames).floor() %
                    VehicleTurntable.frames
              : widget.staticFrame % VehicleTurntable.frames;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _TurntableFramePainter(sheet: sheet, frame: frame),
          );
        },
      ),
    );
  }
}

class _TurntableFramePainter extends CustomPainter {
  final ui.Image sheet;
  final int frame;

  const _TurntableFramePainter({required this.sheet, required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    const cols = VehicleTurntable.cols;
    final fw = sheet.width / cols;
    final fh = sheet.height / (VehicleTurntable.frames / cols);
    final src = Rect.fromLTWH(
      (frame % cols) * fw,
      (frame ~/ cols) * fh,
      fw,
      fh,
    );
    canvas.drawImageRect(
      sheet,
      src,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _TurntableFramePainter old) =>
      old.frame != frame || old.sheet != sheet;
}
