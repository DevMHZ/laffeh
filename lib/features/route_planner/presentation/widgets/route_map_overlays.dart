import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/vehicle_prefs.dart';

/// Screen-centred playback car for follow/chase modes. A plain Flutter
/// widget (not a map symbol) so it stays glued to the centre while the
/// camera glides under it — no platform-channel lag.
class SimPuck extends StatelessWidget {
  final double rotation; // degrees clockwise from up
  const SimPuck({super.key, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * math.pi / 180.0,
      child: SizedBox(
        width: 44,
        height: 44,
        child: CustomPaint(painter: VehiclePrefs.current.painter()),
      ),
    );
  }
}

/// Fixed on-screen vehicle for live driving.
///
/// The camera rotates the map underneath it, so on a straight road the car
/// points straight up — but the camera's bearing *anticipates* the road
/// ahead of the vehicle, so mid-bend the two diverge. [rotationDegrees]
/// carries that difference (road tangent under the car minus the live
/// camera bearing) so the avatar always lies along the road it is actually
/// on instead of appearing to drift sideways into the turn.
class NavigationPuck extends StatelessWidget {
  /// Clockwise degrees from screen-up; 0 on a straight road.
  final double rotationDegrees;

  const NavigationPuck({super.key, this.rotationDegrees = 0});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * math.pi / 180.0,
      child: const SizedBox(
        width: 54,
        height: 54,
        child: CustomPaint(painter: _NavigationPuckPainter()),
      ),
    );
  }
}

class _NavigationPuckPainter extends CustomPainter {
  const _NavigationPuckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      26,
      Paint()..color = AppColors.primary.withValues(alpha: 0.10),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 6), width: 34, height: 38),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    VehiclePrefs.current.painter().paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small circular "return to my location" FAB shown on the map once the
/// user pans away from their current position. Icon-only (with a tooltip)
/// so it stays out of the way until needed.
class LocateFab extends StatelessWidget {
  final VoidCallback onTap;
  const LocateFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.yourLocation,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: AppColors.shadow,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(Iconsax.gps, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Pill button used for "reset view" / recenter actions on the map.
class RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  const RecenterButton({
    super.key,
    required this.onTap,
    this.icon = Iconsax.gps,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.titleSm.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
