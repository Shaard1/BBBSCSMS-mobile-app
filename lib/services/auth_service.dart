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

    // First, check if user is an admin in the profiles table
    final profile = await _client
        .from('profiles')
        .select('role, full_name')
        .eq('id', userId)
        .maybeSingle();

    // If user has admin role, allow login
    final profileRole =
        (profile?['role'] as String?)?.trim().toLowerCase() ?? '';
    if (profileRole == 'admin') {
      return 'admin';
    }

    // For non-admin users, check the residents table for approval status
    var resident = await _client
        .from('residents')
        .select('id, user_id, status, rejection_reason, full_name')
        .eq('user_id', userId)
        .maybeSingle();

    resident ??= await _client
        .from('residents')
        .select('id, user_id, status, rejection_reason, full_name')
        .eq('id', userId)
        .maybeSingle();

    if (resident == null) {
      if (profileRole == 'resident') {
        final createdResident = await _createResidentRecordFromProfile(
          userId: userId,
          fullName: profile?['full_name']?.toString() ?? '',
        );

        if (createdResident) {
          return 'resident';
        }
      }

      await _client.auth.signOut();
      throw AuthMessageException(
        "Your resident record is not linked to this account yet. Please contact the barangay admin to relink your account.",
      );
    }

    final status =
        (resident['status'] as String?)?.trim().toLowerCase() ?? 'pending';

    if (status == 'pending') {
      await _client.auth.signOut();
      throw AuthMessageException(
        "Your account has been submitted and is still pending approval. Please wait 1-2 working days for barangay verification.",
      );
    }

    if (status == 'rejected') {
      await _client.auth.signOut();
      final rejectionReason =
          (resident['rejection_reason'] as String?)?.trim();
      final reasonMessage = rejectionReason == null || rejectionReason.isEmpty
          ? "No reason was provided."
          : rejectionReason;

      throw AuthMessageException(
        "Your account request was rejected. Reason: $reasonMessage Please register again with corrected information.",
      );
    }

    if (status != 'approved') {
      await _client.auth.signOut();
      throw AuthMessageException(
        "Your account cannot log in right now. Please contact the barangay office.",
      );
    }

    // Create or update profile for resident
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

    final role = profileRole;

    if (role.isEmpty) {
      return 'resident';
    }

    return role;
  }

  Future<bool> _createResidentRecordFromProfile({
    required String userId,
    required String fullName,
  }) async {
    try {
      await _client.from('residents').insert({
        'id': userId,
        'user_id': userId,
        'full_name': fullName.trim().isNotEmpty ? fullName.trim() : 'Resident',
        'status': 'pending',
        'address': '',
        'contact_number': '',
        'gender': '',
        'civil_status': '',
      });
      return true;
    } catch (_) {
      return false;
    }
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
