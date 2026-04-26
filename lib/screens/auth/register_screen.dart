import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _brandBlue = Color(0xFF006CBF);
  static const _pageBackground = Color(0xFFF8FAFC);
  static const _cardBackground = Colors.white;
  static const _borderColor = Color(0xFFE6E8ED);
  static const _hintColor = Color(0xFFA0A7B4);
  static const _bodyColor = Color(0xFF64748B);
  static const _titleColor = Color(0xFF006CBF);
  static const _uploadBorderColor = Color(0xFFC2C6D3);
  static const _checkboxFillColor = Color(0xFFF3F4F5);

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _scrollController = ScrollController();
  final _verificationSectionKey = GlobalKey();

  final ImagePicker _picker = ImagePicker();

  String? gender;
  String? civilStatus;
  String? idType;

  File? idImage;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _confirmedAccuracy = false;
  String? _expandedDropdown;
  String? _hoveredDropdown;
  final Map<String, String?> _fieldErrors = {};

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setFieldError(String fieldKey, String? message) {
    setState(() {
      if (message == null || message.isEmpty) {
        _fieldErrors.remove(fieldKey);
      } else {
        _fieldErrors[fieldKey] = message;
      }
    });
  }

  String? _errorFor(String fieldKey) => _fieldErrors[fieldKey];

  bool _isValidMobileNumber(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^(09\d{9}|639\d{9})$').hasMatch(digitsOnly);
  }

  bool _isNetworkError(Object error) {
    if (error is SocketException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network') ||
        message.contains('connection');
  }

  void _scrollToVerificationSection() {
    final context = _verificationSectionKey.currentContext;
    if (context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  Future<void> _pickIdImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Use Camera'),
              onTap: () async {
                Navigator.pop(context);
                await _handlePickedImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _handlePickedImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePickedImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (picked == null || !mounted) return;

      setState(() {
        idImage = File(picked.path);
        _fieldErrors.remove('id_image');
      });
    } catch (e) {
      _showSnackBar('Image error: $e');
    }
  }

  bool _validateForm() {
    final nextErrors = <String, String?>{};

    if (_fullNameController.text.trim().isEmpty) {
      nextErrors['full_name'] = 'Please enter your full name.';
    }

    if (_contactController.text.trim().isEmpty) {
      nextErrors['contact'] = 'Please enter a valid mobile number.';
    } else if (!_isValidMobileNumber(_contactController.text.trim())) {
      nextErrors['contact'] = 'Please enter a valid mobile number.';
    }

    if (gender == null) {
      nextErrors['gender'] = 'Please select your gender.';
    }

    if (civilStatus == null) {
      nextErrors['civil_status'] = 'Please select your civil status.';
    }

    if (_addressController.text.trim().isEmpty) {
      nextErrors['address'] = 'Please enter your address.';
    }

    if (_emailController.text.trim().isEmpty) {
      nextErrors['email'] = 'Please enter your email.';
    }

    if (_passwordController.text.trim().length < 6) {
      nextErrors['password'] = 'Invalid Password';
    }

    if (_confirmPasswordController.text.trim() !=
        _passwordController.text.trim()) {
      nextErrors['confirm_password'] = 'Passwords do not match.';
    }

    if (idType == null) {
      nextErrors['id_type'] = 'Please select your ID type.';
    }

    if (idImage == null) {
      nextErrors['id_image'] = 'Please upload a valid ID.';
    }

    if (!_confirmedAccuracy) {
      nextErrors['confirmed_accuracy'] = 'You must agree before submitting.';
    }

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(nextErrors);
    });

    if (nextErrors.containsKey('id_image') ||
        nextErrors.containsKey('confirmed_accuracy') ||
        nextErrors.containsKey('id_type')) {
      _scrollToVerificationSection();
    }

    return nextErrors.isEmpty;
  }

  Future<String?> uploadImage(File file, String path) async {
    final storage = Supabase.instance.client.storage;

    await storage.from('resident-files').upload(path, file);

    return storage.from('resident-files').getPublicUrl(path);
  }

  Future<void> _showRegistrationSubmittedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Submitted',
                  style: TextStyle(
                    color: _brandBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your account has been submitted and is now pending approval by the barangay.\nPlease wait 1-2 working days for verification.',
                  style: TextStyle(
                    color: _bodyColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Go to Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _register() async {
    if (_isLoading || !_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = authResponse.user;

      if (user == null) {
        throw Exception('Registration failed');
      }

      String? idImageUrl;
      if (idImage != null) {
        idImageUrl = await uploadImage(idImage!, 'id_images/${user.id}.png');
      }

      final residentPayload = <String, dynamic>{
        'id': user.id,
        'full_name': _fullNameController.text.trim(),
        'birthdate': null,
        'gender': gender!,
        'address': _addressController.text.trim(),
        'contact_number': _contactController.text.trim(),
        'civil_status': civilStatus!,
        'id_type': idType!,
        'id_image': idImageUrl,
        'profile_image': null,
        'status': 'pending',
      };

      await Supabase.instance.client.from('residents').insert(residentPayload);

      if (!mounted) return;

      await _showRegistrationSubmittedDialog();
    } catch (e) {
      if (_isNetworkError(e)) {
        _showSnackBar('No internet connection. Please try again.');
      } else {
        _showSnackBar('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _fieldStyle(
    String hint,
    Widget prefixIcon, {
    Widget? suffixIcon,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 14,
      ),
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(
        minWidth: 46,
        minHeight: 46,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _cardBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? const Color(0xFFFF4D4F) : _borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? const Color(0xFFFF4D4F) : _brandBlue,
          width: 1.3,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? const Color(0xFFFF4D4F) : _borderColor,
        ),
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        color: Color(0xFFFF4D4F),
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF4D4F), width: 1.3),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF4D4F), width: 1.3),
      ),
    );
  }

  Widget _assetFieldIcon(
    String assetPath, {
    double width = 18,
    double height = 18,
    EdgeInsetsGeometry padding = const EdgeInsets.only(left: 14, right: 12),
  }) {
    return Padding(
      padding: padding,
      child: SvgPicture.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildDropdownField({
    required String fieldKey,
    required String? value,
    required String hint,
    required Widget icon,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    final isExpanded = _expandedDropdown == fieldKey;
    final isHovered = _hoveredDropdown == fieldKey;
    final errorText = _errorFor(fieldKey);
    final hasError = errorText != null && errorText.isNotEmpty;
    final borderColor = hasError
        ? const Color(0xFFFF4D4F)
        : isExpanded
            ? const Color(0xFF6E7684)
            : isHovered
                ? const Color(0xFFD5D9E1)
                : _borderColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredDropdown = fieldKey),
      onExit: (_) {
        if (_hoveredDropdown == fieldKey) {
          setState(() => _hoveredDropdown = null);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(isExpanded ? 12 : 12),
              onTap: () {
                setState(() {
                  _expandedDropdown = isExpanded ? null : fieldKey;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: isHovered || isExpanded
                      ? const Color(0xFFF1F3F6)
                      : _cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    icon,
                    Expanded(
                      child: Text(
                        value ?? hint,
                        style: const TextStyle(
                          color: Color(0xFF3F4854),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF7E8796),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD9DFE7)),
                ),
                child: Column(
                  children: options.map((option) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _expandedDropdown = null;
                          });
                          onSelected(option);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: Text(
                            option,
                            style: const TextStyle(
                              color: Color(0xFF3F4854),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                errorText,
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldError(String fieldKey) {
    final errorText = _errorFor(fieldKey);
    if (errorText == null || errorText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Text(
        errorText,
        style: const TextStyle(
          color: Color(0xFFFF4D4F),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(int number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: _brandBlue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _brandBlue,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idImageError = _errorFor('id_image');
    final confirmedAccuracyError = _errorFor('confirmed_accuracy');

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Create Account',
                  style: TextStyle(
                    color: _titleColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please provide your details for residency verification. This process ensures the security of our community portal.',
                style: TextStyle(
                  color: _bodyColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(1, 'Personal Information'),
              _buildSectionCard([
                TextField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _setFieldError('full_name', null),
                  decoration: _fieldStyle(
                    'Juan Dela Cruz',
                    _assetFieldIcon(
                      'lib/assets/Juan Dela Cruz Satus Icon.svg',
                    ),
                    errorText: _errorFor('full_name'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  ],
                  onChanged: (_) => _setFieldError('contact', null),
                  decoration: _fieldStyle(
                    'Contact Number',
                    _assetFieldIcon(
                      'lib/assets/Contact Number Icon.svg',
                    ),
                    errorText: _errorFor('contact'),
                  ),
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  fieldKey: 'gender',
                  value: gender,
                  hint: 'Gender',
                  icon: _assetFieldIcon(
                    'lib/assets/Gender Status Icon.svg',
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.only(right: 12),
                  ),
                  options: const ['Male', 'Female'],
                  onSelected: (value) {
                    setState(() {
                      gender = value;
                      _fieldErrors.remove('gender');
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdownField(
                  fieldKey: 'civil_status',
                  value: civilStatus,
                  hint: 'Civil Status',
                  icon: _assetFieldIcon(
                    'lib/assets/Civil Status Icon.svg',
                    padding: const EdgeInsets.only(right: 12),
                  ),
                  options: const [
                    'Married',
                    'Single',
                    'Separated',
                    'Divorce',
                    'Widowed',
                    'Civil Partnership',
                  ],
                  onSelected: (value) {
                    setState(() {
                      civilStatus = value;
                      _fieldErrors.remove('civil_status');
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _setFieldError('address', null),
                  decoration: _fieldStyle(
                    'Address',
                    _assetFieldIcon('lib/assets/MapPin.svg'),
                    errorText: _errorFor('address'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              _buildSectionTitle(2, 'Account Details'),
              _buildSectionCard([
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _setFieldError('email', null),
                  decoration: _fieldStyle(
                    'Email',
                    _assetFieldIcon('lib/assets/Email Status Icon.svg'),
                    errorText: _errorFor('email'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _setFieldError('password', null),
                  decoration: _fieldStyle(
                    'Password',
                    _assetFieldIcon('lib/assets/Password Status Icon.svg'),
                    errorText: _errorFor('password'),
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
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _setFieldError('confirm_password', null),
                  onSubmitted: (_) => _register(),
                  decoration: _fieldStyle(
                    'Confirm Password',
                    _assetFieldIcon('lib/assets/Password Status Icon.svg'),
                    errorText: _errorFor('confirm_password'),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _hintColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              KeyedSubtree(
                key: _verificationSectionKey,
                child: _buildSectionTitle(3, 'Verification'),
              ),
              _buildSectionCard([
                _buildDropdownField(
                  fieldKey: 'id_type',
                  value: idType,
                  hint: 'ID Type',
                  icon: _assetFieldIcon(
                    'lib/assets/ID Type Status Icon.svg',
                    padding: const EdgeInsets.only(right: 12),
                  ),
                  options: const [
                    'Barangay ID',
                    'Student ID',
                    'Postal ID',
                    'Driver License',
                    'PhilSys ID',
                  ],
                  onSelected: (value) {
                    setState(() {
                      idType = value;
                      _fieldErrors.remove('id_type');
                    });
                  },
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickIdImage,
                    borderRadius: BorderRadius.circular(18),
                    child: CustomPaint(
                      painter: _DashedRoundedRectPainter(
                        color: idImageError != null && idImageError.isNotEmpty
                            ? const Color(0xFFFF4D4F)
                            : _uploadBorderColor,
                        radius: 18,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _checkboxFillColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.file_upload_outlined,
                                  color: _brandBlue,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Upload ID Photo',
                                  style: TextStyle(
                                    color: _brandBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (idImage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                idImage!.path
                                    .split(Platform.pathSeparator)
                                    .last,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _bodyColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFieldError('id_image'),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _confirmedAccuracy,
                      activeColor: _brandBlue,
                      checkColor: _brandBlue,
                      fillColor:
                          WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return _checkboxFillColor;
                        }
                        return _checkboxFillColor;
                      }),
                      side: BorderSide(
                        color: confirmedAccuracyError != null &&
                                confirmedAccuracyError.isNotEmpty
                            ? const Color(0xFFFF4D4F)
                            : _borderColor,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _confirmedAccuracy = value ?? false;
                          if (_confirmedAccuracy) {
                            _fieldErrors.remove('confirmed_accuracy');
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: _bodyColor,
                              fontSize: 11,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'I confirm that all provided information is accurate and I agree to the ',
                              ),
                              TextSpan(
                                text: 'Privacy Policy.',
                                style: TextStyle(
                                  color: _brandBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildFieldError('confirmed_accuracy'),
              ]),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Submit for Verification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: _bodyColor,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _brandBlue,
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Log in here',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
