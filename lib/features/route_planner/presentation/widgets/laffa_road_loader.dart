import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

part 'laffa_road_loader_painter.dart';

/// The Laffah road-logo brought to life: a top-down car drives the entire
/// winding road — down the tail from the top of the screen, along the bottom,
/// once clockwise around the right roundabout, through the valley, then
/// anti-clockwise around the left roundabout before diving under the road and
/// vanishing. As it passes each stop it pops up a blue / red / orange pin,
/// trails exhaust puffs, and physically slips UNDER the road at the two bridge
/// crossings.
///
/// This is a faithful Flutter port of the original "Laffa Loader" artwork.
/// All geometry is authored in the source art's viewBox (1195 x 896) and
/// scaled to fit the given box. The road bitmap ([assets/laffeh_road.png],
/// transparent background) is painted under the action and re-painted over the
/// car — clipped to the bridge ellipses — to create the under-pass effect, so
/// it sits seamlessly on the [AppColors.leaf] canvas.
class LaffaRoadLoader extends StatefulWidget {
  /// Length of one full drive, tail-to-end.
  final Duration driveDuration;

  /// Pause (all pins shown, car gone) before the loop restarts.
  final Duration holdDuration;

  /// Extra straight tail (in art-board units) drawn ABOVE the bitmap, so the
  /// "ل" lengthens and the roundabouts drop toward the middle of the screen.
  /// 0 = the original artwork. The road bitmap is shifted down by this amount
  /// and the new top region is painted procedurally to match it seamlessly.
  final double tailExtra;

  const LaffaRoadLoader({
    super.key,
    this.driveDuration = const Duration(milliseconds: 4200),
    this.holdDuration = const Duration(milliseconds: 1200),
    this.tailExtra = 520,
  });

  @override
  State<LaffaRoadLoader> createState() => _LaffaRoadLoaderState();
}

/// The road bitmap's own box.
const Size _imgSize = Size(1195, 896);

class _LaffaRoadLoaderState extends State<LaffaRoadLoader>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Bumped each frame to drive the [AnimatedBuilder] repaint.
  final ValueNotifier<int> _repaint = ValueNotifier(0);

  ui.Image? _road;

  /// How far the bitmap is pushed down; the top region is the procedural tail.
  late final double _yShift = widget.tailExtra;

  /// Full art-board height: bitmap plus the extended tail.
  late final double _artHeight = _imgSize.height + _yShift;

  // ── Pre-computed motion ───────────────────────────────────────────────
  late final ui.PathMetric _metric;
  late final double _len;

  /// Drive fraction (0→1) at which each pin pops up.
  late final double _tOrange, _tRed, _tBlue;

  /// The two windows (drive fractions) during which the car is beneath the
  /// road and an over-pass copy must be drawn on top of it.
  late final List<List<double>> _tunnels;

  // ── Live sim state ────────────────────────────────────────────────────
  final List<_Puff> _puffs = [];
  // Fixed seed: the exhaust looks the same but is reproducible (keeps golden
  // tests of the splash deterministic).
  final math.Random _rng = math.Random(42);
  double _lastPuffMs = 0;
  double _lastPhaseMs = -1;

  /// Elapsed-ms clock shared by the simulation and the painter, so the painted
  /// frame always matches the simulated one.
  double _nowMs = 0;

  // Per-pin pop: the elapsed-ms timestamp at which it first appeared (or null).
  double? _orangeShown, _redShown, _blueShown;

  late final double _driveMs = widget.driveDuration.inMilliseconds.toDouble();
  late final double _cycleMs =
      _driveMs + widget.holdDuration.inMilliseconds.toDouble();

  @override
  void initState() {
    super.initState();
    _buildGeometry();
    _loadImage();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/laffeh_road.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _road = frame.image);
  }

  // ── Geometry, ported 1:1 from the source animation ───────────────────
  void _buildGeometry() {
    const d2r = math.pi / 180;
    final dy = _yShift; // the whole logo is pushed down by the longer tail
    const rR = 133.0;
    const rL = 138.0;
    const tailX = 1016.0;
    const botY = 657.0;
    final rc = const Offset(706, 526).translate(0, dy); // right roundabout centre
    final lc = const Offset(297, 512).translate(0, dy); // left roundabout centre

    // A logo point: authored in bitmap coords, then shifted down by [dy].
    Offset q(double x, double y) => Offset(x, y + dy);
    Offset onR(double a) => rc + Offset(rR * math.cos(a * d2r), rR * math.sin(a * d2r));
    Offset onL(double a) => lc + Offset(rL * math.cos(a * d2r), rL * math.sin(a * d2r));

    final pts = <Offset>[];
    final segs = <MapEntry<String, int>>[];
    void mark(String name) => segs.add(MapEntry(name, pts.length));

    void line(Offset a, Offset b, int n) {
      for (var i = 1; i <= n; i++) {
        pts.add(Offset.lerp(a, b, i / n)!);
      }
    }

    void cubic(Offset p0, Offset p1, Offset p2, Offset p3, int n) {
      for (var i = 1; i <= n; i++) {
        final t = i / n, mt = 1 - t;
        final a = mt * mt * mt, b = 3 * mt * mt * t, c = 3 * mt * t * t, d = t * t * t;
        pts.add(Offset(
          a * p0.dx + b * p1.dx + c * p2.dx + d * p3.dx,
          a * p0.dy + b * p1.dy + c * p2.dy + d * p3.dy,
        ));
      }
    }

    void arc(Offset c, double r, double a0, double a1, double step) {
      final dir = a1 >= a0 ? 1 : -1;
      for (var a = a0; dir > 0 ? a <= a1 : a >= a1; a += dir * step) {
        final rad = a * d2r;
        pts.add(c + Offset(r * math.cos(rad), r * math.sin(rad)));
      }
    }

    // A. tail: from above the top edge straight down the (now longer) tail.
    mark('tail');
    pts.add(const Offset(tailX, -40));
    final tailSteps = (20 * (540 + dy) / 540).round();
    line(const Offset(tailX, -40), q(tailX, 500), tailSteps);
    // B. bottom-right rounded corner onto the bottom road
    cubic(q(tailX, 500), q(tailX, 632), q(986, botY), q(902, botY), 18);
    // C. bottom road, ducking toward the right loop's lower lip
    mark('approach');
    line(q(902, botY), q(792, botY + 1), 10);
    cubic(q(792, botY + 1), q(758, botY + 1), q(732, 659), onR(92), 8);
    // D. right roundabout — clockwise, one full turn
    mark('rloop');
    arc(rc, rR, 92, 92 + 360, 3);
    // E. connector through the valley into the left loop's right side
    mark('connector');
    cubic(onR(92), q(600, 672), q(420, 655), onL(8), 20);
    // F. left roundabout — anti-clockwise, a touch past entry so it dives under
    mark('lloop');
    arc(lc, rL, 8, 8 - 372, 3);
    mark('end');

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    _metric = path.computeMetrics().first;
    _len = _metric.length;

    // Cumulative arc-length fraction at the start of each named segment.
    final cum = List<double>.filled(pts.length, 0);
    for (var i = 1; i < pts.length; i++) {
      cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).distance;
    }
    final total = cum.last;
    final fr = <String, double>{
      for (final s in segs) s.key: cum[math.min(s.value, cum.length - 1)] / total,
    };

    // Nearest drive-fraction to a target point (mirrors the source's findFrac).
    double findFrac(double px, double py) {
      var best = double.infinity, bf = 0.0;
      for (var s = 0.0; s <= 1; s += 0.0015) {
        final p = _metric.getTangentForOffset(s * _len)!.position;
        final dd = (p.dx - px) * (p.dx - px) + (p.dy - py) * (p.dy - py);
        if (dd < best) {
          best = dd;
          bf = s;
        }
      }
      return bf;
    }

    _tOrange = findFrac(rc.dx, rc.dy - rR);
    _tRed = findFrac(372, 406 + dy);
    _tBlue = math.max(findFrac(227, 404 + dy), _tRed + 0.0015);

    final t1a = fr['approach']! + 0.78 * (fr['rloop']! - fr['approach']!);
    final t1b = fr['rloop']! + 0.13 * (fr['connector']! - fr['rloop']!);
    final t2a = fr['lloop']! + 0.82 * (fr['end']! - fr['lloop']!);
    _tunnels = [
      [t1a, t1b],
      [t2a, 1.001],
    ];
  }

  // ── Per-frame simulation (faithful to the original frame loop) ────────
  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1000.0;
    _nowMs = now;
    final phase = now % _cycleMs;

    // New cycle: reset pins and exhaust.
    if (phase < _lastPhaseMs) {
      _orangeShown = _redShown = _blueShown = null;
      _puffs.clear();
    }
    _lastPhaseMs = phase;

    if (phase < _driveMs) {
      final p = phase / _driveMs;
      final tan = _metric.getTangentForOffset(p * _len)!;
      final a = tan.position;
      final ang = math.atan2(tan.vector.dy, tan.vector.dx);

      // Car opacity: it slips under the road rather than fading, except at the
      // final tunnel where it dives under for good.
      var op = 1.0;
      if (p < 0.03) op = p / 0.03;
      if (p >= _tunnels[1][0]) {
        op = math.max(0, 1 - (p - _tunnels[1][0]) / 0.03);
      }

      // Exhaust from the rear-left tail-pipe, only while the car is visible.
      if (op > 0.55 && now - _lastPuffMs > 85) {
        final cs = math.cos(ang), sn = math.sin(ang);
        final rx = a.dx + (-46) * cs - 7 * sn;
        final ry = a.dy + (-46) * sn + 7 * cs;
        _puffs.add(_Puff(rx, ry, now, _rng));
        _lastPuffMs = now;
      }

      if (p >= _tOrange) _orangeShown ??= now;
      if (p >= _tRed) _redShown ??= now;
      if (p >= _tBlue) _blueShown ??= now;
    } else {
      // Hold: car gone, all pins resting.
      _puffs.clear();
      _orangeShown ??= now;
      _redShown ??= now;
      _blueShown ??= now;
    }

    // Age out spent puffs so the list never grows unbounded.
    _puffs.removeWhere((pf) => (now - pf.born) / pf.life >= 1);

    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _road?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _imgSize.width / _artHeight,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _repaint,
          builder: (_, __) => CustomPaint(
            painter: _ScenePainter(this),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}
