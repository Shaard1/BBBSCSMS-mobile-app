import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../crop_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final String fullName;
  final String address;
  final String contactNumber;
  final String profileImageUrl;

  const EditProfileScreen({
    super.key,
    required this.fullName,
    required this.address,
    required this.contactNumber,
    required this.profileImageUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _brandBlue = Color(0xFF0B4F94);
  static const Color _pageBackground = Color(0xFFF4F6F7);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _fullNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactController;

  File? _newProfileImage;
  File? _newProfileImageOriginal;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.fullName);
    _addressController = TextEditingController(text: widget.address);
    _contactController = TextEditingController(text: widget.contactNumber);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text("Use Camera"),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _handlePickedProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _handlePickedProfileImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePickedProfileImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (picked == null) return;

      final imageBytes = await picked.readAsBytes();
      final originalImageFile = File(picked.path);

      if (!mounted) return;

      final cropped = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => CropScreen(
            imageBytes: imageBytes,
            sourcePath: picked.path,
          ),
        ),
      );

      if (cropped == null || !mounted) return;

      setState(() {
        _newProfileImageOriginal = originalImageFile;
        _newProfileImage = cropped;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image error: $e")),
      );
    }
  }

  Future<String> _uploadImage(File file, String path) async {
    await _supabase.storage.from('resident-files').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from('resident-files').getPublicUrl(path);
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final fullName = _fullNameController.text.trim();
    final address = _addressController.text.trim();
    final contactNumber = _contactController.text.trim();

    if (fullName.isEmpty || address.isEmpty || contactNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Please fill in your name, address, and contact number."),
        ),
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please log in again.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = <String, dynamic>{
        'full_name': fullName,
        'address': address,
        'contact_number': contactNumber,
      };

      if (_newProfileImage != null) {
        final croppedUrl = await _uploadImage(
          _newProfileImage!,
          "profile_images/${user.id}.png",
        );
        payload['profile_image'] = croppedUrl;
      }

      if (_newProfileImageOriginal != null) {
        final originalUrl = await _uploadImage(
          _newProfileImageOriginal!,
          "profile_images_original/${user.id}.png",
        );
        payload['profile_image_original'] = originalUrl;
      }

      try {
        await _supabase.from('residents').update(payload).eq('id', user.id);
      } catch (e) {
        if (payload.containsKey('profile_image_original') &&
            e.toString().contains('profile_image_original')) {
          final fallbackPayload = Map<String, dynamic>.from(payload)
            ..remove('profile_image_original');
          await _supabase
              .from('residents')
              .update(fallbackPayload)
              .eq('id', user.id);
        } else {
          rethrow;
        }
      }

      try {
        await _supabase.from('profiles').update({
          'full_name': fullName,
        }).eq('id', user.id);
      } catch (_) {
        // Best-effort sync only.
      }

      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': fullName,
            },
          ),
        );
      } catch (_) {
        // Non-blocking metadata sync.
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save profile: $e")),
      );
      setState(() => _isSaving = false);
      return;
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF8FA2B8),
        fontSize: 13,
      ),
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

  @override
  Widget build(BuildContext context) {
    final hasNetworkImage =
        widget.profileImageUrl.trim().isNotEmpty && _newProfileImage == null;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text("Edit Profile"),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Update your resident details and keep your profile information current.",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Profile Photo",
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 122,
                          height: 122,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFD7E5F5),
                              width: 3,
                            ),
                            image: _newProfileImage != null
                                ? DecorationImage(
                                    image: FileImage(_newProfileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : hasNetworkImage
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          widget.profileImageUrl,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (_newProfileImage == null && !hasNetworkImage)
                              ? const Icon(
                                  Icons.person,
                                  size: 58,
                                  color: Color(0xFFD0D6DC),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: _pickProfileImage,
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: _brandBlue,
                        ),
                        label: const Text(
                          "Change photo",
                          style: TextStyle(
                            color: _brandBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Personal Information",
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration("Full name"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.words,
                      maxLines: 2,
                      decoration: _fieldDecoration("Address"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDecoration("Contact number"),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(fontWeight: FontWeight.w700),
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
