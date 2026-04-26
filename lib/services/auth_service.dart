import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class AuthMessageException implements Exception {
  final String message;

  AuthMessageException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  /* ---------------- CLIENT ---------------- */

  final SupabaseClient _client = SupabaseConfig.client;

  /* ---------------- LOGIN ---------------- */

  static const String missingProfileMessage =
      "Your account is approved, but your profile setup is not complete yet. Please contact the barangay admin.";

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      return null;
    }

    final userId = response.user!.id;

    final resident = await _client
        .from('residents')
        .select('status, rejection_reason, full_name')
        .eq('id', userId)
        .single();

    final status = resident['status'] as String? ?? 'pending';

    if (status == 'pending') {
      await _client.auth.signOut();
      throw AuthMessageException(
        "Your account is still pending approval. Please wait for confirmation.",
      );
    }

    if (status == 'rejected') {
      await _client.auth.signOut();

      throw AuthMessageException(
        "Your account request was not approved. Please contact the barangay office.",
      );
    }

    if (status != 'approved') {
      await _client.auth.signOut();
      throw AuthMessageException(
        "Your account cannot log in right now. Please contact the barangay office.",
      );
    }

    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      try {
        await _client.from('profiles').insert({
          'id': userId,
          'full_name': resident['full_name'] ?? '',
          'role': 'resident',
        });

        return 'resident';
      } catch (_) {
        await _client.auth.signOut();
        throw AuthMessageException(missingProfileMessage);
      }
    }

    final role = (profile['role'] as String?)?.trim() ?? '';

    if (role.isEmpty) {
      return 'resident';
    }

    return role;
  }

  /* ---------------- REGISTER ---------------- */

  Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /* ---------------- LOGOUT ---------------- */

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /* ---------------- CURRENT USER ---------------- */

  User? get currentUser => _client.auth.currentUser;
}
