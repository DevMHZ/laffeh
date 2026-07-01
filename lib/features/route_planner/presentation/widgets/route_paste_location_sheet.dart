import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/google_glyph.dart';
import '../cubit/route_planner_cubit.dart';

/// Paste a Google (or Apple) Maps link — short (`maps.app.goo.gl`) or full —
/// and drop a pin at the location it points to. Reuses the same
/// link-resolving pipeline as the WhatsApp import, so short links are
/// expanded via their redirect before parsing.
Future<void> showPasteLocationSheet(
  BuildContext context,
  RoutePlannerCubit cubit,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _PasteLocationBody(cubit: cubit),
    ),
  );
}

class _PasteLocationBody extends StatefulWidget {
  final RoutePlannerCubit cubit;
  const _PasteLocationBody({required this.cubit});

  @override
  State<_PasteLocationBody> createState() => _PasteLocationBodyState();
}

class _PasteLocationBodyState extends State<_PasteLocationBody> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_error != null) setState(() => _error = null);
    // Rebuild so the "Add point" button enables/disables as the field
    // goes from empty to non-empty (and vice versa).
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _loading = true;
      _error = null;
    });
    final added = await widget.cubit.addPointsFromText(text);
    if (!mounted) return;
    if (added > 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _loading = false;
      _error = AppStrings.pasteLocationInvalid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.pasteLocationTitle, style: AppTextStyles.h3),
            const SizedBox(height: 6),
            Text(
              AppStrings.pasteLocationSub,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: AppTextStyles.bodyLg,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(14),
                  child: GoogleGlyph(size: 18),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Iconsax.clipboard_text, size: 20),
                  tooltip: AppStrings.pasteFromClipboard,
                  onPressed: _pasteFromClipboard,
                ),
                hintText: AppStrings.pasteLocationPlaceholder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.mutedSm.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: AppStrings.pasteLocationAdd,
              loading: _loading,
              onPressed: _controller.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
