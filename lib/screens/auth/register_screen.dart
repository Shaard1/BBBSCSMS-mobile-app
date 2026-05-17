import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'id_camera_capture_screen.dart';
import 'register_verification_screen.dart';
import '../../widgets/top_toast.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _brandBlue = Color(0xFF006CBF);
  static const _pageBackground = Color(0xFFF8FAFC);
  static const _cardBackground = Colors.white;
  static const _sectionPanelBackground = Color(0xFFFFFFFF);
  static const _borderColor = Color(0xFFE6E8ED);
  static const _hintColor = Color(0xFFA0A7B4);
  static const _fieldIconColor = Color(0xFF656A70);
  static const _fieldTextColor = Color(0xFF484D51);
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
  String? birthMonth;
  String? birthDay;
  String? birthYear;

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
    TopToast.show(context, message, backgroundColor: _brandBlue);
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

  String _extractLocalContactDigits(String value) {
    var digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.startsWith('63')) {
      digitsOnly = digitsOnly.substring(2);
    }
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }
    return digitsOnly;
  }

  bool _isValidMobileNumber(String value) {
    final localDigits = _extractLocalContactDigits(value);
    return RegExp(r'^9\d{9}$').hasMatch(localDigits);
  }

  String _normalizedContactNumber() {
    final localDigits = _extractLocalContactDigits(_contactController.text);
    return '+63$localDigits';
  }

  TextStyle _fieldInputTextStyle(String fieldKey) {
    final hasError = _errorFor(fieldKey) != null;
    return TextStyle(
      color: hasError ? const Color(0xFFFF4D4F) : _fieldTextColor,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    );
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
      XFile? picked;
      if (source == ImageSource.camera) {
        final capturedFile = await Navigator.push<File?>(
          context,
          MaterialPageRoute(
            builder: (_) => const IdCameraCaptureScreen(),
          ),
        );
        if (capturedFile != null) {
          picked = XFile(capturedFile.path);
        }
      } else {
        picked = await _picker.pickImage(
          source: source,
          imageQuality: 70,
        );
      }

      if (picked == null || !mounted) return;
      final selected = picked;

      setState(() {
        idImage = File(selected.path);
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

    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(nextErrors);
    });

    return nextErrors.isEmpty;
  }

  Future<String?> uploadImage(File file, String path) async {
    final storage = Supabase.instance.client.storage;
    final uploadFile = await _compressImageForUpload(file);

    await storage.from('resident-files').upload(path, uploadFile);

    return storage.from('resident-files').getPublicUrl(path);
  }

  Future<File> _compressImageForUpload(File original) async {
    try {
      final baseName = p.basenameWithoutExtension(original.path);
      final targetPath = p.join(
        original.parent.path,
        '${baseName}_compressed.jpg',
      );

      final compressed = await FlutterImageCompress.compressAndGetFile(
        original.path,
        targetPath,
        format: CompressFormat.jpeg,
        quality: 60,
        minWidth: 1280,
        minHeight: 1280,
        keepExif: false,
      );

      if (compressed == null) return original;
      return File(compressed.path);
    } catch (_) {
      // Fallback to original file if compression fails.
      return original;
    }
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

  Future<String?> _register({
    required String selectedIdType,
    required File selectedFrontIdImage,
    required File selectedBackIdImage,
  }) async {
    if (_isLoading) return 'Registration is already in progress.';

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

      final idImageFrontUrl = await uploadImage(
        selectedFrontIdImage,
        'id_images/${user.id}_front.jpg',
      );
      final idImageBackUrl = await uploadImage(
        selectedBackIdImage,
        'id_images/${user.id}_back.jpg',
      );

      final residentPayload = <String, dynamic>{
        'id': user.id,
        'full_name': _fullNameController.text.trim(),
        'birthdate': null,
        'gender': gender!,
        'address': _addressController.text.trim(),
        'contact_number': _normalizedContactNumber(),
        'civil_status': civilStatus!,
        'id_type': selectedIdType,
        'id_image': idImageFrontUrl,
        'id_image_front': idImageFrontUrl,
        'id_image_back': idImageBackUrl,
        'profile_image': null,
        'status': 'pending',
      };

      try {
        await Supabase.instance.client.from('residents').insert(residentPayload);
      } catch (insertError) {
        // Backward-compat: if new columns are not migrated yet, fall back
        // to legacy single-image payload so registration can still continue.
        final message = insertError.toString().toLowerCase();
        final missingNewColumns =
            message.contains('id_image_front') ||
            message.contains('id_image_back') ||
            message.contains('column') && message.contains('does not exist');

        if (!missingNewColumns) rethrow;

        final legacyPayload = <String, dynamic>{
          'id': user.id,
          'full_name': _fullNameController.text.trim(),
          'birthdate': null,
          'gender': gender!,
          'address': _addressController.text.trim(),
          'contact_number': _normalizedContactNumber(),
          'civil_status': civilStatus!,
          'id_type': selectedIdType,
          'id_image': idImageFrontUrl,
          'profile_image': null,
          'status': 'pending',
        };
        await Supabase.instance.client.from('residents').insert(legacyPayload);
      }

      return null;
    } catch (e) {
      if (_isNetworkError(e)) {
        return 'No internet connection. Please try again.';
      } else {
        return 'Registration failed: $e';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _continueToVerification() async {
    if (_isLoading || !_validateForm()) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVerificationScreen(
          initialIdType: idType,
          initialFrontImage: idImage,
          initialBackImage: null,
          onSubmitRegistration: ({
            required String idType,
            required File frontIdImage,
            required File backIdImage,
          }) async {
            setState(() {
              this.idType = idType;
              idImage = frontIdImage;
            });
            return _register(
              selectedIdType: idType,
              selectedFrontIdImage: frontIdImage,
              selectedBackIdImage: backIdImage,
            );
          },
        ),
      ),
    );
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
      hintStyle: TextStyle(
        color: hasError ? const Color(0xFFFF4D4F) : _hintColor,
        fontSize: 16,
      ),
      prefixStyle: TextStyle(
        color: hasError ? const Color(0xFFFF4D4F) : _fieldTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: ColorFiltered(
        colorFilter: ColorFilter.mode(
          hasError ? const Color(0xFFFF4D4F) : _fieldIconColor,
          BlendMode.srcIn,
        ),
        child: prefixIcon,
      ),
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
          width: 1.6,
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
          width: 1.6,
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
    double width = 22,
    double height = 22,
    EdgeInsetsGeometry padding = const EdgeInsets.only(left: 14, right: 12),
  }) {
    return Padding(
      padding: padding,
      child: SvgPicture.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          _fieldIconColor,
          BlendMode.srcIn,
        ),
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
                  border: Border.all(
                    color: borderColor,
                    width: 1.6,
                  ),
                ),
                child: Row(
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        hasError ? const Color(0xFFFF4D4F) : _fieldIconColor,
                        BlendMode.srcIn,
                      ),
                      child: icon,
                    ),
                    Expanded(
                      child: Text(
                        value ?? hint,
                        style: TextStyle(
                          color: hasError
                              ? const Color(0xFFFF4D4F)
                              : value == null
                                  ? const Color(0xFF9DA5AE)
                                  : const Color(0xFF2C2F32),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: hasError
                            ? const Color(0xFFFF4D4F)
                            : const Color(0xFF7E8796),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: isExpanded
                ? Padding(
                    key: const ValueKey('dropdown_open'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFD9DFE7),
                          width: 1.6,
                        ),
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
                  )
                : const SizedBox.shrink(key: ValueKey('dropdown_closed')),
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
            width: 35,
            height: 35,
            decoration: const BoxDecoration(
              color: _brandBlue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: _brandBlue,
              fontSize: 20,
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
        border: Border.all(
          color: const Color(0xFFE7EBF1),
          width: 2.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildBirthDateDropdown({
    required String fieldKey,
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    final isExpanded = _expandedDropdown == fieldKey;
    final isHovered = _hoveredDropdown == fieldKey;
    final borderColor = isExpanded
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
              borderRadius: BorderRadius.circular(12),
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
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isHovered || isExpanded
                      ? const Color(0xFFF1F3F6)
                      : _cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 1.6,
                  ),
                ),
                child: Row(
                  children: [
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
                  border: Border.all(
                    color: const Color(0xFFD9DFE7),
                    width: 1.6,
                  ),
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
                            horizontal: 14,
                            vertical: 13,
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
        ],
      ),
    );
  }

  Widget _buildBirthDateInputBox({
    required String hint,
    required int maxLength,
  }) {
    return TextField(
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: const TextStyle(
        color: _fieldTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9DA5AE),
          fontSize: 16,
        ),
        filled: true,
        fillColor: _cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Color(0xFFA7ADB6),
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: _brandBlue,
            width: 1.6,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  'Create Account',
                  textAlign: TextAlign.left,
                  style: GoogleFonts.publicSans(
                    color: _titleColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 40 / 36,
                    letterSpacing: -0.9,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(left: 20),
                child: SizedBox(
                  width: 300,
                  child: Text(
                    'Please provide your details for residency verification. This process ensures the security of our community portal.',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Color(0xFF424751),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _sectionPanelBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildSectionTitle(1, 'Personal Information'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fullNameController,
                      style: _fieldInputTextStyle('full_name'),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _setFieldError('full_name', null),
                      decoration: _fieldStyle(
                        'Juan Dela Cruz',
                        _assetFieldIcon(
                          'lib/assets/Juan Dela Cruz Satus Icon.svg',
                          width: 24,
                          height: 24,
                        ),
                        errorText: _errorFor('full_name'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Date of birth',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Day',
                                style: TextStyle(
                                  color: _fieldTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildBirthDateInputBox(
                                hint: 'DD',
                                maxLength: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Month',
                                style: TextStyle(
                                  color: _fieldTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildBirthDateInputBox(
                                hint: 'MM',
                                maxLength: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Year',
                                style: TextStyle(
                                  color: _fieldTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildBirthDateInputBox(
                                hint: 'YYYY',
                                maxLength: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contactController,
                      style: _fieldInputTextStyle('contact'),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        _PhilippineMobileFormatter(),
                      ],
                      onChanged: (_) => _setFieldError('contact', null),
                      decoration: _fieldStyle(
                        '912 345 6789',
                        _assetFieldIcon('lib/assets/Contact Number Icon.svg'),
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
                        width: 24,
                        height: 24,
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
                        width: 24,
                        height: 24,
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
                      style: _fieldInputTextStyle('address'),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _setFieldError('address', null),
                      decoration: _fieldStyle(
                        'Address',
                        _assetFieldIcon(
                          'lib/assets/MapPin.svg',
                          width: 24,
                          height: 24,
                        ),
                        errorText: _errorFor('address'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle(2, 'Account Details'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      style: _fieldInputTextStyle('email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _setFieldError('email', null),
                      decoration: _fieldStyle(
                        'Email',
                        _assetFieldIcon(
                          'lib/assets/Email Status Icon.svg',
                          width: 24,
                          height: 24,
                        ),
                        errorText: _errorFor('email'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      style: _fieldInputTextStyle('password'),
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _setFieldError('password', null),
                      decoration: _fieldStyle(
                        'Password',
                        _assetFieldIcon(
                          'lib/assets/Password Status Icon.svg',
                          width: 24,
                          height: 24,
                        ),
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
                            color: _errorFor('password') != null
                                ? const Color(0xFFFF4D4F)
                                : _fieldIconColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPasswordController,
                      style: _fieldInputTextStyle('confirm_password'),
                      obscureText: !_isConfirmPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _setFieldError('confirm_password', null),
                      onSubmitted: (_) => _continueToVerification(),
                      decoration: _fieldStyle(
                        'Confirm Password',
                        _assetFieldIcon(
                          'lib/assets/Password Status Icon.svg',
                          width: 24,
                          height: 24,
                        ),
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
                            color: _errorFor('confirm_password') != null
                                ? const Color(0xFFFF4D4F)
                                : _fieldIconColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _continueToVerification,
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
                                    'Continue to Verification',
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

class _PhilippineMobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.startsWith('63')) {
      digitsOnly = digitsOnly.substring(2);
    }
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    final formatted = _formatWithCountryCode(digitsOnly);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithCountryCode(String digits) {
    if (digits.isEmpty) return '';
    final grouped = _groupLocalNumber(digits);
    return '+63 $grouped';
  }

  String _groupLocalNumber(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
}
