import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  static const Color _brandBlue = Color(0xFF0B4F94);
  static const Color _pageBackground = Color(0xFFF4F6F7);
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSavingPassword = false;
  bool _isSendingReset = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  String _email = "Not available";
  String _status = "Unknown";
  String _role = "Resident";

  @override
  void initState() {
    super.initState();
    _loadSecurityInfo();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityInfo() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final resident = await _supabase
          .from('residents')
          .select('status')
          .eq('id', user.id)
          .maybeSingle();

      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _email = (user.email?.trim().isNotEmpty ?? false)
            ? user.email!.trim()
            : "Not available";
        _status = (resident?['status'] as String?)?.trim().isNotEmpty == true
            ? resident!['status']
            : "Approved";
        _role = (profile?['role'] as String?)?.trim().isNotEmpty == true
            ? profile!['role']
            : "resident";
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _email = (user.email?.trim().isNotEmpty ?? false)
            ? user.email!.trim()
            : "Not available";
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'approved') return 'Approved';
    if (normalized == 'pending') return 'Pending';
    if (normalized == 'rejected') return 'Rejected';
    return value.trim().isEmpty ? 'Unknown' : value;
  }

  String _roleLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Resident';
    return "${trimmed[0].toUpperCase()}${trimmed.substring(1)}";
  }

  Color _statusColor(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'approved') return const Color(0xFF2E7D32);
    if (normalized == 'pending') return const Color(0xFFE39B00);
    if (normalized == 'rejected') return const Color(0xFFD9534F);
    return const Color(0xFF5E6A71);
  }

  Future<void> _changePassword() async {
    if (_isSavingPassword) return;

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.length < 6) {
      _showSnackBar("Password must be at least 6 characters.");
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar("Passwords do not match.");
      return;
    }

    setState(() => _isSavingPassword = true);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnackBar("Password updated successfully.");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Failed to update password: $e");
    } finally {
      if (mounted) {
        setState(() => _isSavingPassword = false);
      }
    }
  }

  Future<void> _sendResetEmail() async {
    if (_isSendingReset) return;

    final user = _supabase.auth.currentUser;
    final email = user?.email?.trim() ?? '';

    if (email.isEmpty) {
      _showSnackBar("No email address found for this account.");
      return;
    }

    setState(() => _isSendingReset = true);

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      _showSnackBar("Password reset email sent to $email");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Failed to send reset email: $e");
    } finally {
      if (mounted) {
        setState(() => _isSendingReset = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF8FA2B8),
        fontSize: 13,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brandBlue, width: 1.4),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow({
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF8FA2B8),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_status);

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text("Privacy & Security"),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _pageBackground,
        foregroundColor: _brandBlue,
        titleTextStyle: const TextStyle(
          color: _brandBlue,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const Text(
                    "Manage your account protection and review how your resident information is handled.",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Account Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          label: "Email",
                          value: Text(
                            _email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        _buildInfoRow(
                          label: "Status",
                          value: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusLabel(_status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildInfoRow(
                          label: "Role",
                          value: Text(
                            _roleLabel(_role),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Change Password",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Update your password to keep your account secure.",
                          style: TextStyle(
                            color: Color(0xFF667077),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: !_showNewPassword,
                          decoration: _fieldDecoration(
                            label: "New password",
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showNewPassword = !_showNewPassword;
                                });
                              },
                              icon: Icon(
                                _showNewPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          decoration: _fieldDecoration(
                            label: "Confirm new password",
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed:
                                _isSavingPassword ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSavingPassword
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "Update Password",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isSendingReset ? null : _sendResetEmail,
                          icon: _isSendingReset
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.email_outlined),
                          label: const Text("Send password reset email"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brandBlue,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildCard(
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Privacy Notice",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Your personal information is used only for resident verification, barangay services, and complaint/report processing.",
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF667077),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Only authorized barangay personnel should access your submitted records.",
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF667077),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
