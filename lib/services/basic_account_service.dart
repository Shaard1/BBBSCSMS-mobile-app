import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

class BasicAccountAccess {
  const BasicAccountAccess(
      {required this.active,
      required this.phoneVerified,
      required this.identityStatus,
      required this.basicAccess,
      required this.testAccess,
      this.declaredPhone});

  factory BasicAccountAccess.fromJson(Map<String, dynamic> json) =>
      BasicAccountAccess(
        active: json['account_state'] == 'active',
        phoneVerified: json['phone_verified'] == true,
        identityStatus: json['identity_status']?.toString() ?? 'unverified',
        basicAccess: json['basic_access'] == true,
        testAccess: json['test_access'] == true,
        declaredPhone: json['declared_phone']?.toString(),
      );

  final bool active;
  final bool phoneVerified;
  final String identityStatus;
  final bool basicAccess;
  final bool testAccess;
  final String? declaredPhone;
}

class BasicAccountService {
  BasicAccountService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;
  final SupabaseClient _client;
  static const noticeVersion = '2026-10-21';

  // This preview never enables unverified registration against the live project.
  static const _previewRequested =
      bool.fromEnvironment('BASIC_REGISTRATION_PREVIEW');
  static bool get previewEnabled =>
      _previewRequested &&
      SupabaseConfig.supabaseUrl == 'https://xvpyskemxgspttzjokiu.supabase.co';

  static String? normalizePhone(String input) {
    if (!RegExp(r'^[+0-9 ()-]+$').hasMatch(input.trim())) return null;
    final digits = input.replaceAll(RegExp(r'[ ()-]'), '');
    if (RegExp(r'^09\d{9}$').hasMatch(digits)) {
      return '+63${digits.substring(1)}';
    }
    if (RegExp(r'^639\d{9}$').hasMatch(digits)) return '+$digits';
    if (RegExp(r'^\+639\d{9}$').hasMatch(digits)) return digits;
    return null;
  }

  static String? validatePassword(String password) {
    if (password.runes.length < 15) {
      return 'Use at least 15 characters; a passphrase is welcome.';
    }
    if (password.runes.length > 128) return 'Use no more than 128 characters.';
    return null;
  }

  Future<BasicAccountAccess?> access() async {
    final data = await _client.rpc('get_my_resident_access');
    if (data == null) return null;
    return BasicAccountAccess.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BasicAccountAccess> complete(
      {required String name, required String phone}) async {
    final data = await _client.rpc('complete_basic_registration', params: {
      'p_full_name': name.trim(),
      'p_phone': phone,
      'p_privacy_version': noticeVersion,
      'p_terms_version': noticeVersion,
    });
    return BasicAccountAccess.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<bool> registerForTest(
      {required String name,
      required String phone,
      required String email,
      required String password}) async {
    if (!previewEnabled) {
      throw StateError('Test registration is unavailable in this build.');
    }
    // Ensure the migration exists before creating an Authentication account.
    final available = await _client.rpc('basic_registration_preview_available');
    if (available != true) {
      throw StateError(
          'The test account workflow has not been enabled on the test database.');
    }
    final response = await _client.auth
        .signUp(email: email.trim().toLowerCase(), password: password, data: {
      'full_name': name.trim(),
      'declared_phone': phone,
      'basic_registration_version': noticeVersion,
    });
    if (response.user == null) {
      throw StateError('Account creation did not complete.');
    }
    if (response.session == null) return false;
    await complete(name: name, phone: phone);
    return true;
  }

  Future<void> resumeRegistration(User user) async {
    final metadata = user.userMetadata ?? {};
    if (metadata['basic_registration_version'] != noticeVersion) return;
    if (await access() != null) return;
    final phone = normalizePhone(metadata['declared_phone']?.toString() ?? '');
    final name = metadata['full_name']?.toString().trim() ?? '';
    if (phone == null || name.length < 2) {
      throw StateError('Complete your registration details first.');
    }
    await complete(name: name, phone: phone);
  }
}
