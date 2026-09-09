import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/config/service_profile.dart';

/// A cardboard parcel travelling between the van and the doorstep.
///
/// The three round types are the same three nouns — a van, a parcel, a
/// doorstep — and differ only in which way the parcel goes. Two flat icons
/// separated by an arrowhead put the whole meaning in about six pixels, which
/// is why the stock box-plus/box-minus pair read as the same glyph twice. Two
/// things carry the difference here instead, and both are large:
///
///   * **the van's state** — loaded for a delivery round, empty for a pickup
///     round, half-there when no preference is expressed. Legible in a still
///     frame, which matters because the collapsed settings row shows one.
///   * **the parcel's travel** — it slides out of the van and fades into the
///     doorstep, or lifts off the doorstep and fades into the van.
///
/// The parcel is drawn isometrically and in cardboard beige rather than as a
/// flat tinted square: it is the only object here that is a *thing* rather
/// than a place, and giving it a lid and two side faces is what makes the
/// motion read as a parcel being handled rather than a dot on a track.
/// Stages of one parcel's pass, as fractions of the loop.
///
/// The parcel fades in where it starts, travels, lands, sits there for about
/// a second, fades out, and the next one appears back at the start. A single
/// box shuttling up and down reads as a lift; a box that arrives, is left,
/// and is replaced reads as a round being worked.
const double _fadeInEnd = 0.08;
const double _travelEnd = 0.50;
const double _holdEnd = 0.78; // ~0.9s of the 3.2s loop, sat on the ground
const double _fadeOutEnd = 0.92;

/// Phase the glyph rests at when nothing is animating — mid-travel, fully
/// opaque. Not zero: the parcel fades in, so a still glyph parked at zero is
/// a van and a doorstep with nothing between them, which is exactly what a
/// collapsed settings row renders.
const double kParcelRestingPhase = 0.30;

/// How far along its journey the parcel is at loop position [t], 0→1.
///
/// Delivery accelerates into the ground — it is falling, and stopping dead is
/// what landing looks like. Pickup decelerates into the van, because it is
/// being lifted rather than dropped.
double parcelTravel(double t, ServiceProfile profile) {
  if (profile == ServiceProfile.none) return 0;
  if (t <= _fadeInEnd) return 0;
  if (t >= _travelEnd) return 1;
  final raw = (t - _fadeInEnd) / (_travelEnd - _fadeInEnd);
  return profile == ServiceProfile.delivery
      ? Curves.easeInCubic.transform(raw)
      : Curves.easeOutCubic.transform(raw);
}

/// Parcel opacity at loop position [t].
double parcelOpacity(double t, ServiceProfile profile) {
  if (profile == ServiceProfile.none) return 1;
  if (t < _fadeInEnd) return Curves.easeOut.transform(t / _fadeInEnd);
  if (t <= _holdEnd) return 1;
  if (t >= _fadeOutEnd) return 0;
  return Curves.easeIn.transform(1 - (t - _holdEnd) / (_fadeOutEnd - _holdEnd));
}

class ServiceProfileGlyph extends StatefulWidget {
  final ServiceProfile profile;
  final double size;

  /// Tint for the van and the doorstep. The parcel keeps its own cardboard
  /// colours so it stays a parcel whether the row is selected or not.
  final Color color;

  /// Still frame when false — for a collapsed row, or a golden test.
  final bool animate;

  /// Where in the loop to start, 0..1. Two glyphs side by side moving in
  /// lockstep read as one animation with a mirror; a little offset makes
  /// them read as two separate things.
  final double phaseOffset;

  const ServiceProfileGlyph({
    super.key,
    required this.profile,
    this.size = 34,
    required this.color,
    this.animate = true,
    this.phaseOffset = 0,
  });

  @override
  State<ServiceProfileGlyph> createState() => _ServiceProfileGlyphState();
}

class _ServiceProfileGlyphState extends State<ServiceProfileGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ServiceProfileGlyph old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.profile != widget.profile) _sync();
  }

  /// A row nobody is looking at keeps no ticker running.
  void _sync() {
    final wants = widget.animate;
    if (wants) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = kParcelRestingPhase;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _ServiceProfilePainter(
            profile: widget.profile,
            colour: widget.color,
            t: (_controller.value + widget.phaseOffset) % 1.0,
          ),
        ),
      ),
    );
  }
}

class _ServiceProfilePainter extends CustomPainter {
  final ServiceProfile profile;
  final Color colour;
  final double t;

  _ServiceProfilePainter({
    required this.profile,
    required this.colour,
    required this.t,
  });

  // Cardboard. Three tones so the isometric faces read as one solid object
  // lit from above, rather than three shapes that happen to touch.
  static const Color _lid = Color(0xFFE8C99A);
  static const Color _left = Color(0xFFC9A46F);
  static const Color _right = Color(0xFFB08853);
  static const Color _tape = Color(0xFF8A6A3E);

  // Where the parcel sits at each end of its travel, as a fraction of height.
  static const double _atVan = 0.44;
  static const double _atDoor = 0.70;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── No preference ───────────────────────────────────────────────────
    // No van and no doorstep, because expressing no preference is exactly
    // the absence of a direction between them — drawing the two bars would
    // pose a question this profile declines to answer. Just the parcel,
    // turning on the spot.
    if (profile == ServiceProfile.none) {
      final centre = Offset(w / 2, h / 2);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(2 * math.pi * t);
      canvas.translate(-centre.dx, -centre.dy);
      _paintParcel(canvas, w, centre, 1, grounded: false);
      canvas.restore();
      return;
    }

    final stroke = w * 0.07;

    // ── The van ─────────────────────────────────────────────────────────
    final van = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.05, w * 0.68, h * 0.16),
      Radius.circular(w * 0.06),
    );
    if (profile == ServiceProfile.delivery) {
      canvas.drawRRect(van, Paint()..color = colour); // loaded
    } else {
      canvas.drawRRect(
        van,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke, // empty
      );
    }

    // ── The doorstep ────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(w * 0.28, h * 0.95),
      Offset(w * 0.72, h * 0.95),
      Paint()
        ..color = colour.withValues(alpha: 0.40)
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── The parcel ──────────────────────────────────────────────────────
    final travel = parcelTravel(t, profile);
    final centre = Offset(
      w / 2,
      h *
          (profile == ServiceProfile.delivery
              ? _atVan + (_atDoor - _atVan) * travel
              : _atDoor - (_atDoor - _atVan) * travel),
    );
    _paintParcel(canvas, w, centre, parcelOpacity(t, profile));
  }

  /// An isometric cardboard box, centred on [c].
  void _paintParcel(
    Canvas canvas,
    double w,
    Offset c,
    double opacity, {
    bool grounded = true,
  }) {
    if (opacity <= 0.01) return;
    final half = w * 0.17; // half-width of the footprint
    final lidH = w * 0.10; // vertical extent of the lid rhombus
    final sideH = w * 0.15; // height of the vertical faces

    final top = c.dy - (lidH + sideH) / 2;
    final shoulder = top + lidH; // where the lid meets the walls
    final bottom = shoulder + sideH;

    Paint fill(Color k) => Paint()
      ..color = k.withValues(alpha: opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final lid = Path()
      ..moveTo(c.dx, top)
      ..lineTo(c.dx + half, top + lidH / 2)
      ..lineTo(c.dx, shoulder)
      ..lineTo(c.dx - half, top + lidH / 2)
      ..close();

    final leftFace = Path()
      ..moveTo(c.dx - half, top + lidH / 2)
      ..lineTo(c.dx, shoulder)
      ..lineTo(c.dx, bottom)
      ..lineTo(c.dx - half, bottom - lidH / 2)
      ..close();
    final rightFace = Path()
      ..moveTo(c.dx + half, top + lidH / 2)
      ..lineTo(c.dx, shoulder)
      ..lineTo(c.dx, bottom)
      ..lineTo(c.dx + half, bottom - lidH / 2)
      ..close();

    // A soft contact shadow, so the parcel sits in the scene rather than on
    // top of it. Skipped when the parcel is not on a surface: a tumbling box
    // casting a shadow that tumbles with it reads as a mistake.
    if (grounded) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, bottom + w * 0.05),
          width: half * 1.5,
          height: w * 0.05,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.13 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }

    canvas.drawPath(leftFace, fill(_left));
    canvas.drawPath(rightFace, fill(_right));
    canvas.drawPath(lid, fill(_lid));

    // Tape: across the lid seam and down the front corner.
    final tape = Paint()
      ..color = _tape.withValues(alpha: 0.55 * opacity)
      ..strokeWidth = math.max(1.0, w * 0.035)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx - half, top + lidH / 2),
      Offset(c.dx + half, top + lidH / 2),
      tape,
    );
    canvas.drawLine(Offset(c.dx, shoulder), Offset(c.dx, bottom), tape);
  }

  @override
  bool shouldRepaint(_ServiceProfilePainter old) =>
      old.t != t || old.profile != profile || old.colour != colour;
}
