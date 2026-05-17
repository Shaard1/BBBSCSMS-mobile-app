import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../widgets/top_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _brandBlue = Color(0xFF0B4F94);
  static const _buttonBlue = Color(0xFF006CBF); // ***** Button color *****
  static const _linkBlue = Color(0xFF003E7E);
  static const _cardBackground = Colors.white;
  static const _pageBackground = Color(0xFFF8FAFC);
  static const _borderColor = Color(0xFFE4E4E4);
  static const _errorColor = Color(0xFFD9534F);
  static const _errorBackground = Color(0xFFFFF3F2);
  static const _errorBorder = Color(0xFFF4C7C3);
  static const _hintColor = Color(0xFF9B9B9B);
  static const _fieldIconColor = Color(0xFF737782);
  static const _bodyTextColor = Color(0xFF646464);

  static const double _formTopRadius = 24;
  static const double _buttonRadius = 8; // ***** Button border radius *****

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
    final hintColor = hasError ? _errorColor : _hintColor;
    final iconColor = hasError ? _errorColor : _fieldIconColor;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: hintColor, fontSize: 15),
      prefixIcon: Icon(icon, color: iconColor, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? _errorColor : _brandBlue,
          width: 1.4,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompactPhone = screenHeight < 720;

    final topSpacing = isCompactPhone
        ? 44.0
        : 50.0; // ***** Top spacing / logo section position *****
    final logoSize = isCompactPhone ? 86.0 : 96.0; // ***** Logo size *****
    final titleFontSize =
        isCompactPhone ? 28.0 : 30.0; // ***** Title font size *****
    final subtitleFontSize = 16.0; // ***** Subtitle font size *****
    final formTopSpacing = isCompactPhone
        ? 44.0
        : 52.0; // ***** Form container starting position *****
    final inputFieldHeight =
        isCompactPhone ? 56.0 : 58.0; // ***** Input field height *****
    final buttonHeight =
        isCompactPhone ? 54.0 : 56.0; // ***** Button height *****

    return Scaffold(
      backgroundColor: _pageBackground,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: topSpacing),
                  SvgPicture.asset(
                    'lib/assets/Bancao-Bancao Logo.svg',
                    width: logoSize,
                    height: logoSize,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Bancao-Bancao App',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.publicSans(
                      color: _brandBlue,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 42),
                    child: Text(
                      'Access your community civic portal\nand stay connected with local\nservices.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF424751),
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w400,
                        height: 24 / 16,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  SizedBox(height: formTopSpacing),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                      decoration: const BoxDecoration(
                        color: _cardBackground, // soft white, not too pure white
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          // ***** Login Form: Email Field Start *****
                          SizedBox(
                            height: inputFieldHeight,
                            child: TextField(
                              controller: _emailController,
                              style: TextStyle(
                                color: _emailHasError
                                    ? _errorColor
                                    : Colors.black87,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _clearErrorForInput(),
                              decoration: _inputDecoration(
                                hintText: 'Email',
                                icon: Icons.mail_outline,
                                hasError: _emailHasError,
                              ),
                            ),
                          ),
                          // ***** Login Form: Email Field End *****
                          const SizedBox(height: 14),
                          // ***** Login Form: Password Field Start *****
                          SizedBox(
                            height: inputFieldHeight,
                            child: TextField(
                              controller: _passwordController,
                              style: TextStyle(
                                color: _passwordHasError
                                    ? _errorColor
                                    : Colors.black87,
                              ),
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
                                    color: _passwordHasError
                                        ? _errorColor
                                        : _fieldIconColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // ***** Login Form: Password Field End *****
                          // ***** Login Form: Error Message Start *****
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorMessage(),
                          ],
                          // ***** Login Form: Error Message End *****
                          const SizedBox(height: 24),
                          // ***** Login Form: Login Button Start *****
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _buttonBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(_buttonRadius),
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
                          // ***** Login Form: Login Button End *****
                          const SizedBox(height: 26),
                          // ***** Login Form: Forgot Password Start *****
                          TextButton(
                            onPressed: () {
                              TopToast.show(
                                context,
                                'Forgot password is not available yet.',
                                backgroundColor: _brandBlue,
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _linkBlue,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // ***** Login Form: Forgot Password End *****
                          const SizedBox(height: 14),
                          const Divider(
                            color: Color(0xFFEAEAEA),
                            thickness: 1,
                            height: 1,
                          ),
                          const SizedBox(height: 16),
                          // ***** Login Form: Register Prompt Start *****
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF424751),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 20 / 14,
                                  letterSpacing: 0,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _linkBlue,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 20 / 14,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // ***** Login Form: Register Prompt End *****
                        ],
                      ),
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
