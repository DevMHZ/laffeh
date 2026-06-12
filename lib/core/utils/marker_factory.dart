import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class MarkerFactory {
  MarkerFactory._();

  static Widget depot({String? tooltip}) => _MarkerTooltip(
    message: tooltip,
    child: _DotMarker(
      color: AppColors.primary,
      child: const Icon(Icons.flag_rounded, color: AppColors.white, size: 12),
    ),
  );

  static Widget stop(int index, {String? tooltip}) => _MarkerTooltip(
    message: tooltip,
    child: _DotMarker(
      color: AppColors.accent,
      child: Text(
        '$index',
        style: const TextStyle(
          fontFamily: 'Almarai',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: AppColors.white,
          height: 1.0,
        ),
      ),
    ),
  );

  static Widget vehicle({required double bearing}) => _MarkerTooltip(
    message: AppStrings.vehicle,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Transform.rotate(
        angle: bearing * math.pi / 180,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: AppColors.white,
            size: 15,
          ),
        ),
      ),
    ),
  );

  static Widget navigationVehicle({required double bearing}) => _MarkerTooltip(
    message: AppStrings.vehicle,
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Transform.rotate(
        angle: bearing * math.pi / 180,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: AppColors.white,
            size: 17,
          ),
        ),
      ),
    ),
  );

  static Widget userLocation({String? tooltip}) => _MarkerTooltip(
    message: tooltip,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
        ),
      ),
    ),
  );
}

class _DotMarker extends StatelessWidget {
  final Color color;
  final Widget child;

  const _DotMarker({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MarkerTooltip extends StatelessWidget {
  final String? message;
  final Widget child;

  const _MarkerTooltip({required this.message, required this.child});

  @override
  Widget build(BuildContext context) {
    final text = message?.trim();
    if (text == null || text.isEmpty) return child;
    return Tooltip(message: text, child: child);
  }
}
