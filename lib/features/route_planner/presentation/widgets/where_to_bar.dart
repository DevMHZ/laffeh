import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'add_place_bar.dart';
import 'glass_panel.dart';

/// The first thing on an empty map: a navigator's search box.
///
/// Laffeh's business is multi-stop, but nobody arrives at a map wanting to
/// build a plan — they arrive wanting to get somewhere. So the empty state
/// asks the one question every navigator asks, and the planning vocabulary
/// ("stop", "optimize", "route order") stays out of sight until the driver
/// asks for a second destination and actually needs it.
///
/// The other three ways in — drop a pin, paste a Maps link, import from
/// WhatsApp — keep their place underneath as quiet icon buttons. They are how
/// existing drivers work, and promoting search must not cost them a tap they
/// used to have.
///
/// Underneath them is the door for the other kind of arrival: the driver who
/// opened Laffeh precisely because they have six deliveries and no idea what
/// order to do them in. Progressive disclosure is a kindness to a newcomer
/// and an obstacle to them — they should not have to add a stop, read a
/// navigator card and find "add another stop" to be told what they already
/// came in knowing. One tap says "several stops", and the screen says it back
/// to them ([multiStop]) so the mode is never a silent one.
class WhereToBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onPickOnMap;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWhatsapp;

  /// True once the driver has declared this a multi-stop trip, before any
  /// point exists. Changes what the bar says, not what it does: the ways in
  /// are the same, but the first place they name is a stop in a round rather
  /// than "where to".
  final bool multiStop;

  /// Declares the trip multi-stop, and takes the declaration back.
  final VoidCallback onPlanMultiStop;
  final VoidCallback onExitMultiStop;

  const WhereToBar({
    super.key,
    required this.onSearch,
    required this.onPickOnMap,
    required this.onGoogleMaps,
    required this.onWhatsapp,
    this.multiStop = false,
    required this.onPlanMultiStop,
    required this.onExitMultiStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddPlaceBar(
          // In a multi-stop trip the first place named is a stop among
          // several, so the box asks for one instead of asking where the
          // driver is going.
          title: multiStop ? AppStrings.addPointCta : AppStrings.whereTo,
          onSearch: onSearch,
          onPickOnMap: onPickOnMap,
          onGoogleMaps: onGoogleMaps,
          onWhatsapp: onWhatsapp,
        ),
        const SizedBox(height: 10),
        // The choice itself, last and full width: it is the frame the rest of
        // the screen is read through, not a competitor to the search box.
        TripShapeSelector(
          multiStop: multiStop,
          onSingle: onExitMultiStop,
          onMulti: onPlanMultiStop,
        ),
      ],
    );
  }
}

/// "This trip is: one destination / several stops" — two cards, one of them
/// ticked, and the tick is the point.
///
/// An earlier shape of this control was a single line that turned a mode on.
/// It read as an advertisement, and a driver could not tell by looking at it
/// whether it was something to press, something already on, or a sentence
/// about the app. A pair of options with a radio on each says three things at
/// a glance that no banner can: there is a choice here, it is mine to make,
/// and this is the one that is currently made.
///
/// The drawings carry the meaning for anyone who does not read the label —
/// a dot with a line to one pin, against a winding route threading several.
/// They carry it well enough that the caption that used to sit underneath —
/// a sentence restating the ticked card — was only costing a line of map.
class TripShapeSelector extends StatelessWidget {
  final bool multiStop;
  final VoidCallback onSingle;
  final VoidCallback onMulti;

  const TripShapeSelector({
    super.key,
    required this.multiStop,
    required this.onSingle,
    required this.onMulti,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
            child: Text(
              AppStrings.tripShapeTitle,
              style: AppTextStyles.mutedSm.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Intrinsic so the pair is always the same height: two cards of
          // different heights would read as one being the main option.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ShapeCard(
                    label: AppStrings.tripShapeSingle,
                    selected: !multiStop,
                    multi: false,
                    onTap: onSingle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShapeCard(
                    label: AppStrings.tripShapeMulti,
                    selected: multiStop,
                    multi: true,
                    onTap: onMulti,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two shapes: a picture of the trip, then a radio and its name.
///
/// The picture leads because it is the thing that can be understood without
/// reading — and because it is not a symbol for the trip, it is a small
/// portrait of it, drawn in the same vocabulary the map itself uses: the
/// green dot the driver starts on, the amber numbered stops, the route
/// between them. What the card promises is what the screen will look like.
class _ShapeCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  const _ShapeCard({
    required this.label,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.13)
            : AppColors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.9),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ShapeThumb(multi: multi, selected: selected),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _Tick(selected: selected),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSm.copyWith(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The portrait: a strip of map with the trip drawn on it.
class _ShapeThumb extends StatelessWidget {
  final bool multi;
  final bool selected;

  const _ShapeThumb({required this.multi, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: AspectRatio(
        // The design box the painter is written in.
        aspectRatio: 150 / 52,
        child: CustomPaint(
          painter: _ShapeGlyphPainter(
            multi: multi,
            // Unpicked is drawn in greys: the two pictures must never
            // compete for the eye once one of them is the answer.
            route: selected ? AppColors.primary : AppColors.textMuted,
            mark: selected ? AppColors.accent : AppColors.textMuted,
            ground: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.border.withValues(alpha: 0.35),
            // A trip drawn left-to-right reads backwards to an Arabic
            // reader: it should start where their eye starts.
            mirror: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

/// The radio. A ring until it is chosen, then a filled tick — the one
/// element on the card whose whole job is to say "this is a choice".
class _Tick extends StatelessWidget {
  final bool selected;
  const _Tick({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderStrong,
          width: 1.6,
        ),
      ),
      child: selected
          ? SizedBox(
              width: 12,
              height: 12,
              child: CustomPaint(painter: _TickPainter(color: AppColors.white)),
            )
          : null,
    );
  }
}

/// The two trips, drawn rather than named.
///
///   * single — the driver's dot, one route, one pin. Nothing to order.
///   * multi  — the same dot, a route that visits numbered stops and ends at
///     the last one. The numbers are the whole product in one glance: not
///     "several places" but *several places put in an order*.
///
/// Both routes run **along the streets**. A diagonal line between two pins is
/// a distance, not a trip — no car drives it — and the picture is a promise
/// about what the app does, so it has to obey the same grid the real map
/// does: down this street, left at that one, arrive.
///
/// Hand-drawn instead of picked from an icon font because no icon set has
/// this pair, and the pair is the message.
class _ShapeGlyphPainter extends CustomPainter {
  final bool multi;
  final Color route;
  final Color mark;
  final Color ground;

  /// Flips the drawing for right-to-left reading.
  final bool mirror;

  _ShapeGlyphPainter({
    required this.multi,
    required this.route,
    required this.mark,
    required this.ground,
    this.mirror = false,
  });

  /// Design box the coordinates below are written in; scaled to fit.
  static const Size _box = Size(150, 52);

  /// The street grid every drawing here is laid on. Two avenues and four
  /// cross streets: enough of a city for a route to have to turn in.
  static const List<double> _avenues = [20, 42];
  static const List<double> _streets = [16, 48, 92, 124];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _box.width, size.height / _box.height);
    if (mirror) {
      // The grid mirrors with the trip: the route has to stay on its streets.
      canvas.translate(_box.width, 0);
      canvas.scale(-1, 1);
    }
    _ground(canvas);

    final stroke = Paint()
      ..color = route
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (multi) {
      // Out along the avenue, down a street, back up another — and the two
      // stops sit mid-block on the streets it turns into, where an address
      // actually is.
      canvas.drawPath(
        _along(const [
          Offset(16, 20),
          Offset(48, 20),
          Offset(48, 42),
          Offset(92, 42),
          Offset(92, 20),
          Offset(124, 20),
          Offset(124, 42),
        ]),
        stroke,
      );
      _origin(canvas, const Offset(16, 20));
      _stop(canvas, const Offset(48, 31), '1');
      _stop(canvas, const Offset(92, 31), '2');
      // The last stop is a pin: a round has an end, and the end is a place
      // you arrive at like any other destination.
      _pin(canvas, const Offset(124, 26.6), '3');
    } else {
      canvas.drawPath(
        _along(const [
          Offset(16, 20),
          Offset(92, 20),
          Offset(92, 42),
          Offset(134, 42),
        ]),
        stroke,
      );
      _origin(canvas, const Offset(16, 20));
      _pin(canvas, const Offset(134, 26.6), null);
    }
    canvas.restore();
  }

  /// A polyline through [corners] with its turns rounded, the way a road
  /// bends rather than snapping.
  Path _along(List<Offset> corners, {double radius = 7}) {
    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (var i = 1; i < corners.length - 1; i++) {
      final corner = corners[i];
      final into = _towards(corner, corners[i - 1], radius);
      final out = _towards(corner, corners[i + 1], radius);
      path.lineTo(into.dx, into.dy);
      path.quadraticBezierTo(corner.dx, corner.dy, out.dx, out.dy);
    }
    path.lineTo(corners.last.dx, corners.last.dy);
    return path;
  }

  /// [distance] along the line from [from] towards [to], clamped so a short
  /// leg can never overshoot its own corner.
  Offset _towards(Offset from, Offset to, double distance) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return from;
    return from + delta * (math.min(distance, length / 2) / length);
  }

  /// A strip of city: soft ground with the grid the route runs on. The
  /// streets are drawn wider than the route, so the trip reads as being
  /// *on* them rather than crossing over them.
  void _ground(Canvas canvas) {
    canvas.drawRect(Offset.zero & _box, Paint()..color = ground);
    final tarmac = Paint()
      ..color = AppColors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.6
      ..strokeCap = StrokeCap.round;
    for (final y in _avenues) {
      canvas.drawLine(Offset(-6, y), Offset(_box.width + 6, y), tarmac);
    }
    for (final x in _streets) {
      canvas.drawLine(Offset(x, -6), Offset(x, _box.height + 6), tarmac);
    }
  }

  /// Where the driver is: the map's own green dot, white-cored.
  void _origin(Canvas canvas, Offset at) {
    canvas.drawCircle(at, 7.4, Paint()..color = AppColors.white);
    canvas.drawCircle(at, 6.2, Paint()..color = route);
    canvas.drawCircle(at, 2.6, Paint()..color = AppColors.white);
  }

  /// A numbered stop, exactly as the map draws one.
  void _stop(Canvas canvas, Offset at, String number) {
    canvas.drawCircle(at, 9.4, Paint()..color = AppColors.white);
    canvas.drawCircle(at, 8.2, Paint()..color = mark);
    _number(canvas, at, number);
  }

  /// The destination. [number] is the stop's place in the order, or null
  /// when it is the only place the trip goes.
  void _pin(Canvas canvas, Offset head, String? number) {
    final path = Path()
      ..moveTo(head.dx, head.dy + 15.4)
      ..cubicTo(
        head.dx - 9.6,
        head.dy + 5.0,
        head.dx - 9.2,
        head.dy - 9.2,
        head.dx,
        head.dy - 9.2,
      )
      ..cubicTo(
        head.dx + 9.2,
        head.dy - 9.2,
        head.dx + 9.6,
        head.dy + 5.0,
        head.dx,
        head.dy + 15.4,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = mark);
    if (number == null) {
      canvas.drawCircle(head, 3.4, Paint()..color = AppColors.white);
    } else {
      _number(canvas, head, number);
    }
  }

  void _number(Canvas canvas, Offset at, String text) {
    // Undo the mirror for the digit alone: a flipped "2" is not a number.
    canvas.save();
    if (mirror) {
      canvas.translate(at.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.white,
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w800,
          fontFamily: 'Almarai',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShapeGlyphPainter old) =>
      old.multi != multi ||
      old.route != route ||
      old.mark != mark ||
      old.ground != ground ||
      old.mirror != mirror;
}

/// The tick inside a chosen card. Drawn, not an icon: this one mark is what
/// tells the driver a choice was made, and it must not depend on a font.
class _TickPainter extends CustomPainter {
  final Color color;
  const _TickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.16, h * 0.54)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.86, h * 0.24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.18
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}
