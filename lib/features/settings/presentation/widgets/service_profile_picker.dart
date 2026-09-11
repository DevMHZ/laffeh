import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/service_profile.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'service_profile_glyph.dart';

String serviceProfileName(ServiceProfile profile) => switch (profile) {
  ServiceProfile.delivery => AppStrings.serviceProfileDelivery,
  ServiceProfile.pickup => AppStrings.serviceProfilePickup,
  ServiceProfile.none => AppStrings.serviceProfileNone,
};

String serviceProfileHint(ServiceProfile profile) => switch (profile) {
  ServiceProfile.delivery => AppStrings.serviceProfileDeliveryHint,
  ServiceProfile.pickup => AppStrings.serviceProfilePickupHint,
  ServiceProfile.none => AppStrings.serviceProfileNoneHint,
};

/// Readable, mutually exclusive load preferences. Copy describes a planning
/// preference, not a guarantee that a particular stop will be first or last.
class ServiceProfilePicker extends StatelessWidget {
  final ServiceProfile value;
  final ValueChanged<ServiceProfile> onChanged;

  const ServiceProfilePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.serviceProfileIntro,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        for (final profile in ServiceProfile.values)
          _ProfileChoice(
            profile: profile,
            selected: profile == value,
            onTap: () => onChanged(profile),
          ),
      ],
    );
  }
}

class _ProfileChoice extends StatelessWidget {
  final ServiceProfile profile;
  final bool selected;
  final VoidCallback onTap;
  const _ProfileChoice({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = serviceProfileName(profile);
    final hint = serviceProfileHint(profile);
    void choose() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        key: ValueKey('profile-${profile.name}'),
        label: title,
        value: hint,
        checked: selected,
        inMutuallyExclusiveGroup: true,
        onTap: choose,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: choose,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.borderStrong,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ServiceProfileGlyph(
                        profile: profile,
                        size: 44,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        animate:
                            selected &&
                            !MediaQuery.disableAnimationsOf(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(title, style: AppTextStyles.titleMd),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 22,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
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
