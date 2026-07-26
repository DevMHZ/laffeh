import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

/// Supabase access for the `profiles` table and the `save_onboarding` RPC.
class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<ProfileModel?> fetchMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (row == null) return null;
    return ProfileModel.fromMap(row);
  }

  Future<void> recordTermsAcceptance(String termsVersion) async {
    await _client.rpc(
      'record_terms_acceptance',
      params: {'p_terms_version': termsVersion},
    );
  }

  Future<void> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
    String? termsVersion,
  }) async {
    await _client.rpc(
      'save_onboarding',
      params: {
        'p_full_name': fullName,
        'p_company_name': companyName,
        'p_use_case_codes': useCaseCodes,
        'p_other_text': otherText,
        'p_terms_version': termsVersion,
      },
    );
  }
}
