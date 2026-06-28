part of 'onboarding_mock.dart';

// ─────────────────────────────────────────────────────────────────────
// Plan & optimise demo
// ─────────────────────────────────────────────────────────────────────

class OnbPlanDemo extends StatefulWidget {
  const OnbPlanDemo({super.key});

  @override
  State<OnbPlanDemo> createState() => _OnbPlanDemoState();
}

class _OnbPlanDemoState extends State<OnbPlanDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _pins = [
    Offset(0.30, 0.34),
    Offset(0.64, 0.40),
    Offset(0.50, 0.66),
  ];
  static const _colors = [
    AppColors.pinBlue,
    AppColors.pinRed,
    AppColors.pinOrange,
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final routeProgress = ((t - 0.50) / 0.24).clamp(0.0, 1.0);
        final optimizing = t > 0.46;
        return Opacity(
          opacity: _loopFade(t),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RouteLinePainter(
                        points: _pins,
                        progress: routeProgress,
                        color: AppColors.routeGo,
                      ),
                    ),
                  ),
                  for (var i = 0; i < _pins.length; i++) _buildPin(i, w, h, t),
                  // Mock top stepper chip.
                  Positioned(
                    top: 30,
                    left: 0,
                    right: 0,
                    child: Center(child: _miniStepper(optimizing)),
                  ),
                  // Mock optimise button.
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 16,
                    child: _miniOptimizeButton(optimizing),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPin(int i, double w, double h, double t) {
    final start = 0.08 + i * 0.13;
    final p = ((t - start) / 0.20).clamp(0.0, 1.0);
    if (p <= 0) return const SizedBox.shrink();
    final e = Curves.elasticOut.transform(p);
    final dy = -26 * (1 - e);
    final pos = _pins[i];
    const pinSize = 30.0;
    return Positioned(
      left: pos.dx * w - pinSize / 2,
      top: pos.dy * h - pinSize + dy,
      child: Opacity(
        opacity: (p * 3).clamp(0.0, 1.0),
        child: _MockPin(color: _colors[i], size: pinSize),
      ),
    );
  }

  Widget _miniStepper(bool optimizing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Container(
                width: 10,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                color: (optimizing ? i <= 1 : i == 0)
                    ? AppColors.primary
                    : AppColors.borderStrong,
              ),
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (optimizing ? i <= 1 : i == 0)
                    ? AppColors.primary
                    : AppColors.surfaceDim,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniOptimizeButton(bool optimizing) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      height: 36,
      decoration: BoxDecoration(
        color: optimizing ? AppColors.primary : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.route_rounded,
            size: 15,
            color: optimizing ? AppColors.white : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            AppStrings.optimizeRoute,
            style: AppTextStyles.titleSm.copyWith(
              color: optimizing ? AppColors.white : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// WhatsApp / import demo (the hero)
// ─────────────────────────────────────────────────────────────────────

class OnbWhatsappDemo extends StatefulWidget {
  const OnbWhatsappDemo({super.key});

  @override
  State<OnbWhatsappDemo> createState() => _OnbWhatsappDemoState();
}

class _OnbWhatsappDemoState extends State<OnbWhatsappDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Chat (with the share sheet) cross-fades into the map where the
        // shared point lands.
        final chatOpacity = (1 - ((t - 0.56) / 0.10)).clamp(0.0, 1.0);
        final mapOpacity = ((t - 0.58) / 0.10).clamp(0.0, 1.0);
        return Opacity(
          opacity: _loopFade(t),
          child: Stack(
            children: [
              if (chatOpacity > 0)
                Opacity(opacity: chatOpacity, child: _chatLayer(t)),
              if (mapOpacity > 0)
                Opacity(opacity: mapOpacity, child: _mapLayer(t)),
            ],
          ),
        );
      },
    );
  }

  Widget _chatLayer(double t) {
    // Share sheet rises between 0.28 and 0.52.
    final sheetT = ((t - 0.28) / 0.16).clamp(0.0, 1.0);
    final sheetOffset = (1 - Curves.easeOutCubic.transform(sheetT)) * 220;
    return Container(
      color: const Color(0xFF0B141A),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Slim chat app bar.
              Container(
                padding: const EdgeInsets.fromLTRB(12, 38, 12, 10),
                color: const Color(0xFF1F2C34),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xFF3B4A54),
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ali',
                      style: AppTextStyles.titleSm.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Received location card.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _locationBubble(),
                ),
              ),
              const SizedBox(height: 8),
              // Sent reply bubble.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005C4B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.done_all,
                      size: 15,
                      color: Color(0xFF53BDEB),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // The "Open with" share sheet.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Transform.translate(
              offset: Offset(0, sheetOffset),
              child: _openWithSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationBubble() {
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
            child: SizedBox(
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
                  const _MockPin(color: AppColors.pinRed, size: 26),
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

  Widget _openWithSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF233138),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Open with',
            style: AppTextStyles.titleSm.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _appTile(
                highlighted: false,
                label: 'Maps',
                child: const Icon(
                  Icons.map_rounded,
                  color: Color(0xFF34A853),
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              _appTile(
                highlighted: true,
                label: 'laffeh',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/laffeh_logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appTile({
    required bool highlighted,
    required String label,
    required Widget child,
  }) {
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
          Text(
            label,
            style: AppTextStyles.mutedSm.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _mapLayer(double t) {
    // The shared point drops in once we land on the map.
    final dropT = ((t - 0.62) / 0.16).clamp(0.0, 1.0);
    final e = Curves.elasticOut.transform(dropT);
    final dy = -34 * (1 - e);
    final toastT = ((t - 0.74) / 0.10).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
            Positioned(
              left: c.maxWidth / 2 - 17,
              top: c.maxHeight * 0.5 - 34 + dy,
              child: Opacity(
                opacity: (dropT * 3).clamp(0.0, 1.0),
                child: const _MockPin(color: AppColors.primary, size: 34),
              ),
            ),
            if (toastT > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: Opacity(
                    opacity: toastT,
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Location demo
// ─────────────────────────────────────────────────────────────────────

class OnbLocationDemo extends StatefulWidget {
  const OnbLocationDemo({super.key});

  @override
  State<OnbLocationDemo> createState() => _OnbLocationDemoState();
}

class _OnbLocationDemoState extends State<OnbLocationDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              return SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding accuracy ring.
                    Container(
                      width: 30 + v * 80,
                      height: 30 + v * 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.info.withValues(
                          alpha: (0.22 * (1 - v)).clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                    // The blue "you" dot.
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.info,
                        border: Border.all(color: AppColors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.info.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Welcome logo (gentle breath)
// ─────────────────────────────────────────────────────────────────────

class OnbWelcomeArt extends StatefulWidget {
  const OnbWelcomeArt({super.key});

  @override
  State<OnbWelcomeArt> createState() => _OnbWelcomeArtState();
}

class _OnbWelcomeArtState extends State<OnbWelcomeArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final breath = 1.0 + 0.014 * math.sin(_c.value * 2 * math.pi);
        return Transform.scale(scale: breath, child: child);
      },
      child: const _WelcomeLogoCard(),
    );
  }
}

class _WelcomeLogoCard extends StatelessWidget {
  const _WelcomeLogoCard();

  static const double _logoAspectRatio = 1195 / 896;
  static const double _maxWidth = 286;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _maxWidth;
        final heightBoundWidth = constraints.maxHeight.isFinite
            ? constraints.maxHeight * _logoAspectRatio
            : _maxWidth;
        final width = math.min(_maxWidth, math.min(maxWidth, heightBoundWidth));

        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: _logoAspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEAF6E4)],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.86),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 34,
                    spreadRadius: -10,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: AppColors.asphalt.withValues(alpha: 0.08),
                    blurRadius: 18,
                    spreadRadius: -12,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/laffeh_logo.png',
                        fit: BoxFit.cover,
                        alignment: const Alignment(-0.04, -0.02),
                        filterQuality: FilterQuality.high,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.white.withValues(alpha: 0.12),
                              AppColors.white.withValues(alpha: 0.00),
                              AppColors.asphalt.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
