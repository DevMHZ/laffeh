part of 'onboarding_mock.dart';

// ─────────────────────────────────────────────────────────────────────
// Import demo — iPhone
// ─────────────────────────────────────────────────────────────────────

/// The iPhone route for a location shared over WhatsApp.
///
/// On Android, WhatsApp's own "Open with" sheet lists Laffeh and the point
/// lands in one tap. iOS has no such list: WhatsApp hands a tapped location
/// to a map app, and that map app's share button is the only door a third
/// party can come through. So the trip is one screen longer, and pretending
/// otherwise — showing an iPhone driver the Android sheet — leaves them
/// hunting for a "Laffeh" entry that does not exist on their phone.
///
/// Four beats, looping: the chat, the map the tap opens, the iOS share sheet
/// with Laffeh in it, and the point landing on the route.
class OnbWhatsappDemoIos extends StatefulWidget {
  const OnbWhatsappDemoIos({super.key});

  @override
  State<OnbWhatsappDemoIos> createState() => _OnbWhatsappDemoIosState();
}

class _OnbWhatsappDemoIosState extends State<OnbWhatsappDemoIos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Longer than the Android loop: there is one more screen to read, and
    // rushing the extra step is what makes a walkthrough unreadable.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8600),
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
        // chat 0.00–0.30 · maps 0.28–0.70 · laffeh 0.68–1.00
        final chat = (1 - ((t - 0.26) / 0.06)).clamp(0.0, 1.0);
        final maps =
            ((t - 0.28) / 0.06).clamp(0.0, 1.0) *
            (1 - ((t - 0.68) / 0.06)).clamp(0.0, 1.0);
        final laffeh = ((t - 0.70) / 0.06).clamp(0.0, 1.0);
        return Opacity(
          opacity: _loopFade(t),
          child: Stack(
            children: [
              if (chat > 0) Opacity(opacity: chat, child: _chatLayer(t)),
              if (maps > 0) Opacity(opacity: maps, child: _mapsLayer(t)),
              if (laffeh > 0) Opacity(opacity: laffeh, child: _laffehLayer(t)),
              _StepBadge(step: _stepFor(t)),
            ],
          ),
        );
      },
    );
  }

  int _stepFor(double t) {
    if (t < 0.28) return 1;
    if (t < 0.52) return 2;
    if (t < 0.70) return 3;
    return 4;
  }

  // ── 1. WhatsApp: the driver taps the location ──
  Widget _chatLayer(double t) {
    final tap = ((t - 0.13) / 0.12).clamp(0.0, 1.0);
    return Container(
      color: const Color(0xFF0B141A),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _WaLocationBubble(),
                ),
              ),
            ],
          ),
          // The tap lands on the middle of the location card.
          PositionedDirectional(
            start: 65,
            top: 114,
            child: _TapPulse(t: tap, size: 44),
          ),
        ],
      ),
    );
  }

  // ── 2 & 3. Maps opens; its share button reveals the iOS sheet ──
  Widget _mapsLayer(double t) {
    final tap = ((t - 0.38) / 0.10).clamp(0.0, 1.0);
    final sheetT = ((t - 0.50) / 0.12).clamp(0.0, 1.0);
    final sheetOffset = (1 - Curves.easeOutCubic.transform(sheetT)) * 260;
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MapBackdrop())),
        // A map app's chrome, kept generic — the point is the share button,
        // not which map app the driver happens to have.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 34, 12, 10),
            color: AppColors.white.withValues(alpha: 0.92),
            child: Row(
              children: [
                Icon(Icons.map_rounded, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Maps',
                  style: AppTextStyles.mutedSm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.12),
          child: _MockPin(color: AppColors.pinRed, size: 30),
        ),
        // The place card, with the share button the whole beat is about.
        Positioned(
          left: 10,
          right: 10,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.ios_share_rounded,
                        size: 18,
                        color: AppColors.info,
                      ),
                    ),
                    _TapPulse(t: tap, size: 40, color: AppColors.info),
                  ],
                ),
              ],
            ),
          ),
        ),
        // The iOS share sheet, with Laffeh among the apps.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Transform.translate(
            offset: Offset(0, sheetOffset),
            child: _iosShareSheet(),
          ),
        ),
      ],
    );
  }

  Widget _iosShareSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ShareAppTile(
                highlighted: false,
                label: 'Messages',
                labelColor: AppColors.textSecondary,
                child: Icon(
                  Icons.chat_bubble_rounded,
                  size: 24,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              _ShareAppTile(
                highlighted: true,
                label: 'laffeh',
                labelColor: AppColors.textPrimary,
                child: const _LaffehTileIcon(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Laffeh: the point lands ──
  Widget _laffehLayer(double t) {
    final dropT = ((t - 0.74) / 0.14).clamp(0.0, 1.0);
    final e = Curves.elasticOut.transform(dropT);
    final dy = -34 * (1 - e);
    final toastT = ((t - 0.85) / 0.09).clamp(0.0, 1.0);
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
                child: _MockPin(color: AppColors.primary, size: 34),
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

/// "1 / 4", pinned to the corner of the demo.
///
/// The extra hop is the whole reason this demo exists, and a driver watching
/// a loop needs to know they are seeing four screens rather than missing a
/// step somewhere.
class _StepBadge extends StatelessWidget {
  final int step;
  const _StepBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    // Directional, not absolute: the mock's own app bar puts its title at the
    // start, so a badge pinned to the physical right lands on top of it the
    // moment the app is read right-to-left.
    return PositionedDirectional(
      top: 38,
      end: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.asphaltDark.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
        ),
        // Latin digits regardless of language: this is a step counter on a
        // mock screen, not app copy.
        child: Text(
          '$step / 4',
          textDirection: TextDirection.ltr,
          style: AppTextStyles.mutedSm.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
