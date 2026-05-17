import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'id_camera_capture_screen.dart';

typedef SubmitRegistrationCallback =
    Future<String?> Function({
      required String idType,
      required File frontIdImage,
      required File backIdImage,
    });

class RegisterVerificationScreen extends StatefulWidget {
  const RegisterVerificationScreen({
    super.key,
    required this.onSubmitRegistration,
    this.initialIdType,
    this.initialFrontImage,
    this.initialBackImage,
  });

  final SubmitRegistrationCallback onSubmitRegistration;
  final String? initialIdType;
  final File? initialFrontImage;
  final File? initialBackImage;

  @override
  State<RegisterVerificationScreen> createState() =>
      _RegisterVerificationScreenState();
}

class _RegisterVerificationScreenState extends State<RegisterVerificationScreen> {
  static const _brandBlue = Color(0xFF006CBF);
  static const _pageBackground = Color(0xFFF8FAFC);
  static const _borderColor = Color(0xFFE6E8ED);
  static const _fieldIconColor = Color(0xFF656A70);

  final _picker = ImagePicker();

  String? _idType;
  File? _frontIdImage;
  File? _backIdImage;
  String? _error;
  bool _isSubmitting = false;
  bool _idTypeExpanded = false;
  bool _idTypeHovered = false;

  @override
  void initState() {
    super.initState();
    _idType = widget.initialIdType;
    _frontIdImage = widget.initialFrontImage;
    _backIdImage = widget.initialBackImage;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickIdImage({required bool isFront}) async {
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
                final capturedFile = await Navigator.push<File?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IdCameraCaptureScreen(),
                  ),
                );
                if (capturedFile == null || !mounted) return;
                setState(() {
                  if (isFront) {
                    _frontIdImage = capturedFile;
                  } else {
                    _backIdImage = capturedFile;
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                );
                if (picked == null || !mounted) return;
                setState(() {
                  if (isFront) {
                    _frontIdImage = File(picked.path);
                  } else {
                    _backIdImage = File(picked.path);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubmittedDialog() async {
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
                    color: Color(0xFF64748B),
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
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
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

  Future<void> _completeVerification() async {
    if (_idType == null) {
      setState(() => _error = 'Please select your ID type.');
      return;
    }
    if (_frontIdImage == null || _backIdImage == null) {
      setState(() => _error = 'Please upload both front and back ID photos.');
      return;
    }

    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final submitError = await widget.onSubmitRegistration(
      idType: _idType!,
      frontIdImage: _frontIdImage!,
      backIdImage: _backIdImage!,
    );

    if (!mounted) return;

    if (submitError != null) {
      setState(() {
        _isSubmitting = false;
        _error = submitError;
      });
      return;
    }

    setState(() => _isSubmitting = false);
    await _showSubmittedDialog();
  }

  Widget _buildSectionTitle(int number, String title) {
    return Row(
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
    );
  }

  Widget _idPhotoTile({
    required String label,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF484D51),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor, width: 1.4),
            ),
            child: image == null
                ? const Center(
                    child: Icon(
                      Icons.credit_card,
                      size: 44,
                      color: Color(0xFFB3BBC7),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      image,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 34,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              label: Text(image == null ? 'Add Photo' : 'Retake'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdTypeDropdown() {
    const options = [
      'Barangay ID',
      'Student ID',
      'Postal ID',
      'Driver License',
      'PhilSys ID',
    ];

    final borderColor = _idTypeExpanded
        ? _brandBlue
        : _idTypeHovered
            ? const Color(0xFFD5D9E1)
            : _borderColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _idTypeHovered = true),
      onExit: (_) => setState(() => _idTypeHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _idTypeExpanded = !_idTypeExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: _idTypeHovered || _idTypeExpanded
                      ? const Color(0xFFF1F3F6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: _fieldIconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _idType ?? 'ID Type',
                        style: const TextStyle(
                          color: Color(0xFF484D51),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _idTypeExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF7E8796),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _idTypeExpanded
                ? Container(
                    key: const ValueKey('idtype_open'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD9DFE7), width: 1.4),
                    ),
                    child: Column(
                      children: options.map((option) {
                        final isSelected = option == _idType;
                        return Material(
                          color: isSelected
                              ? const Color(0xFFE5E7EB)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _idType = option;
                                _idTypeExpanded = false;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Text(
                                option,
                                style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idtype_closed')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0F2F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _buildSectionTitle(3, 'Verification'),
              const SizedBox(height: 12),
              const Text(
                'Take Photo of Your ID',
                style: TextStyle(
                  color: Color(0xFF11151A),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a clear photo of the front and back of your government ID.',
                style: TextStyle(
                  color: Color(0xFF424751),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _buildIdTypeDropdown(),
              const SizedBox(height: 14),
              _idPhotoTile(
                label: 'Front',
                image: _frontIdImage,
                onTap: () => _pickIdImage(isFront: true),
              ),
              const SizedBox(height: 14),
              _idPhotoTile(
                label: 'Back',
                image: _backIdImage,
                onTap: () => _pickIdImage(isFront: false),
              ),
              if (hasError) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _completeVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
