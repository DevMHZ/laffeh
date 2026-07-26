import 'package:equatable/equatable.dart';

/// The user's profile row. Never holds the password — that lives only in
/// Supabase Auth.
///
/// [phone] and [useCaseCodes] are server-maintained mirrors (of
/// `auth.users.phone` and of `user_use_cases`), written by the sign-up trigger
/// and `save_onboarding`, so a profile row reads on its own.
class Profile extends Equatable {
  final String id;
  final String? phone;
  final String fullName;
  final String companyName;
  final List<String> useCaseCodes;
  final String? otherUseCaseText;
  final bool onboardingCompleted;

  const Profile({
    required this.id,
    this.phone,
    required this.fullName,
    required this.companyName,
    this.useCaseCodes = const [],
    this.otherUseCaseText,
    required this.onboardingCompleted,
  });

  @override
  List<Object?> get props => [
    id,
    phone,
    fullName,
    companyName,
    useCaseCodes,
    otherUseCaseText,
    onboardingCompleted,
  ];
}
