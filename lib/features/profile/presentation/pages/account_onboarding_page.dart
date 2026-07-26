import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/auth_messages.dart';
import '../../../auth/presentation/pages/sign_in_page.dart';
import '../../../auth/presentation/widgets/auth_error_banner.dart';
import '../../../auth/presentation/widgets/auth_field_shell.dart';
import '../../../auth/presentation/widgets/auth_header.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../../auth/presentation/widgets/password_field.dart';
import '../../../auth/presentation/widgets/phone_field.dart';
import '../../../route_planner/presentation/pages/route_planner_page.dart';
import '../../domain/entities/use_case_option.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/account_onboarding_cubit.dart';
import '../widgets/use_case_chips.dart';

/// Multi-step "create account" flow. When [credentialsDone] is true it resumes
/// a user whose account exists but whose profile is incomplete (starts at
/// [startStep], skipping the credentials step).
class AccountOnboardingPage extends StatelessWidget {
  const AccountOnboardingPage({
    super.key,
    this.startStep = 0,
    this.credentialsDone = false,
  });

  final int startStep;
  final bool credentialsDone;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountOnboardingCubit>(
      create: (_) => AccountOnboardingCubit(
        sl<AuthRepository>(),
        sl<ProfileRepository>(),
        startStep: startStep,
        credentialsDone: credentialsDone,
      ),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _fullName = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _other = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _fullName.dispose();
    _company.dispose();
    _phone.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _onSuccess() async {
    final prefs = sl<SharedPreferences>();
    await prefs.setBool(AppStrings.welcomeSeenKey, true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoutePlannerPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountOnboardingCubit, AccountOnboardingState>(
      listenWhen: (prev, curr) => prev.phase != curr.phase,
      listener: (context, state) {
        if (state.phase == OnbPhase.success) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            barrierColor: AppColors.background.withValues(alpha: 0.92),
            builder: (_) => const _SuccessOverlay(),
          );
          Future.delayed(const Duration(milliseconds: 1300), _onSuccess);
        }
      },
      builder: (context, state) {
        final cubit = context.read<AccountOnboardingCubit>();
        return PopScope(
          canPop: state.step == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && state.step > 0) cubit.back();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (state.step == 0) {
                    Navigator.of(context).maybePop();
                  } else {
                    cubit.back();
                  }
                },
              ),
              title: Text(AppStrings.createAccountTitle),
            ),
            body: SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
                  children: [
                    _Progress(step: state.step),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _buildStep(context, state, cubit),
                      ),
                    ),
                    _BottomBar(state: state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep(
    BuildContext context,
    AccountOnboardingState state,
    AccountOnboardingCubit cubit,
  ) {
    return switch (state.step) {
      0 => _CredentialsStep(
        key: const ValueKey(0),
        state: state,
        cubit: cubit,
        phone: _phone,
        password: _password,
        confirm: _confirm,
      ),
      1 => _NameCompanyStep(
        key: const ValueKey(1),
        state: state,
        cubit: cubit,
        fullName: _fullName,
        company: _company,
      ),
      2 => _UseCasesStep(
        key: const ValueKey(2),
        state: state,
        cubit: cubit,
        other: _other,
      ),
      _ => _SummaryStep(key: const ValueKey(3), state: state, cubit: cubit),
    };
  }
}

// ── Progress ────────────────────────────────────────────
/// One segment per step plus a "Step n of m" counter, so the flow reads as a
/// finite list of steps rather than an open-ended bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  static const int _total = AccountOnboardingState.lastStep + 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < _total; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppColors.primary
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.stepCounter(step + 1, _total),
            style: AppTextStyles.mutedSm,
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ───────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state});
  final AccountOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountOnboardingCubit>();
    final isLast = state.step == AccountOnboardingState.lastStep;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: AppButton(
        label: isLast ? AppStrings.finishButton : AppStrings.authContinue,
        loading: state.phase == OnbPhase.submitting,
        onPressed: () => isLast ? cubit.submit() : cubit.next(),
      ),
    );
  }
}

// ── Step 0: credentials ─────────────────────────────────
class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep({
    super.key,
    required this.state,
    required this.cubit,
    required this.phone,
    required this.password,
    required this.confirm,
  });

  final AccountOnboardingState state;
  final AccountOnboardingCubit cubit;
  final TextEditingController phone;
  final TextEditingController password;
  final TextEditingController confirm;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AuthHeader(
          title: AppStrings.stepCredentialsTitle,
          subtitle: AppStrings.stepCredentialsSubtitle,
        ),
        PhoneField(
          country: state.country,
          controller: phone,
          label: AppStrings.phoneLabel,
          errorText: AuthMessages.phoneValidation(
            state.phoneError,
            state.country,
          ),
          textInputAction: TextInputAction.next,
          onCountryChanged: cubit.setCountry,
          onChanged: cubit.setNational,
        ),
        const SizedBox(height: 18),
        PasswordField(
          controller: password,
          label: AppStrings.passwordLabel,
          hint: AppStrings.passwordHint,
          errorText: AuthMessages.validation(state.passwordError),
          textInputAction: TextInputAction.next,
          onChanged: cubit.setPassword,
        ),
        const SizedBox(height: 18),
        PasswordField(
          controller: confirm,
          label: AppStrings.passwordConfirmLabel,
          hint: AppStrings.passwordConfirmHint,
          errorText: AuthMessages.validation(state.confirmError),
          textInputAction: TextInputAction.done,
          onChanged: cubit.setConfirm,
          onSubmitted: cubit.next,
        ),
        if (state.submitErrorCode != null) ...[
          const SizedBox(height: 18),
          _SubmitError(
            code: state.submitErrorCode!,
            onSignIn: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SignInPage()),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Step 1: name + company ──────────────────────────────
class _NameCompanyStep extends StatelessWidget {
  const _NameCompanyStep({
    super.key,
    required this.state,
    required this.cubit,
    required this.fullName,
    required this.company,
  });

  final AccountOnboardingState state;
  final AccountOnboardingCubit cubit;
  final TextEditingController fullName;
  final TextEditingController company;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AuthHeader(title: AppStrings.nameQuestion),
        AuthTextField(
          controller: fullName,
          hint: AppStrings.nameHint,
          prefixIcon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          errorText: AuthMessages.validation(state.nameError),
          onChanged: cubit.setFullName,
        ),
        const SizedBox(height: 28),
        Text(AppStrings.companyQuestion, style: AppTextStyles.h3),
        const SizedBox(height: 14),
        AuthTextField(
          controller: company,
          hint: AppStrings.companyHint,
          prefixIcon: Icons.business_outlined,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          errorText: AuthMessages.validation(state.companyError),
          onChanged: cubit.setCompany,
        ),
      ],
    );
  }
}

// ── Step 2: use cases ───────────────────────────────────
class _UseCasesStep extends StatelessWidget {
  const _UseCasesStep({
    super.key,
    required this.state,
    required this.cubit,
    required this.other,
  });

  final AccountOnboardingState state;
  final AccountOnboardingCubit cubit;
  final TextEditingController other;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AuthHeader(title: AppStrings.useCaseQuestion, bottomSpacing: 20),
        UseCaseChips(selected: state.useCases, onToggle: cubit.toggleUseCase),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: state.isOtherSelected
              ? Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: AuthTextField(
                    controller: other,
                    hint: AppStrings.useCaseOtherHint,
                    prefixIcon: Icons.edit_outlined,
                    maxLines: 2,
                    onChanged: cubit.setOtherText,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (state.useCaseError != null)
          AuthFieldError(text: AppStrings.useCaseSelectAtLeastOne),
      ],
    );
  }
}

// ── Step 3: summary ─────────────────────────────────────
class _SummaryStep extends StatelessWidget {
  const _SummaryStep({super.key, required this.state, required this.cubit});

  final AccountOnboardingState state;
  final AccountOnboardingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final useCaseLabels = state.useCases
        .map(UseCaseOption.labelForCode)
        .join('، ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        AuthHeader(title: AppStrings.summaryTitle, bottomSpacing: 20),
        _SummaryRow(
          label: AppStrings.summaryPhone,
          value: state.phoneE164 ?? '—',
          onEdit: () => _goto(cubit, 0),
        ),
        _SummaryRow(
          label: AppStrings.summaryName,
          value: state.fullName,
          onEdit: () => _goto(cubit, 1),
        ),
        _SummaryRow(
          label: AppStrings.summaryCompany,
          value: state.company,
          onEdit: () => _goto(cubit, 1),
        ),
        _SummaryRow(
          label: AppStrings.summaryUseCases,
          value: useCaseLabels,
          onEdit: () => _goto(cubit, 2),
        ),
        if (state.submitErrorCode != null) ...[
          const SizedBox(height: 12),
          _SubmitError(code: state.submitErrorCode!),
        ],
      ],
    );
  }

  void _goto(AccountOnboardingCubit cubit, int step) {
    // Walk back to the requested step (back() only moves one at a time).
    while (cubit.state.step > step) {
      cubit.back();
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        value.isEmpty ? '—' : value,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      AppStrings.edit,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small shared bits ───────────────────────────────────
/// Submit failure for a step. A phone that is already registered gets a
/// shortcut into sign-in rather than a dead end.
class _SubmitError extends StatelessWidget {
  const _SubmitError({required this.code, this.onSignIn});
  final String code;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final showSignIn = onSignIn != null && code == 'phoneInUse';
    return AuthErrorBanner(
      message: AuthMessages.authError(code),
      actionLabel: showSignIn ? AppStrings.signInButton : null,
      onAction: showSignIn ? onSignIn : null,
    );
  }
}

// ── Success overlay ─────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, value, __) => Transform.scale(
              scale: value,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 52),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.successTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.h3,
          ),
        ],
      ),
    );
  }
}
