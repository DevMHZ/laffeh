import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'auth_field_shell.dart';

/// Password input with a show/hide toggle, sharing the auth field chrome.
/// Never logs or persists its value.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthFieldShell(
      label: widget.label,
      errorText: widget.errorText,
      focused: _focus.hasFocus,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: _focus.hasFocus ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                obscureText: _obscured,
                obscuringCharacter: '•',
                keyboardType: TextInputType.visiblePassword,
                textInputAction: widget.textInputAction,
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                onChanged: widget.onChanged,
                onSubmitted: (_) => widget.onSubmitted?.call(),
                decoration: authInnerDecoration(hint: widget.hint),
              ),
            ),
            IconButton(
              tooltip: _obscured
                  ? AppStrings.passwordShow
                  : AppStrings.passwordHide,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ],
        ),
      ),
    );
  }
}
