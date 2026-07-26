import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../route_planner/presentation/pages/route_planner_page.dart';
import '../../domain/country.dart';
import '../auth_messages.dart';
import '../cubit/auth_cubit.dart';
import '../../../profile/presentation/pages/account_onboarding_page.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_header.dart';
import '../widgets/language_chip.dart';
import '../widgets/password_field.dart';
import '../widgets/phone_field.dart';
import 'forgot_password_sheet.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  Country _country = Country.fallback;

  bool _submitting = false;
  String? _phoneError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    // Lenient on sign-in: length must fit the country, but an unusual prefix
    // our curated plan doesn't know must never lock an existing account out.
    final phoneErr = _country.validateNational(_phone.text, strict: false);
    final phoneE164 = _country.toE164(_phone.text, strict: false);
    final passErr = FormValidators.password(_password.text);

    setState(() {
      _phoneError = AuthMessages.phoneValidation(phoneErr, _country);
      _passwordError = AuthMessages.validation(passErr);
      _formError = null;
    });
    if (phoneE164 == null || passErr != null) return;

    setState(() => _submitting = true);
    final result = await context.read<AuthCubit>().signIn(
      phone: phoneE164,
      password: _password.text,
    );
    if (!mounted) return;

    await result.when(
      success: (_) async {
        final complete = await sl<ProfileRepository>().isOnboardingComplete();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => complete
                ? const RoutePlannerPage()
                : const AccountOnboardingPage(
                    startStep: 1,
                    credentialsDone: true,
                  ),
          ),
        );
      },
      failure: (f) async {
        setState(() {
          _submitting = false;
          _formError = AuthMessages.authError(
            f is AuthFailure ? f.code : 'unknown',
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: Center(child: LanguageChip()),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              AuthHeader(
                title: AppStrings.signInTitle,
                subtitle: AppStrings.signInSubtitle,
              ),
              PhoneField(
                country: _country,
                controller: _phone,
                label: AppStrings.phoneLabel,
                errorText: _phoneError,
                textInputAction: TextInputAction.next,
                onCountryChanged: (c) => setState(() => _country = c),
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
              ),
              const SizedBox(height: 18),
              PasswordField(
                controller: _password,
                label: AppStrings.passwordLabel,
                hint: AppStrings.passwordHint,
                errorText: _passwordError,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: _submit,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => showForgotPasswordSheet(context),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    AppStrings.forgotPassword,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 4),
                AuthErrorBanner(message: _formError!),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: AppStrings.signInButton,
                loading: _submitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 28),
              _CreateAccountPrompt(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const AccountOnboardingPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Don't have an account? — Create a new account", as one tappable line so
/// the link never wraps away from its question.
class _CreateAccountPrompt extends StatelessWidget {
  const _CreateAccountPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              Text(
                AppStrings.signInNoAccount,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                AppStrings.signInCreateNew,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
