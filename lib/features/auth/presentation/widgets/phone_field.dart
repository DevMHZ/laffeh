import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../domain/country.dart';
import 'auth_field_shell.dart';

/// Phone input: a compact country-code selector fused into the same field as
/// the national number, separated by a hairline.
///
/// The inner row is forced LTR so the country code always sits on the *left*
/// and the digits read left-to-right, even when the app is in Arabic — a phone
/// number is a Latin-numeral sequence, not prose. The label and error line
/// still follow the app's direction.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.country,
    required this.controller,
    required this.onCountryChanged,
    this.label,
    this.hint,
    this.errorText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final Country country;
  final TextEditingController controller;
  final ValueChanged<Country> onCountryChanged;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late final FocusNode _focus = FocusNode()..addListener(_rebuild);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant PhoneField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (old.country.iso != widget.country.iso) _reformatForCountry();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// A new country brings a new mask and digit cap — re-run the current text
  /// through them so what's shown is exactly what gets validated.
  void _reformatForCountry() {
    final digits = PhoneUtils.digitsOnly(widget.controller.text);
    final capped = digits.length > widget.country.maxNationalDigits
        ? digits.substring(0, widget.country.maxNationalDigits)
        : digits;
    final text = widget.country.formatNational(capped);
    if (text == widget.controller.text) return;

    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // The parent must hold the same value it will validate, but we're inside a
    // rebuild here — defer the notification by a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged?.call(text);
    });
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context, widget.country);
    if (picked != null) widget.onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final complete =
        widget.errorText == null &&
        widget.country.isValidNational(widget.controller.text, strict: false);

    return AuthFieldShell(
      label: widget.label,
      errorText: widget.errorText,
      focused: _focus.hasFocus,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _CountryButton(country: widget.country, onTap: _pickCountry),
            Container(width: 1, height: 26, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.phone,
                  textInputAction: widget.textInputAction,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: [_NationalNumberFormatter(widget.country)],
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  decoration: authInnerDecoration(
                    hint: widget.hint ?? widget.country.example,
                  ),
                ),
              ),
            ),
            // Quiet confirmation that the number is now a complete one.
            AnimatedScale(
              scale: complete ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live input mask for the national number: digits only, no trunk `0`, grouped
/// the way [Country.example] is grouped, and capped at the country's longest
/// mobile number. A jump of more than one digit is treated as a paste and run
/// through [Country.normalizeNational], so pasting `+963 944 123 456` or
/// `00963944123456` lands as `944 123 456`.
class _NationalNumberFormatter extends TextInputFormatter {
  _NationalNumberFormatter(this.country);

  final Country country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final oldDigits = PhoneUtils.digitsOnly(old.text);
    var digits = PhoneUtils.digitsOnly(next.text);

    digits = digits.length > oldDigits.length + 1
        ? country.normalizeNational(digits)
        : digits.replaceFirst(RegExp('^0+'), '');

    if (digits.length > country.maxNationalDigits) {
      digits = digits.substring(0, country.maxNationalDigits);
    }

    final text = country.formatNational(digits);
    final caret = next.selection.end < 0
        ? next.text.length
        : next.selection.end.clamp(0, next.text.length);
    final typedBeforeCaret = PhoneUtils.digitsOnly(
      next.text.substring(0, caret),
    ).length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: _offsetAfterDigits(text, typedBeforeCaret),
      ),
    );
  }

  /// Where the caret sits once [count] digits of [text] have gone by.
  int _offsetAfterDigits(String text, int count) {
    if (count <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit >= 0x30 && unit <= 0x39 && ++seen == count) return i + 1;
    }
    return text.length;
  }
}

/// The leading segment of [PhoneField]: flag, dial code, chevron. Deliberately
/// narrow — it is a qualifier for the number, not a peer field.
class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onTap});

  final Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 7),
              Text(
                country.dialCode,
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodyMd.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a searchable bottom sheet for choosing a country.
Future<Country?> showCountryPicker(BuildContext context, Country current) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CountryPickerSheet(current: current),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.current});

  final Country current;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = Country.all
        .where((c) => c.matches(_query))
        .toList(growable: false);
    final lang = AppStrings.languageCode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: AppTextStyles.bodyMd,
                decoration: InputDecoration(
                  hintText: AppStrings.countrySearchHint,
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (_, i) {
                  final c = results[i];
                  final selected = c.iso == widget.current.iso;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      c.localizedName(lang),
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                    trailing: Text(
                      c.dialCode,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor: AppColors.primarySoft,
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
