import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../crop_screen.dart';
import 'register_verification_screen.dart';
import '../../widgets/top_toast.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
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

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _birthDayController = TextEditingController();
  final _birthMonthController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _scrollController = ScrollController();

  final ImagePicker _picker = ImagePicker();

  String? gender;
  String? civilStatus;
  String? idType;
  String? birthMonth;
  String? birthDay;
  String? birthYear;

  File? idImage;
  File? _profileImage;
  File? _profileImageOriginal;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _expandedDropdown;
  String? _hoveredDropdown;
  final Map<String, String?> _fieldErrors = {};
  late final Map<String, AnimationController> _fieldShakeControllers;

  @override
  void initState() {
    super.initState();
    _fieldShakeControllers = {
      for (final fieldKey in [
        'full_name',
        'birth_day',
        'birth_month',
        'contact',
        'gender',
        'civil_status',
        'address',
        'email',
        'password',
        'confirm_password',
      ])
        fieldKey: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        ),
    };
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
    _scrollController.dispose();
    for (final controller in _fieldShakeControllers.values) {
      controller.dispose();
    }
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

  void _triggerFieldShake(String fieldKey) {
    final controller = _fieldShakeControllers[fieldKey];
    controller
      ?..stop()
      ..forward(from: 0);
  }

  Widget _buildShakingField(String fieldKey, Widget child) {
    final controller = _fieldShakeControllers[fieldKey];
    if (controller == null) return child;

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, animatedChild) {
        final offset = 6 * (1 - (controller.value - 0.5).abs() * 2);
        final direction =
                controller.value < 0.25 ||
                    (controller.value >= 0.5 && controller.value < 0.75)
            ? -1.0
            : 1.0;
        return Transform.translate(
          offset: Offset(offset * direction, 0),
          child: animatedChild,
        );
      },
    );
  }

  void _handleBirthDateChanged(String fieldKey, String value) {
    if (fieldKey == 'birth_day') {
      birthDay = value.trim().isEmpty ? null : value.trim();
      final parsedDay = int.tryParse(value);

      if (value.isEmpty) {
        _setFieldError(fieldKey, null);
        return;
      }

      if (parsedDay == null || parsedDay < 1 || parsedDay > 31) {
        _setFieldError(fieldKey, 'Use 1-31.');
        _triggerFieldShake(fieldKey);
        return;
      }

      _setFieldError(fieldKey, null);
      return;
    }

    if (fieldKey == 'birth_month') {
      birthMonth = value.trim().isEmpty ? null : value.trim();
      final parsedMonth = int.tryParse(value);

      if (value.isEmpty) {
        _setFieldError(fieldKey, null);
        return;
      }

      if (parsedMonth == null || parsedMonth < 1 || parsedMonth > 12) {
        _setFieldError(fieldKey, 'Use 1-12.');
        _triggerFieldShake(fieldKey);
        return;
      }

      _setFieldError(fieldKey, null);
      return;
    }

    birthYear = value.trim().isEmpty ? null : value.trim();
  }

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

  String _registrationErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (_isNetworkError(error)) {
      return 'No internet connection. Please try again.';
    }

    if (message.contains('over_email_send_rate_limit')) {
      return 'Please wait a few seconds before trying again. Supabase is temporarily limiting confirmation emails.';
    }

    if (message.contains('email_provider_disabled')) {
      return 'Email/password signup is disabled in Supabase. Enable the Email provider, but keep email confirmation turned off.';
    }

    if (message.contains('email confirmation is still enabled')) {
      return 'Email confirmation is still enabled in Supabase. Turn it off so residents can submit their ID for barangay approval.';
    }

    if (message.contains('email not confirmed') ||
        message.contains('confirm your email')) {
      return 'Please confirm your email first, then log in to complete registration.';
    }

    if (message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('user already registered')) {
      return 'This email is already registered. Please log in or use another email.';
    }

    return 'Registration failed. Please check your details and try again.';
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

    for (final fieldKey in nextErrors.keys) {
      _triggerFieldShake(fieldKey);
    }

    return nextErrors.isEmpty;
  }

  String? _buildBirthdateValue() {
    final dayText = _birthDayController.text.trim();
    final monthText = _birthMonthController.text.trim();
    final yearText = _birthYearController.text.trim();

    if (dayText.isEmpty || monthText.isEmpty || yearText.isEmpty) {
      return null;
    }

    final day = int.tryParse(dayText);
    final month = int.tryParse(monthText);
    final year = int.tryParse(yearText);

    if (day == null || month == null || year == null) {
      return null;
    }

    if (day < 1 || day > 31 || month < 1 || month > 12 || yearText.length != 4) {
      return null;
    }

    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickProfileImage() async {
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
                await _handleProfileImageSelection(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _handleProfileImageSelection(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProfileImageSelection(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      final originalFile = File(picked.path);
      final originalBytes = await originalFile.readAsBytes();
      if (!mounted) return;
      final croppedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => CropScreen(
            imageBytes: originalBytes,
            sourcePath: originalFile.path,
          ),
        ),
      );

      if (croppedFile == null || !mounted) return;

      setState(() {
        _profileImage = croppedFile;
        _profileImageOriginal = originalFile;
      });
    } catch (e) {
      _showSnackBar('Image error: $e');
    }
  }

  Future<String?> uploadImage(File file, String path) async {
    final storage = Supabase.instance.client.storage;
    final uploadFile = await _compressImageForUpload(file);

    await storage.from('resident-files').upload(
          path,
          uploadFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

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

      if (authResponse.session == null ||
          Supabase.instance.client.auth.currentSession == null) {
        throw Exception(
          'Email confirmation is still enabled in Supabase. Turn it off so residents can submit their ID for barangay approval.',
        );
      }

      final idImageFrontUrl = await uploadImage(
        selectedFrontIdImage,
        '${user.id}/id_images/front.jpg',
      );
      final idImageBackUrl = await uploadImage(
        selectedBackIdImage,
        '${user.id}/id_images/back.jpg',
      );
      final birthdateValue = _buildBirthdateValue();
      String? profileImageUrl;
      String? profileImageOriginalUrl;

      if (_profileImage != null) {
        profileImageUrl = await uploadImage(
          _profileImage!,
          '${user.id}/profile_images/profile.png',
        );
      }

      if (_profileImageOriginal != null) {
        profileImageOriginalUrl = await uploadImage(
          _profileImageOriginal!,
          '${user.id}/profile_images_original/profile.png',
        );
      }

      final residentPayload = <String, dynamic>{
        'id': user.id,
        'user_id': user.id,
        'email': _emailController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'birthdate': birthdateValue,
        'birth_day': _birthDayController.text.trim().isEmpty
            ? null
            : _birthDayController.text.trim(),
        'birth_month': _birthMonthController.text.trim().isEmpty
            ? null
            : _birthMonthController.text.trim(),
        'birth_year': _birthYearController.text.trim().isEmpty
            ? null
            : _birthYearController.text.trim(),
        'gender': gender!,
        'address': _addressController.text.trim(),
        'contact_number': _normalizedContactNumber(),
        'civil_status': civilStatus!,
        'id_type': selectedIdType,
        'id_image': idImageFrontUrl,
        'id_image_front': idImageFrontUrl,
        'id_image_back': idImageBackUrl,
        'profile_image': profileImageUrl,
        'profile_image_original': profileImageOriginalUrl,
        'status': 'pending',
      };

      try {
        await Supabase.instance.client.from('residents').insert(residentPayload);
      } catch (insertError) {
        // Backward-compat: if new columns are not migrated yet, fall back
        // to legacy single-image payload so registration can still continue.
        final message = insertError.toString().toLowerCase();
        final missingNewColumns =
            message.contains('email') ||
            message.contains('birth_day') ||
            message.contains('birth_month') ||
            message.contains('birth_year') ||
            message.contains('id_image_front') ||
            message.contains('id_image_back') ||
            message.contains('profile_image_original') ||
            message.contains('column') && message.contains('does not exist');

        if (!missingNewColumns) rethrow;

        final legacyPayload = <String, dynamic>{
          'id': user.id,
          'user_id': user.id,
          'email': _emailController.text.trim(),
          'full_name': _fullNameController.text.trim(),
          'birthdate': birthdateValue,
          'gender': gender!,
          'address': _addressController.text.trim(),
          'contact_number': _normalizedContactNumber(),
          'civil_status': civilStatus!,
          'id_type': selectedIdType,
          'id_image': idImageFrontUrl,
          'profile_image': profileImageUrl,
          'status': 'pending',
        };
        if (message.contains('email')) {
          legacyPayload.remove('email');
        }
        if (message.contains('birth_day')) {
          legacyPayload.remove('birth_day');
        }
        if (message.contains('birth_month')) {
          legacyPayload.remove('birth_month');
        }
        if (message.contains('birth_year')) {
          legacyPayload.remove('birth_year');
        }
        if (message.contains('profile_image_original')) {
          legacyPayload.remove('profile_image_original');
        }
        await Supabase.instance.client.from('residents').insert(legacyPayload);
      }

      return null;
    } catch (e) {
      return _registrationErrorMessage(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    bool hasError = false,
  }) {
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
    );
  }

  Widget _buildFieldWithReservedError({
    required String fieldKey,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        _buildFieldError(fieldKey),
      ],
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

    return _buildShakingField(
      fieldKey,
      MouseRegion(
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
          SizedBox(
            height: 24,
            child: hasError
                ? Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: Color(0xFFFF4D4F),
                        fontSize: 12,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    ));
  }

  Widget _buildFieldError(String fieldKey) {
    final errorText = _errorFor(fieldKey);
    return SizedBox(
      height: 24,
      child: errorText == null || errorText.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                errorText,
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 12,
                ),
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

  Widget _buildBirthDateInputBox({
    required String fieldKey,
    required TextEditingController controller,
    required String hint,
    required int maxLength,
  }) {
    final hasError = _errorFor(fieldKey) != null;
    Widget input = TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (value) => _handleBirthDateChanged(fieldKey, value),
      style: TextStyle(
        color: hasError ? const Color(0xFFFF4D4F) : _fieldTextColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          color: hasError ? const Color(0xFFFF4D4F) : const Color(0xFF9DA5AE),
          fontSize: 16,
        ),
        filled: true,
        fillColor: _cardBackground,
        contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
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
      ),
    );
    return _buildShakingField(fieldKey, input);
  }

  Widget _buildProfilePhotoPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF3F7FB),
              border: Border.all(
                color: const Color(0xFFD8E3F0),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
              image: _profileImage != null
                  ? DecorationImage(
                      image: FileImage(_profileImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _profileImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 42,
                        color: _brandBlue,
                      ),
                      SizedBox(height: 6),
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 18,
                        color: Color(0xFF6B7C93),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: _brandBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _profileImage == null ? 'Add profile photo' : 'Change profile photo',
          style: const TextStyle(
            color: _brandBlue,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2C2F32),
          fontSize: 16,
          fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 6),
                    _buildProfilePhotoPicker(),
                    const SizedBox(height: 18),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Full name'),
                    const SizedBox(height: 6),
                    _buildFieldWithReservedError(
                      fieldKey: 'full_name',
                      child: _buildShakingField(
                        'full_name',
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
                            hasError: _errorFor('full_name') != null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Date of birth'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text(
                                'Day',
                                style: TextStyle(
                                  color: _fieldTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildBirthDateInputBox(
                                fieldKey: 'birth_day',
                                controller: _birthDayController,
                                hint: 'DD',
                                maxLength: 2,
                              ),
                              _buildFieldError('birth_day'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text(
                                'Month',
                                style: TextStyle(
                                  color: _fieldTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildBirthDateInputBox(
                                fieldKey: 'birth_month',
                                controller: _birthMonthController,
                                hint: 'MM',
                                maxLength: 2,
                              ),
                              _buildFieldError('birth_month'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text(
                                'Year',
                                style: TextStyle(
                                  color: _fieldTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildBirthDateInputBox(
                                fieldKey: 'birth_year',
                                controller: _birthYearController,
                                hint: 'YYYY',
                                maxLength: 4,
                              ),
                              _buildFieldError('birth_year'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Contact number'),
                    const SizedBox(height: 6),
                    _buildFieldWithReservedError(
                      fieldKey: 'contact',
                      child: _buildShakingField(
                        'contact',
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
                            _assetFieldIcon(
                              'lib/assets/Contact Number Icon.svg',
                            ),
                            hasError: _errorFor('contact') != null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Gender'),
                    const SizedBox(height: 6),
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
                    _buildFieldLabel('Civil status'),
                    const SizedBox(height: 6),
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
                    _buildFieldLabel('Address'),
                    const SizedBox(height: 6),
                    _buildFieldWithReservedError(
                      fieldKey: 'address',
                      child: _buildShakingField(
                        'address',
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
                            hasError: _errorFor('address') != null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle(2, 'Account Details'),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Email'),
                    const SizedBox(height: 6),
                    _buildFieldWithReservedError(
                      fieldKey: 'email',
                      child: _buildShakingField(
                        'email',
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
                            hasError: _errorFor('email') != null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Password'),
                    const SizedBox(height: 6),
                    _buildFieldWithReservedError(
                      fieldKey: 'password',
                      child: _buildShakingField(
                        'password',
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
                            hasError: _errorFor('password') != null,
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
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldLabel('Confirm password'),
                    const SizedBox(height: 6),
                    _buildFieldWithReservedError(
                      fieldKey: 'confirm_password',
                      child: _buildShakingField(
                        'confirm_password',
                        TextField(
                          controller: _confirmPasswordController,
                          style: _fieldInputTextStyle('confirm_password'),
                          obscureText: !_isConfirmPasswordVisible,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) =>
                              _setFieldError('confirm_password', null),
                          onSubmitted: (_) => _continueToVerification(),
                          decoration: _fieldStyle(
                            'Confirm Password',
                            _assetFieldIcon(
                              'lib/assets/Password Status Icon.svg',
                              width: 24,
                              height: 24,
                            ),
                            hasError: _errorFor('confirm_password') != null,
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
