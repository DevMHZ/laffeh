import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_config.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opens a published legal document in the browser, in the app's current
/// language. Shows a snackbar if no browser can handle it.
Future<void> openLegalDoc(BuildContext context, LegalDoc doc) {
  // Resolved before the first await so this stays safe even when the caller's
  // context goes away (e.g. a sheet closing on tap).
  return _launchLegal(doc, ScaffoldMessenger.maybeOf(context));
}

Future<void> _launchLegal(
  LegalDoc doc,
  ScaffoldMessengerState? messenger,
) async {
  final uri = LegalConfig.uriFor(doc);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger?.showSnackBar(
      SnackBar(content: Text(AppStrings.websiteOpenFailed(uri.toString()))),
    );
  }
}

/// Lists the published policies (privacy, terms, account deletion) so they stay
/// reachable from anywhere — required for the store listing, and the honest
/// place to send someone who taps "Terms & Privacy".
Future<void> showLegalLinksSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _LegalLinksSheet(),
  );
}

class _LegalLinksSheet extends StatelessWidget {
  const _LegalLinksSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppStrings.legalTitle, style: AppTextStyles.titleMd),
            const SizedBox(height: 8),
            const _LegalRow(
              icon: Icons.privacy_tip_outlined,
              doc: LegalDoc.privacy,
            ),
            const _LegalRow(
              icon: Icons.description_outlined,
              doc: LegalDoc.terms,
            ),
            const _LegalRow(
              icon: Icons.person_remove_outlined,
              doc: LegalDoc.accountDeletion,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({required this.icon, required this.doc});

  final IconData icon;
  final LegalDoc doc;

  String get _label => switch (doc) {
    LegalDoc.privacy => AppStrings.legalPrivacy,
    LegalDoc.terms => AppStrings.legalTerms,
    LegalDoc.accountDeletion => AppStrings.legalAccountDeletion,
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(_label, style: AppTextStyles.bodyMd),
      trailing: Icon(Icons.open_in_new, size: 18, color: AppColors.textMuted),
      onTap: () {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop();
        _launchLegal(doc, messenger);
      },
    );
  }
}
