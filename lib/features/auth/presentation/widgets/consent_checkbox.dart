import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/legal_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/legal_links_sheet.dart';

/// The sign-up consent gate: a required checkbox whose label carries tappable
/// links to the published Terms and Privacy Policy.
///
/// The sentence comes from a localized template with `{terms}` / `{privacy}`
/// placeholders so each language keeps its own word order (and RTL works
/// without any special casing).
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final invalid = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                    activeColor: AppColors.primary,
                    side: invalid
                        ? BorderSide(color: AppColors.danger, width: 1.6)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: _ConsentText(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (invalid)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, start: 4),
            child: Text(
              errorText!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Stateful purely so the two tap recognizers can be disposed — building them
/// inside `build()` would leak one pair per rebuild.
class _ConsentText extends StatefulWidget {
  const _ConsentText();

  @override
  State<_ConsentText> createState() => _ConsentTextState();
}

class _ConsentTextState extends State<_ConsentText> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => openLegalDoc(context, LegalDoc.terms);
    _privacy = TapGestureRecognizer()
      ..onTap = () => openLegalDoc(context, LegalDoc.privacy);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary);
    final link = base.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: _spans(base: base, link: link),
      ),
    );
  }

  /// Splits the localized template on its placeholders and turns each one into
  /// a tappable link, leaving the surrounding text as-is.
  List<InlineSpan> _spans({required TextStyle base, required TextStyle link}) {
    final template = AppStrings.consentTemplate;
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\{(terms|privacy)\}');
    var index = 0;

    for (final match in pattern.allMatches(template)) {
      if (match.start > index) {
        spans.add(TextSpan(text: template.substring(index, match.start)));
      }
      final isTerms = match.group(1) == 'terms';
      spans.add(
        TextSpan(
          text: isTerms ? AppStrings.legalTerms : AppStrings.legalPrivacy,
          style: link,
          recognizer: isTerms ? _terms : _privacy,
        ),
      );
      index = match.end;
    }
    if (index < template.length) {
      spans.add(TextSpan(text: template.substring(index)));
    }
    return spans;
  }
}
