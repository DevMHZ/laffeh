import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.id,
    super.phone,
    required super.fullName,
    required super.companyName,
    super.useCaseCodes,
    super.otherUseCaseText,
    required super.onboardingCompleted,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      phone: map['phone'] as String?,
      fullName: (map['full_name'] as String?) ?? '',
      companyName: (map['company_name'] as String?) ?? '',
      useCaseCodes: switch (map['use_case_codes']) {
        final List<dynamic> codes => codes.cast<String>(),
        _ => const <String>[],
      },
      otherUseCaseText: map['other_use_case_text'] as String?,
      onboardingCompleted: (map['onboarding_completed'] as bool?) ?? false,
    );
  }
}
