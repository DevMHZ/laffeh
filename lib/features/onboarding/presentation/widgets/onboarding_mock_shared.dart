part of 'onboarding_mock.dart';

// ─────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────

/// A teardrop map pin with a white outline, sized to [size].
class _MockPin extends StatelessWidget {
  final Color color;
  final double size;
  const _MockPin({required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.location_on, size: size, color: AppColors.white),
          Icon(Icons.location_on, size: size * 0.8, color: color),
        ],
      ),
    );
  }
}

/// Soft mini-map: parks, blocks and a couple of roads. Pure paint, no
/// tiles — enough to read as "a map" behind the pins.
class _MapBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDF1E8),
    );

    final park = Paint()..color = AppColors.primarySoft;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.52,
          size.height * 0.08,
          size.width * 0.42,
          size.height * 0.24,
        ),
        const Radius.circular(12),
      ),
      park,
    );

    final block = Paint()..color = const Color(0xFFE1E8DA);
    final blocks = [
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.10,
        size.width * 0.32,
        size.height * 0.18,
      ),
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.58,
        size.width * 0.36,
        size.height * 0.22,
      ),
      Rect.fromLTWH(
        size.width * 0.58,
        size.height * 0.62,
        size.width * 0.34,
        size.height * 0.24,
      ),
    ];
    for (final r in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(9)),
        block,
      );
    }

    final road = Paint()
      ..color = AppColors.white
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.46),
      Offset(size.width, size.height * 0.5),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Strokes a polyline through [points] (normalised 0..1), revealing
/// [progress] of its length.
class _RouteLinePainter extends CustomPainter {
  final List<Offset> points;
  final double progress;
  final Color color;

  _RouteLinePainter({
    required this.points,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || progress <= 0) return;
    final abs = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final path = Path()..moveTo(abs.first.dx, abs.first.dy);
    for (var i = 1; i < abs.length; i++) {
      path.lineTo(abs[i].dx, abs[i].dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter old) =>
      old.progress != progress || old.color != color;
}

/// The location card as WhatsApp draws it — mini-map, pin, "Location".
/// Shared by both import demos: the message the driver receives is the same
/// on either platform; only what happens after the tap differs.
class _WaLocationBubble extends StatelessWidget {
  const _WaLocationBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            // Full width, or the Stack shrinks to the pin inside it and the
            // mini-map collapses into a 26px strip — the column is
            // start-aligned, so nothing else stretches it.
            child: SizedBox(
              height: 70,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
                  _MockPin(color: AppColors.pinRed, size: 26),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 2),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 13,
                  color: Color(0xFF8FA3AD),
                ),
                const SizedBox(width: 3),
                Text(
                  'Location',
                  style: AppTextStyles.mutedSm.copyWith(
                    color: const Color(0xFF8FA3AD),
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

/// One app in a share sheet. [highlighted] is the one the driver is being
/// told to pick.
class _ShareAppTile extends StatelessWidget {
  final bool highlighted;
  final String label;
  final Widget child;
  final Color labelColor;

  const _ShareAppTile({
    required this.highlighted,
    required this.label,
    required this.child,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.16)
            : Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 42, height: 42, child: Center(child: child)),
          const SizedBox(height: 5),
          Text(label, style: AppTextStyles.mutedSm.copyWith(color: labelColor)),
        ],
      ),
    );
  }
}

/// The Laffeh app icon, rounded — the thing to look for in a share sheet.
class _LaffehTileIcon extends StatelessWidget {
  const _LaffehTileIcon();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: Image.asset(
      'assets/laffeh_logo.png',
      width: 40,
      height: 40,
      fit: BoxFit.cover,
    ),
  );
}

/// A finger-tap ripple: two rings expanding out of a point, then gone.
/// [t] is 0..1 over the tap; outside that range nothing is drawn.
class _TapPulse extends StatelessWidget {
  final double t;
  final double size;
  final Color color;

  const _TapPulse({required this.t, this.size = 34, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    // Two rings half a phase apart, so one is always mid-flight. A single
    // ring spends most of its life nearly transparent, and on a looping
    // demo that reads as a smudge rather than a tap.
    final rings = [t % 1.0, (t + 0.5) % 1.0];
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final phase in rings)
              Builder(
                builder: (_) {
                  final grow = Curves.easeOutCubic.transform(phase);
                  final d = size * (0.30 + grow * 0.70);
                  return Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: (1 - grow) * 0.95),
                        width: 2.5,
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of every import story: the Laffeh map, with the shared place
/// dropping onto it and a "+1" to say it is now on the route.
///
/// [drop] and [toast] are 0..1 progressions the caller derives from its own
/// timeline, so each demo can arrive at this moment at its own pace.
class _LandingMapLayer extends StatelessWidget {
  final double drop;
  final double toast;

  const _LandingMapLayer({required this.drop, required this.toast});

  @override
  Widget build(BuildContext context) {
    final e = Curves.elasticOut.transform(drop);
    final dy = -34 * (1 - e);
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
          Positioned(
            left: c.maxWidth / 2 - 17,
            top: c.maxHeight * 0.5 - 34 + dy,
            child: Opacity(
              opacity: (drop * 3).clamp(0.0, 1.0),
              child: _MockPin(color: AppColors.primary, size: 34),
            ),
          ),
          if (toast > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: Opacity(
                  opacity: toast,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+1',
                          style: AppTextStyles.titleSm.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

double _loopFade(double t) {
  if (t < 0.05) return t / 0.05;
  if (t > 0.93) return ((1 - t) / 0.07).clamp(0.0, 1.0);
  return 1.0;
}
