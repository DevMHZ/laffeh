import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

part 'onboarding_mock_shared.dart';
part 'onboarding_mock_demos.dart';

/// Animated mock visuals for the onboarding slides.
///
/// Everything here is rebuilt from app widgets, colours and painters —
/// deliberately *not* screenshots — so it stays crisp at any size, picks
/// up the brand theme, and reads correctly in en / ar / fr. Each demo
/// owns one repeating controller and tells a tiny looping story.

// ─────────────────────────────────────────────────────────────────────
// Phone frame
// ─────────────────────────────────────────────────────────────────────

/// A stylised handset that gently floats, wrapping a mock "screen".
class OnbPhoneFrame extends StatefulWidget {
  final Widget child;
  final double width;

  const OnbPhoneFrame({super.key, required this.child, this.width = 210});

  @override
  State<OnbPhoneFrame> createState() => _OnbPhoneFrameState();
}

class _OnbPhoneFrameState extends State<OnbPhoneFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * 2.04;
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(_float.value); // 0..1
        return Transform.translate(
          offset: Offset(0, -6 + v * 12),
          child: Transform.rotate(angle: (-0.012 + v * 0.024), child: child),
        );
      },
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.asphaltDark,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.asphaltDark.withValues(alpha: 0.32),
              blurRadius: 34,
              spreadRadius: -6,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        padding: const EdgeInsets.all(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              // Dynamic-island style pill.
              Positioned(
                top: 9,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: w * 0.32,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.asphaltDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
