import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/use_case_option.dart';

/// Large selectable cards for the "why do you use the app" step. Multi-select,
/// with an animated check, a subtle press-scale and light haptics.
class UseCaseChips extends StatelessWidget {
  const UseCaseChips({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in UseCaseOption.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _UseCaseCard(
              option: option,
              selected: selected.contains(option.code),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(option.code);
              },
            ),
          ),
      ],
    );
  }
}

class _UseCaseCard extends StatefulWidget {
  const _UseCaseCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final UseCaseOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_UseCaseCard> createState() => _UseCaseCardState();
}

class _UseCaseCardState extends State<_UseCaseCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.option.icon,
                size: 24,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.option.label(),
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: selected
                    ? Icon(
                        Icons.check_circle,
                        key: const ValueKey('checked'),
                        color: AppColors.primary,
                        size: 24,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey('unchecked'),
                        color: AppColors.border,
                        size: 24,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
