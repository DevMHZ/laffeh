import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/whatsapp_glyph.dart';

/// Explicit delivery outcomes. Both advance the trip; contacting the customer
/// is a separate action and never completes a stop.
class StopArrivalActions extends StatelessWidget {
  final String deliveredLabel;
  final String nextLabel;
  final VoidCallback onDelivered;
  final VoidCallback? onUnableToDeliver;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;

  const StopArrivalActions({
    super.key,
    required this.deliveredLabel,
    required this.nextLabel,
    required this.onDelivered,
    this.onUnableToDeliver,
    this.onCall,
    this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onCall != null || onWhatsapp != null) ...[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (onCall != null)
                    TextButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Iconsax.call, size: 22),
                      label: Text(AppStrings.stopCall),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(88, 48),
                      ),
                    ),
                  if (onWhatsapp != null)
                    TextButton.icon(
                      onPressed: onWhatsapp,
                      icon: WhatsappGlyph(size: 22, color: AppColors.primary),
                      label: Text(AppStrings.stopWhatsapp),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(88, 48),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _OutcomeButton(
                  key: const ValueKey('arrival-delivered'),
                  label: deliveredLabel,
                  nextLabel: nextLabel,
                  icon: Iconsax.tick_circle,
                  primary: true,
                  onTap: onDelivered,
                ),
              ),
              if (onUnableToDeliver != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _OutcomeButton(
                    key: const ValueKey('arrival-unable'),
                    label: AppStrings.couldNotDeliver,
                    nextLabel: nextLabel,
                    icon: Iconsax.close_circle,
                    primary: false,
                    onTap: onUnableToDeliver!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  final String label;
  final String nextLabel;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _OutcomeButton({
    super.key,
    required this.label,
    required this.nextLabel,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.danger;
    return Semantics(
      button: true,
      label: '$label. $nextLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: primary ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: primary
              ? BorderSide.none
              : BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primary
                          ? Colors.white.withValues(alpha: .88)
                          : AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
