import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _brandBlue = Color(0xFF0B4F94);
  static const _cardBackground = Colors.white;
  static const _pageBackground = Color(0xFFF8FAFC);
  static const _borderColor = Color(0xFFE4E4E4);
  static const _errorColor = Color(0xFFD9534F);
  static const _errorBackground = Color(0xFFFFF3F2);
  static const _errorBorder = Color(0xFFF4C7C3);
  static const _hintColor = Color(0xFF9B9B9B);
  static const _bodyTextColor = Color(0xFF646464);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _emailHasError = false;
  bool _passwordHasError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final validationMessage = _validateLoginInput(email, password);

    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _emailHasError = false;
      _passwordHasError = false;
    });

    try {
      final role = await _authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _loginErrorMessage(e);
        _emailHasError = true;
        _passwordHasError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateLoginInput(String email, String password) {
    final isEmailEmpty = email.isEmpty;
    final isPasswordEmpty = password.isEmpty;

    if (isEmailEmpty && isPasswordEmpty) {
      _emailHasError = true;
      _passwordHasError = true;
      return "Please enter your email and password.";
    }

    if (isEmailEmpty) {
      _emailHasError = true;
      _passwordHasError = false;
      return "Please enter your email.";
    }

    if (isPasswordEmpty) {
      _emailHasError = false;
      _passwordHasError = true;
      return "Please enter your password.";
    }

    if (!_isValidEmail(email)) {
      _emailHasError = true;
      _passwordHasError = false;
      return "Please enter a valid email address.";
    }

    _emailHasError = false;
    _passwordHasError = false;
    return null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  String _loginErrorMessage(Object error) {
    if (error is AuthMessageException) {
      return error.message;
    }

    final message = error.toString().toLowerCase();

    if (message.contains('pending approval')) {
      return "Your account is still pending approval. Please wait for confirmation.";
    }

    if (message.contains('not approved') ||
        message.contains('rejected') ||
        message.contains('registration was rejected')) {
      return "Your account request was not approved. Please contact the barangay office.";
    }

    if (message.contains('too many') ||
        message.contains('rate limit') ||
        message.contains('429')) {
      return "Too many login attempts. Please try again later.";
    }

    if (message.contains('invalid login') ||
        message.contains('invalid credentials') ||
        message.contains('invalid email or password') ||
        message.contains('email not confirmed')) {
      return "Incorrect email or password. Please try again.";
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('failed host lookup') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('clientexception')) {
      return "Unable to connect. Please check your internet connection.";
    }

    return "Something went wrong. Please try again.";
  }

  void _clearErrorForInput() {
    if (_errorMessage == null && !_emailHasError && !_passwordHasError) return;

    setState(() {
      _errorMessage = null;
      _emailHasError = false;
      _passwordHasError = false;
    });
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
    bool hasError = false,
  }) {
    final borderColor = hasError ? _errorColor : _borderColor;

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
      prefixIcon: Icon(icon, color: _hintColor, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? _errorColor : _brandBlue,
          width: 1.4,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _errorBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _errorColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: _errorColor,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 36),
                    SvgPicture.asset(
                      'lib/assets/Bancao-Bancao Logo.svg',
                      height: 84,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Bancao-Bancao App',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _brandBlue,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 42),
                      child: Text(
                        'Access your community civic portal\nand stay connected with local\nservices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _bodyTextColor,
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                      decoration: const BoxDecoration(
                        color: _cardBackground,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _clearErrorForInput(),
                            decoration: _inputDecoration(
                              hintText: 'Email',
                              icon: Icons.mail_outline,
                              hasError: _emailHasError,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => _clearErrorForInput(),
                            onSubmitted: (_) => _login(),
                            decoration: _inputDecoration(
                              hintText: 'Password',
                              icon: Icons.lock_outline,
                              hasError: _passwordHasError,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _hintColor,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorMessage(),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Forgot password is not available yet.',
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _brandBlue,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(
                            color: Color(0xFFEAEAEA),
                            thickness: 1,
                            height: 1,
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              const Text(
                                "Don't have an account?",
                                style: TextStyle(
                                  color: _bodyTextColor,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _brandBlue,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
