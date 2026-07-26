import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/data/error/auth_error_mapper.dart';
import '../../../auth/presentation/auth_messages.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/pages/sign_in_page.dart';

/// Account block in Settings: who is signed in, plus sign-out and the
/// permanent account-deletion path Google Play requires of any app that lets
/// users create an account.
///
/// Login is optional in this app, so this renders in two shapes: a sign-in
/// prompt for guests, and the sign-out / delete pair for signed-in users.
class AccountSection extends StatefulWidget {
  const AccountSection({super.key});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  /// Guards against a second tap while a sign-out / delete round-trip is in
  /// flight — both close the session, so a double fire would race.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(user?.phone),
            const SizedBox(height: 12),
            if (user == null)
              _ActionRow(
                icon: Iconsax.login,
                label: AppStrings.signInButton,
                trailing: AppStrings.accountGuestHint,
                onTap: _busy ? null : _openSignIn,
              )
            else ...[
              _ActionRow(
                icon: Iconsax.logout,
                label: AppStrings.signOut,
                onTap: _busy ? null : _confirmSignOut,
              ),
              const SizedBox(height: 4),
              _ActionRow(
                icon: Iconsax.trash,
                label: AppStrings.deleteAccount,
                danger: true,
                onTap: _busy ? null : _confirmDelete,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _header(String? phone) {
    final signedIn = phone != null;
    return Row(
      children: [
        Icon(Iconsax.user, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(AppStrings.account, style: AppTextStyles.titleMd)),
        if (_busy)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
        else
          Text(
            // The phone number is the account identity here (no email, no
            // username), so it doubles as the "signed in as" label.
            signedIn ? phone : AppStrings.accountGuest,
            style: AppTextStyles.mutedSm.copyWith(color: AppColors.textMuted),
            textDirection: signedIn ? TextDirection.ltr : null,
          ),
      ],
    );
  }

  Future<void> _openSignIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignInPage()),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppStrings.signOutConfirmTitle,
          style: AppTextStyles.titleMd,
        ),
        content: Text(
          AppStrings.signOutConfirmBody,
          style: AppTextStyles.mutedSm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppStrings.signOut,
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await context.read<AuthCubit>().signOut();
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) => _toast(AppStrings.signOutDone),
      failure: (f) => _toast(AuthMessages.authError(_codeOf(f))),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      // Deliberately not dismissible by tapping outside: this is destructive
      // and irreversible, so leaving should be an explicit choice.
      barrierDismissible: false,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await context.read<AuthCubit>().deleteAccount();
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) {
        _toast(AppStrings.deleteAccountDone);
        // Drop back to the planner. It works fine signed out, and the account
        // this Settings page was describing no longer exists.
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      failure: (f) => _toast(AuthMessages.authError(_codeOf(f))),
    );
  }

  String _codeOf(Failure failure) =>
      failure is AuthFailure ? failure.code : AuthErrorMapper.unknown;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Confirmation for the destructive path. Spells out exactly what is erased —
/// Play's deletion policy expects the disclosure, and it is the only warning
/// the user gets — and gates the button behind an explicit acknowledgement so
/// the action cannot be completed by muscle memory.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Iconsax.warning_2, size: 20, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.deleteAccountTitle,
              style: AppTextStyles.titleMd,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.deleteAccountBody, style: AppTextStyles.mutedSm),
            const SizedBox(height: 10),
            _bullet(AppStrings.deleteAccountItemLogin),
            _bullet(AppStrings.deleteAccountItemProfile),
            _bullet(AppStrings.deleteAccountItemLocation),
            const SizedBox(height: 12),
            Text(
              AppStrings.deleteAccountIrreversible,
              style: AppTextStyles.mutedSm.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 6),
            // Tapping the label toggles too — a bare 18px checkbox is a poor
            // target, and this row is the gate on the whole action.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _acknowledged = !_acknowledged),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acknowledged,
                        activeColor: AppColors.danger,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) =>
                            setState(() => _acknowledged = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.deleteAccountAck,
                        style: AppTextStyles.mutedSm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: _acknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(
            AppStrings.deleteAccountConfirm,
            style: TextStyle(
              color: _acknowledged ? AppColors.danger : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.mutedSm.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One tappable row, styled to match the collapsible headers in Settings so
/// the account block reads as part of the same list.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool danger;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.danger : AppColors.primary;
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.titleSm.copyWith(
                      color: danger ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing!,
                    style: AppTextStyles.mutedSm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
