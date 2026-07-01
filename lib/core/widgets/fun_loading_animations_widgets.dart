part of 'fun_loading_animations.dart';

class _Looping extends StatefulWidget {
  final Duration period;
  final Widget Function(BuildContext, double phase) builder;
  const _Looping({required this.period, required this.builder});

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => widget.builder(context, _ctrl.value),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Variant 0 — Pin shuffle (the optimizer re-orders the stops)
// ─────────────────────────────────────────────────────────────────

class _PinShuffle extends StatefulWidget {
  const _PinShuffle();

  @override
  State<_PinShuffle> createState() => _PinShuffleState();
}

class _PinShuffleState extends State<_PinShuffle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Which slot each pin currently occupies (pin i → slot order[i]).
  final List<int> _slots = [0, 1, 2, 3];

  /// Swap choreography, repeated forever.
  static const _swaps = [(0, 3), (1, 2), (0, 1), (2, 3), (1, 3), (0, 2)];
  int _swapIndex = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Commit the swap, move on to the next pair.
        final (a, b) = _swaps[_swapIndex];
        final ai = _slots.indexOf(a);
        final bi = _slots.indexOf(b);
        final tmp = _slots[ai];
        _slots[ai] = _slots[bi];
        _slots[bi] = tmp;
        _swapIndex = (_swapIndex + 1) % _swaps.length;
        _ctrl.forward(from: 0);
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _PinShufflePainter(
          t: Curves.easeInOutCubic.transform(_ctrl.value),
          slots: List.of(_slots),
          swap: _swaps[_swapIndex],
        ),
      ),
    );
  }
}

class _PinShufflePainter extends CustomPainter {
  final double t;
  final List<int> slots;
  final (int, int) swap;

  _PinShufflePainter({required this.t, required this.slots, required this.swap});

  static final _colors = [
    AppColors.pinBlue,
    AppColors.pinRed,
    AppColors.pinOrange,
    AppColors.primary,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.58;
    double slotX(int slot) => size.width * (0.17 + 0.22 * slot);

    // Ground line the pins sit on.
    canvas.drawLine(
      Offset(size.width * 0.08, cy + 4),
      Offset(size.width * 0.92, cy + 4),
      Paint()
        ..color = AppColors.surfaceDim
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final (a, b) = swap;
    for (var pin = 0; pin < 4; pin++) {
      final slot = slots.indexOf(pin);
      var x = slotX(slot);
      var y = cy;

      if (pin == a || pin == b) {
        final other = pin == a ? slotX(slots.indexOf(b)) : slotX(slots.indexOf(a));
        x = x + (other - x) * t;
        // One pin arcs over, the other dips under.
        final lift = math.sin(t * math.pi);
        y = cy + (pin == a ? -22.0 * lift : 14.0 * lift);
      }

      canvas.save();
      canvas.translate(x, y);
      _paintPin(canvas, _colors[pin], size.height * 0.26);
      canvas.restore();
    }

    // Thinking sparkles above.
    final sparkle = Paint()
      ..color = AppColors.pinOrange.withValues(alpha: 0.6 * math.sin(t * math.pi))
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final sx = size.width / 2;
    final sy = size.height * 0.16;
    for (var i = 0; i < 4; i++) {
      final ang = i * math.pi / 2 + t * math.pi;
      canvas.drawLine(
        Offset(sx + 4 * math.cos(ang), sy + 4 * math.sin(ang)),
        Offset(sx + 8 * math.cos(ang), sy + 8 * math.sin(ang)),
        sparkle,
      );
    }
  }

  @override
  bool shouldRepaint(_PinShufflePainter old) =>
      old.t != t || old.swap != swap || old.slots.toString() != slots.toString();
}

// ─────────────────────────────────────────────────────────────────
// Variant 1 — Loop drive (tiny car lapping the laffeh loop)
// ─────────────────────────────────────────────────────────────────

class _LoopDrive extends StatelessWidget {
  const _LoopDrive();

  @override
  Widget build(BuildContext context) {
    return _Looping(
      period: const Duration(milliseconds: 2400),
      builder: (_, phase) => CustomPaint(
        painter: _LoopDrivePainter(phase: phase),
      ),
    );
  }
}

class _LoopDrivePainter extends CustomPainter {
  final double phase;
  _LoopDrivePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.33;
    final roadW = size.width * 0.16;

    // Road ring.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW,
    );

    // Lane dashes crawling the opposite way.
    final dashPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = roadW * 0.18
      ..strokeCap = StrokeCap.round;
    const dashes = 9;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      final start = -phase * 2 * math.pi + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        sweep * 0.5,
        false,
        dashPaint,
      );
    }

    // The car, tangent to the ring.
    final angle = phase * 2 * math.pi - math.pi / 2;
    final carPos = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    canvas.save();
    canvas.translate(carPos.dx, carPos.dy);
    canvas.rotate(angle + math.pi / 2);
    _paintMiniCar(canvas, size.width * 0.30);
    canvas.restore();

    // Destination pin in the middle, gently bobbing.
    final bob = math.sin(phase * 4 * math.pi) * 2;
    canvas.save();
    canvas.translate(center.dx, center.dy + size.width * 0.10 + bob);
    _paintPin(canvas, AppColors.pinRed, size.width * 0.22);
    canvas.restore();
  }

  /// A top-view car pointing "up", centered at origin. [len] = body length.
  void _paintMiniCar(Canvas canvas, double len) {
    final w = len * 0.52;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: len),
      Radius.circular(w * 0.32),
    );
    canvas.drawRRect(
      body.shift(Offset(0, len * 0.04)),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.25),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.white);
    // Windshield + rear window.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -len * 0.18),
          width: w * 0.72,
          height: len * 0.2,
        ),
        Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, len * 0.26),
          width: w * 0.66,
          height: len * 0.14,
        ),
        Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.6),
    );
    // Headlights.
    final light = Paint()..color = AppColors.pinOrange;
    canvas.drawCircle(Offset(-w * 0.26, -len * 0.46), w * 0.10, light);
    canvas.drawCircle(Offset(w * 0.26, -len * 0.46), w * 0.10, light);
  }

  @override
  bool shouldRepaint(_LoopDrivePainter old) => old.phase != phase;
}

// ─────────────────────────────────────────────────────────────────
// Variant 2 — Drop & connect (pins land, best path draws itself)
// ─────────────────────────────────────────────────────────────────

class _DropAndConnect extends StatelessWidget {
  const _DropAndConnect();

  @override
  Widget build(BuildContext context) {
    return _Looping(
      period: const Duration(milliseconds: 3600),
      builder: (_, phase) => CustomPaint(
        painter: _DropAndConnectPainter(phase: phase),
      ),
    );
  }
}

class _DropAndConnectPainter extends CustomPainter {
  final double phase;
  _DropAndConnectPainter({required this.phase});

  // Scatter (fractions of size) and the "optimized" visit order.
  static const _spots = [
    Offset(0.24, 0.36),
    Offset(0.72, 0.24),
    Offset(0.78, 0.66),
    Offset(0.34, 0.76),
  ];
  static const _order = [0, 1, 2, 3];
  static final _colors = [
    AppColors.pinBlue,
    AppColors.pinOrange,
    AppColors.pinRed,
    AppColors.primary,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Fade the whole scene out at the end of the loop.
    final fade = phase > 0.92 ? 1 - (phase - 0.92) / 0.08 : 1.0;
    if (fade <= 0) return;

    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: fade),
    );

    _drawGrid(canvas, size);

    final pts = _spots
        .map((f) => Offset(f.dx * size.width, f.dy * size.height))
        .toList();

    // 1) Pins drop in, one per 0.09 of the loop starting at 0.04.
    for (var i = 0; i < pts.length; i++) {
      final start = 0.04 + i * 0.09;
      final local = ((phase - start) / 0.09).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final bounce = Curves.elasticOut.transform(local);
      canvas.save();
      canvas.translate(pts[i].dx, pts[i].dy);
      canvas.scale(bounce);
      _paintPin(canvas, _colors[i], size.height * 0.20);
      canvas.restore();
    }

    // 2) Route draws through them (0.45 → 0.78).
    final draw = ((phase - 0.45) / 0.33).clamp(0.0, 1.0);
    if (draw > 0) {
      final route = _order.map((i) => pts[i]).toList();
      _drawPartialRoute(canvas, route, draw);
    }

    // 3) Stamp of approval (0.80 → 0.92).
    final stamp = ((phase - 0.80) / 0.10).clamp(0.0, 1.0);
    if (stamp > 0) {
      final pop = Curves.easeOutBack.transform(stamp);
      final c = Offset(size.width * 0.52, size.height * 0.50);
      canvas.drawCircle(
        c,
        13.0 * pop,
        Paint()..color = AppColors.primary,
      );
      canvas.drawCircle(
        c,
        13.0 * pop,
        Paint()
          ..color = AppColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final check = Path()
        ..moveTo(c.dx - 5 * pop, c.dy)
        ..lineTo(c.dx - 1.5 * pop, c.dy + 4 * pop)
        ..lineTo(c.dx + 5.5 * pop, c.dy - 4 * pop);
      canvas.drawPath(
        check,
        Paint()
          ..color = AppColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.surfaceDim.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      final y = size.height * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  void _drawPartialRoute(Canvas canvas, List<Offset> route, double t) {
    var total = 0.0;
    final lens = <double>[];
    for (var i = 0; i < route.length - 1; i++) {
      final l = (route[i + 1] - route[i]).distance;
      lens.add(l);
      total += l;
    }
    var remaining = total * t;

    final path = Path()..moveTo(route[0].dx, route[0].dy);
    for (var i = 0; i < lens.length && remaining > 0; i++) {
      if (remaining >= lens[i]) {
        path.lineTo(route[i + 1].dx, route[i + 1].dy);
        remaining -= lens[i];
      } else {
        final f = remaining / lens[i];
        final p = Offset.lerp(route[i], route[i + 1], f)!;
        path.lineTo(p.dx, p.dy);
        remaining = 0;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_DropAndConnectPainter old) => old.phase != phase;
}
