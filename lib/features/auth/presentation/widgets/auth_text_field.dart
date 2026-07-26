import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'auth_field_shell.dart';

/// Plain text input wearing the same chrome as [PhoneField] and
/// [PasswordField], so every field across the auth flow matches.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
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
    final multiline = widget.maxLines > 1;
    return AuthFieldShell(
      label: widget.label,
      errorText: widget.errorText,
      focused: _focus.hasFocus,
      height: multiline ? 56 + 22.0 * (widget.maxLines - 1) : 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (widget.prefixIcon != null) ...[
              Padding(
                padding: EdgeInsets.only(top: multiline ? 16 : 0),
                child: Icon(
                  widget.prefixIcon,
                  size: 20,
                  color: _focus.hasFocus
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: multiline
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _field(multiline: true),
                    )
                  : _field(multiline: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required bool multiline}) => TextField(
    controller: widget.controller,
    focusNode: _focus,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    textCapitalization: widget.textCapitalization,
    maxLines: widget.maxLines,
    minLines: multiline ? widget.maxLines : 1,
    style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
    onChanged: widget.onChanged,
    onSubmitted: (_) => widget.onSubmitted?.call(),
    decoration: authInnerDecoration(hint: widget.hint),
  );
}
