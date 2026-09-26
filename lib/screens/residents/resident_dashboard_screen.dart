import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/announcement_model.dart';
import '../../services/announcement_service.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/app_selection_field.dart';
import '../../widgets/app_tap_surface.dart';
import '../../widgets/app_status_message.dart';
import '../../widgets/app_content_switcher.dart';
import '../../core/app_interactions.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';
import 'report_location_picker_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  final String name;
  final int initialTabIndex;

  const ResidentDashboardScreen({
    super.key,
    required this.name,
    this.initialTabIndex = 0,
  });

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _AnnouncementSegment {
  final String text;
  final Map<String, dynamic> attributes;

  const _AnnouncementSegment({
    required this.text,
    required this.attributes,
  });
}

class _AnnouncementLine {
  final List<_AnnouncementSegment> segments;
  final String? align;

  const _AnnouncementLine({
    required this.segments,
    this.align,
  });
}

enum _ResidentServiceView {
  menu,
  reportForm,
  certificates,
  certificateRequestForm,
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  static const String _verifiedShieldAsset =
      'lib/assets/Verified Resident badge.svg';
  static const String _verifiedCheckAsset =
      'lib/assets/Verified check badge.svg';
  static const String _demoGcashReceiverName = 'Demo GCash Receiver';
  static const String _demoGcashReceiverNumber = '09XXXXXXXXX';
  final SupabaseClient _supabase = Supabase.instance.client;
  final AnnouncementService _announcementService = AnnouncementService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  final Map<String, TextEditingController> _certificateControllers = {
    for (final key in [
      'full_name',
      'address',
      'contact_number',
      'email',
      'payment_reference',
      'date_of_birth',
      'civil_status',
      'purpose',
      'additional_notes',
      'institution_agency',
      'reason_for_request',
      'length_of_stay',
      'loan_purpose',
      'lending_company',
      'loan_amount',
      'gender',
      'occupation',
      'emergency_contact_name',
      'emergency_contact_number',
      'certification_details',
      'requesting_party',
      'business_name',
      'business_address',
      'business_type',
      'years_of_operation',
      'operator_name',
      'plate_number',
      'route_area',
      'banca_name',
      'banca_registration_number',
      'operation_area',
    ])
      key: TextEditingController(),
  };

  static const int _minAnnouncementFontSize = 1;
  static const int _maxAnnouncementFontSize = 144;
  static const Color _brandBlue = Color(0xFF0B4F94);
  static const Color _gold = Color(0xFFF1A400);
  static const Color _softBlue = Color(0xFFEAF3FF);
  static const Color _pageBackground = Color(0xFFF8F9FA);
  static const double _pageHorizontalPadding = 16;
  static const double _topBarTopPadding = 18;
  static const double _topActionSize = 48;
  static const double _bottomNavIconSize = 31;

  final List<String> _categories = const [
    "Road Damage",
    "Garbage Collection",
    "Broken Streetlight",
    "Drainage Issue",
    "Noise Complaint",
    "Others",
  ];

  int _currentTab = 0;
  String? _selectedCategory;
  _ResidentServiceView _serviceView = _ResidentServiceView.menu;

  bool _isLoadingReports = true;
  bool _reportsLoadFailed = false;
  bool _documentsLoadFailed = false;
  bool _announcementsLoadFailed = false;
  bool _isLoadingAnnouncements = true;
  bool _isSubmittingReport = false;
  bool _isSubmittingCertificateRequest = false;
  bool _isFetchingLocation = false;
  bool _notifyAnnouncements = true;
  bool _notifyReportUpdates = true;
  bool _notifyDocumentUpdates = true;
  String _selectedAnnouncementFilter = "All";

  String _fullName = "";
  String _address = "Address not set";
  String _contactNumber = "No contact number";
  String _profileImage = "";
  String _reportLocationLabel = "Tap to choose location on map";
  Map<String, dynamic>? _selectedCertificateRequest;
  String _selectedCertificatePaymentMethod = "GCash";
  String _selectedCertificateVariant = "Good Moral";
  File? _selectedPaymentProofImage;

  static const int _maxReportImages = 10;
  final List<File> _selectedReportImages = [];
  double? _reportLatitude;
  double? _reportLongitude;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _documentRequests = [];
  List<Announcement> _announcements = [];
  Set<String> _readAnnouncementIds = {};
  Map<String, String> _announcementAuthorNames = {};

  int get _unreadAnnouncementCount => _announcements
      .where((announcement) => !_readAnnouncementIds.contains(announcement.id))
      .length;

  List<Map<String, dynamic>> get _certificateOptions => const [
        {
          'key': 'certificate_of_indigency',
          'title': 'Certificate of Indigency',
          'description': 'For social welfare services',
          'fee': 'Free',
          'icon': Icons.volunteer_activism_outlined,
          'accent': Color(0xFFFF6B81),
          'background': Color(0xFFFFEFF3),
        },
        {
          'key': 'good_moral_residency',
          'title': 'Good Moral / Residency',
          'description': 'Proof of residency or standing',
          'fee': 'Fee: \u20B1100',
          'icon': Icons.home_outlined,
          'accent': Color(0xFFE3B317),
          'background': Color(0xFFFFF6D9),
        },
        {
          'key': 'barangay_clearance_for_loan',
          'title': 'Barangay Clearance For Loan',
          'description': 'Required for loan applications.',
          'fee': 'Fee: \u20B1150',
          'icon': Icons.description_outlined,
          'accent': Color(0xFF4A90E2),
          'background': Color(0xFFEAF3FF),
        },
        {
          'key': 'barangay_id',
          'title': 'Barangay ID',
          'description': 'Official resident identification.',
          'fee': 'Fee: \u20B1100',
          'icon': Icons.badge_outlined,
          'accent': Color(0xFF6C63FF),
          'background': Color(0xFFF0EEFF),
        },
        {
          'key': 'special_certification',
          'title': 'Special Certification',
          'description': 'For special legal or personal purposes.',
          'fee': 'Fee: \u20B1100',
          'icon': Icons.fact_check_outlined,
          'accent': Color(0xFF9B6BDA),
          'background': Color(0xFFF5ECFF),
        },
        {
          'key': 'store_business_clearance',
          'title': 'Store Business Clearance',
          'description': 'Permit for sari-sari store operation.',
          'fee': 'Fee: \u20B1500',
          'icon': Icons.storefront_outlined,
          'accent': Color(0xFF32B768),
          'background': Color(0xFFE9F9EF),
        },
        {
          'key': 'tricycle_clearance',
          'title': 'Tricycle Clearance',
          'description': 'Permit for tricycle business operation.',
          'fee': 'Fee: \u20B1300',
          'icon': Icons.pedal_bike_outlined,
          'accent': Color(0xFFF5A623),
          'background': Color(0xFFFFF2DE),
        },
        {
          'key': 'banca_clearance',
          'title': 'Banca Clearance',
          'description': 'Permit for banca business operation.',
          'fee': 'Fee: \u20B1300',
          'icon': Icons.sailing_outlined,
          'accent': Color(0xFF31B7AE),
          'background': Color(0xFFE6FBF8),
        },
      ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
    _fullName = widget.name.trim();
    _loadResidentProfile();
    _fetchResidentActivity();
    _fetchAnnouncements();
  }

  @override
  void dispose() {
    TopToast.dismiss();
    _descriptionController.dispose();
    for (final controller in _certificateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadResidentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final data = await _supabase
          .from('residents')
          .select('full_name, address, contact_number, profile_image')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) return;

      setState(() {
        _fullName = (data['full_name'] as String?)?.trim().isNotEmpty == true
            ? data['full_name']
            : _fullName;
        _address = (data['address'] as String?)?.trim().isNotEmpty == true
            ? data['address']
            : _address;
        _contactNumber =
            (data['contact_number'] as String?)?.trim().isNotEmpty == true
                ? data['contact_number']
                : _contactNumber;
        _profileImage = (data['profile_image'] as String?) ?? "";
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _fetchAnnouncements() async {
    final user = _supabase.auth.currentUser;

    try {
      final announcements =
          await _announcementService.fetchPublishedAnnouncements();
      Set<String> readIds = _readAnnouncementIds;
      Map<String, String> authorNames = _announcementAuthorNames;

      try {
        authorNames = await _announcementService.fetchAuthorNamesByIds(
          announcements.map((item) => item.createdBy).toList(),
        );
      } catch (_) {}

      if (user != null) {
        try {
          readIds =
              await _announcementService.fetchReadAnnouncementIds(user.id);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _announcementsLoadFailed = false;
        _announcements = announcements;
        _readAnnouncementIds = readIds;
        _announcementAuthorNames = authorNames;
        _isLoadingAnnouncements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _announcementsLoadFailed = true;
        _isLoadingAnnouncements = false;
      });
    }
  }

  String _announcementCreatorLabel(Announcement announcement) {
    final storedName = announcement.createdByName.trim();
    if (storedName.isNotEmpty) {
      return "By: $storedName";
    }
    final creatorId = announcement.createdBy.trim();
    final creatorName = _announcementAuthorNames[creatorId]?.trim() ?? '';
    if (creatorName.isNotEmpty) {
      return "By: $creatorName";
    }
    return "By: Barangay Admin";
  }

  Future<void> _markAnnouncementsRead(List<String> announcementIds) async {
    final user = _supabase.auth.currentUser;
    if (user == null || announcementIds.isEmpty) return;

    final unreadIds = announcementIds
        .where((id) => !_readAnnouncementIds.contains(id))
        .toList();
    if (unreadIds.isEmpty) return;

    try {
      await _announcementService.markAnnouncementsRead(
        userId: user.id,
        announcementIds: unreadIds,
      );

      if (!mounted) return;
      setState(() {
        _readAnnouncementIds = {..._readAnnouncementIds, ...unreadIds};
      });
    } catch (_) {}
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          fullName: _fullName,
          address: _address == "Address not set" ? "" : _address,
          contactNumber:
              _contactNumber == "No contact number" ? "" : _contactNumber,
          profileImageUrl: _profileImage,
        ),
      ),
    );

    if (updated == true) {
      await _loadResidentProfile();

      if (!mounted) return;
      _showSnackBar("Profile updated successfully.");
    }
  }

  Future<void> _openPrivacySecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacySecurityScreen(),
      ),
    );
  }

  Future<void> _fetchResidentActivity() async {
    if (mounted) {
      setState(() => _isLoadingReports = true);
    }

    await Future.wait([
      _fetchMyReports(),
      _fetchMyDocumentRequests(),
    ]);

    if (!mounted) return;
    setState(() => _isLoadingReports = false);
  }

  Future<void> _fetchMyReports() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _reports = [];
      });
      return;
    }

    try {
      final data = await _supabase
          .from('reports')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _reportsLoadFailed = false;
        _reports = List<Map<String, dynamic>>.from(data).map((report) {
          return {
            ...report,
            'activity_type': 'report',
          };
        }).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reportsLoadFailed = true);
    }
  }

  Future<void> _fetchMyDocumentRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _documentRequests = [];
      });
      return;
    }

    try {
      final data = await _supabase
          .from('document_requests')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _documentsLoadFailed = false;
        _documentRequests =
            List<Map<String, dynamic>>.from(data).map((request) {
          return {
            ...request,
            'activity_type': 'document_request',
          };
        }).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _documentsLoadFailed = true);
    }
  }

  Future<void> _pickReportImage(ImageSource source) async {
    if (_selectedReportImages.length >= _maxReportImages) {
      _showSnackBar("You can upload up to $_maxReportImages images only.");
      return;
    }

    if (source == ImageSource.gallery) {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 75);
      if (pickedFiles.isEmpty) return;
      _appendPickedReportImages(pickedFiles);
      return;
    }

    final picked = await _picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;
    _appendPickedReportImages([picked]);
  }

  void _appendPickedReportImages(List<XFile> pickedFiles) {
    final remainingSlots = _maxReportImages - _selectedReportImages.length;
    if (remainingSlots <= 0) {
      _showSnackBar("You can upload up to $_maxReportImages images only.");
      return;
    }

    final filesToAdd = pickedFiles
        .take(remainingSlots)
        .map((picked) => File(picked.path))
        .toList();

    if (filesToAdd.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _selectedReportImages.addAll(filesToAdd);
    });

    final skippedCount = pickedFiles.length - filesToAdd.length;
    if (skippedCount > 0) {
      _showSnackBar(
        "$skippedCount image(s) not added. Max is $_maxReportImages images.",
      );
    }
  }

  void _removeSelectedReportImage(int index) {
    if (index < 0 || index >= _selectedReportImages.length) return;
    setState(() {
      _selectedReportImages.removeAt(index);
    });
  }

  Future<String?> _uploadReportImage(File imageFile) async {
    try {
      final fileName = path.basename(imageFile.path);
      final userId = _supabase.auth.currentUser!.id;
      final filePath =
          "$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName";

      await _supabase.storage.from('report-images').upload(filePath, imageFile);
      return _supabase.storage.from('report-images').getPublicUrl(filePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      _showSnackBar("Please choose an issue category.");
      return;
    }

    if (_descriptionController.text.trim().isEmpty ||
        _selectedReportImages.isEmpty) {
      _showSnackBar("Please add a description and at least one photo.");
      return;
    }

    if (_reportLatitude == null || _reportLongitude == null) {
      _showSnackBar("Please set report location on the map.");
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar("Session expired. Please log in again.");
      return;
    }

    setState(() => _isSubmittingReport = true);

    try {
      final imageUrls = <String>[];
      for (final image in _selectedReportImages) {
        final imageUrl = await _uploadReportImage(image);
        if (imageUrl == null) {
          throw Exception("Image upload failed");
        }
        imageUrls.add(imageUrl);
      }

      final payload = {
        'user_id': user.id,
        'description': _descriptionController.text.trim(),
        'image_url': imageUrls.first,
        'image_urls': imageUrls,
        'category': _selectedCategory,
        'latitude': _reportLatitude,
        'longitude': _reportLongitude,
        'status': 'pending',
      };

      try {
        await _supabase.from('reports').insert(payload);
      } catch (e) {
        if (e.toString().contains('image_urls')) {
          final fallbackPayload = Map<String, dynamic>.from(payload)
            ..remove('image_urls');
          await _supabase.from('reports').insert(fallbackPayload);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      setState(() {
        _isSubmittingReport = false;
        _descriptionController.clear();
        _selectedReportImages.clear();
        _selectedCategory = null;
        _reportLatitude = null;
        _reportLongitude = null;
        _reportLocationLabel = "Tap to choose location on map";
        _currentTab = 2;
        _serviceView = _ResidentServiceView.menu;
      });

      await _fetchResidentActivity();
      _showSnackBar("Report submitted successfully.");
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmittingReport = false);
      _showSnackBar("Failed to submit report. Please try again.");
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Log out?"),
          content: const Text(
            "Are you sure you want to log out of your account?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9534F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Log out"),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await _supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  String _formatCoordinates(double latitude, double longitude) {
    return "Lat ${latitude.toStringAsFixed(6)}, Lng ${longitude.toStringAsFixed(6)}";
  }

  Future<void> _captureCurrentLocation() async {
    if (_isFetchingLocation) return;

    setState(() => _isFetchingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Location service is disabled. Please enable GPS.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showSnackBar("Location permission denied.");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
            "Location permission denied forever. Enable it in settings.");
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (!mounted) return;
      setState(() {
        _reportLatitude = position.latitude;
        _reportLongitude = position.longitude;
        _reportLocationLabel =
            _formatCoordinates(position.latitude, position.longitude);
      });
      _showSnackBar("Current location captured.");
    } catch (_) {
      _showSnackBar("Failed to get location. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportLocationPickerScreen(
          initialLatitude: _reportLatitude,
          initialLongitude: _reportLongitude,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final latitude = result['latitude'];
    final longitude = result['longitude'];
    if (latitude == null || longitude == null) return;

    setState(() {
      _reportLatitude = latitude;
      _reportLongitude = longitude;
      _reportLocationLabel = _formatCoordinates(latitude, longitude);
    });
    _showSnackBar("Location pinned on map.");
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    TopToast.show(context, message, backgroundColor: _brandBlue);
  }

  Future<void> _runAction(
    FutureOr<void> Function() action,
  ) async {
    if (!mounted) return;
    await action();
  }

  String _statusLabel(String status) {
    final normalized = status.toLowerCase();
    if (normalized == "awaiting_payment") return "Awaiting Payment";
    if (normalized == "ready_for_release") return "Ready for Release";
    if (normalized == "rejected") return "Rejected";
    if (normalized == "in_process" || normalized == "in progress") {
      return "In Progress";
    }
    if (normalized == "processing") return "Processing";
    if (normalized == "completed") return "Completed";
    if (normalized == "resolved") return "Resolved";
    return "Pending";
  }

  ({Color bg, Color text}) _statusChipStyle(String status) {
    final normalizedStatus = status.toLowerCase();
    if (normalizedStatus == "completed" || normalizedStatus == "resolved") {
      return (
        bg: const Color(0xFFD1FAE5),
        text: const Color(0xFF065F46),
      );
    }
    if (normalizedStatus == "rejected") {
      return (
        bg: const Color(0xFFFEE2E2),
        text: const Color(0xFFB91C1C),
      );
    }
    if (normalizedStatus == "in_process" ||
        normalizedStatus == "in progress" ||
        normalizedStatus == "processing" ||
        normalizedStatus == "ready_for_release") {
      return (
        bg: const Color(0xFFDBEAFE),
        text: const Color(0xFF1E40AF),
      );
    }
    if (normalizedStatus == "awaiting_payment") {
      return (
        bg: const Color(0xFFEDE9FE),
        text: const Color(0xFF6D28D9),
      );
    }
    return (
      bg: const Color(0xFFFEF3C7),
      text: const Color(0xFFD79321),
    );
  }

  String _formatDetailedReportDate(String? rawValue) {
    final parsed = rawValue == null ? null : DateTime.tryParse(rawValue);
    if (parsed == null) return "Unknown date";
    final local = parsed.toLocal();
    const monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${monthNames[local.month - 1]} ${local.day}, ${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }

  List<String> _extractReportImages(Map<String, dynamic> report) {
    final urls = <String>[];

    void addUrl(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        urls.add(text);
      }
    }

    addUrl(report['image_url']);

    final raw = report['image_urls'];
    if (raw is List) {
      for (final item in raw) {
        addUrl(item);
      }
    } else if (raw is String) {
      final text = raw.trim();
      if (text.startsWith('[') && text.endsWith(']')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            for (final item in decoded) {
              addUrl(item);
            }
          }
        } catch (_) {
          addUrl(raw);
        }
      } else {
        addUrl(raw);
      }
    }

    return urls.toSet().toList();
  }

  Future<void> _showReportLocationDialog(Map<String, dynamic> report) async {
    final latitude = (report['latitude'] as num?)?.toDouble();
    final longitude = (report['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;

    final point = LatLng(latitude, longitude);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Report Location",
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF374151),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                  child: Text(
                    _formatCoordinates(latitude, longitude),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 16,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName:
                                'com.example.barangay_mobile_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 44,
                                height: 44,
                                point: point,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Future<void> _showReportDetails(Map<String, dynamic> report) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _buildReportDetailsPage(report),
      ),
    );
  }

  Future<void> _showDocumentRequestDetails(Map<String, dynamic> request) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _buildDocumentRequestDetailsPage(request),
      ),
    );
  }

  Widget _buildReportDetailsPage(Map<String, dynamic> report) {
    final images = _extractReportImages(report);
    final latitude = (report['latitude'] as num?)?.toDouble();
    final longitude = (report['longitude'] as num?)?.toDouble();
    final category = (report['category']?.toString().trim().isNotEmpty ?? false)
        ? report['category'].toString()
        : "Others";
    final description =
        (report['description']?.toString().trim().isNotEmpty ?? false)
            ? report['description'].toString().trim()
            : "No description provided.";
    final adminNote = report['admin_note']?.toString().trim() ?? '';
    final status = _statusLabel(report['status']?.toString() ?? 'pending');
    final createdAt = report['created_at']?.toString();
    final isDocumentRequest = _isDocumentRequestCategory(category);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF0B4F94),
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Report Details",
                  style: TextStyle(
                    color: Color(0xFF0B4F94),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildReportDetailsHeroImage(
              imageUrl: images.isEmpty ? null : images.first,
              imageUrls: images,
              status: status,
            ),
            if (images.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return AppTapSurface(
                      onTap: () => _showSwipeImageGallery(
                        images,
                        initialIndex: index,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          images[index],
                          width: 82,
                          height: 62,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                _buildReportDetailsMetaChip(
                  icon: Icons.construction_rounded,
                  label: category,
                ),
                const SizedBox(width: 14),
                _buildReportDetailsMetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: _formatReportDateOnly(createdAt),
                  filled: false,
                ),
                if (!isDocumentRequest && latitude != null && longitude != null)
                  const Spacer(),
                if (!isDocumentRequest && latitude != null && longitude != null)
                  InkWell(
                    onTap: () => _showReportLocationDialog(report),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Color(0xFF0B4F94),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "See location",
                            style: TextStyle(
                              color: Color(0xFF0B4F94),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _reportDetailsTitle(category),
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _reportDetailsDescription(description),
              style: const TextStyle(
                color: Color(0xFF424751),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (adminNote.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildResidentStaffNoteCard(adminNote),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportDetailsHeroImage({
    required String? imageUrl,
    required List<String> imageUrls,
    required String status,
  }) {
    return AppTapSurface(
      onTap: imageUrl == null
          ? null
          : () => _showSwipeImageGallery(
                imageUrls,
                initialIndex: 0,
              ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(46),
          bottomLeft: Radius.circular(46),
          bottomRight: Radius.circular(20),
        ),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 224,
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 44,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 44,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _buildReportDetailsStatusPill(status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDetailsStatusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE7BD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetailsMetaChip({
    required IconData icon,
    required String label,
    bool filled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFE7E8E9) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF424751)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF424751),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _reportDetailsTitle(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains("road") || normalized.contains("pothole")) {
      return "Severe Pothole near\nIntersection";
    }
    return category;
  }

  bool _isDocumentRequestCategory(String category) {
    final text = category.toLowerCase();
    return text.contains("certificate") ||
        text.contains("clearance") ||
        text.contains("residency") ||
        text.contains("document");
  }

  String _reportDetailsDescription(String description) {
    if (description == "No description provided.") {
      return "No additional description was provided.";
    }
    return description;
  }

  Widget _buildResidentStaffNoteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.edit_note_rounded,
                color: _brandBlue,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                "Staff Note",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReportDateOnly(String? rawValue) {
    final parsed = rawValue == null ? null : DateTime.tryParse(rawValue);
    if (parsed == null) return "Unknown date";
    final local = parsed.toLocal();
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${months[local.month - 1]} ${local.day}, ${local.year}";
  }

  String _formatAnnouncementDate(DateTime value) {
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${months[local.month - 1]} ${local.day}, ${local.year}";
  }

  List<_AnnouncementLine> _parseAnnouncementLines(String rawContent) {
    final trimmed = rawContent.trim();
    final ops = <Map<String, dynamic>>[];

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              ops.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {}
    }

    if (ops.isNotEmpty) {
      return _buildAnnouncementLinesFromOps(ops);
    }

    if (trimmed.contains('<') && trimmed.contains('>')) {
      return _parseHtmlAnnouncementLines(rawContent);
    }

    return _parseMarkupAnnouncementLines(rawContent);
  }

  List<_AnnouncementLine> _buildAnnouncementLinesFromOps(
    List<Map<String, dynamic>> ops,
  ) {
    final lines = <_AnnouncementLine>[];
    final currentSegments = <_AnnouncementSegment>[];

    void pushLine([String? align]) {
      lines.add(
        _AnnouncementLine(
          segments: List<_AnnouncementSegment>.from(currentSegments),
          align: align,
        ),
      );
      currentSegments.clear();
    }

    for (final op in ops) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (insert is! String) continue;

      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isNotEmpty) {
          currentSegments.add(
            _AnnouncementSegment(
              text: part,
              attributes: attributes,
            ),
          );
        }

        if (i < parts.length - 1) {
          pushLine(attributes['align']?.toString());
        }
      }
    }

    if (currentSegments.isNotEmpty) {
      pushLine();
    }

    return lines;
  }

  List<_AnnouncementLine> _parseMarkupAnnouncementLines(String rawContent) {
    final lines = <_AnnouncementLine>[];
    final currentSegments = <_AnnouncementSegment>[];
    final tagPattern = RegExp(
      r'\[(\/?)(b|i|u|s|size|align)\b(?:=([^\]]+))?\]',
      caseSensitive: false,
    );

    final boldStack = <bool>[];
    final italicStack = <bool>[];
    final underlineStack = <bool>[];
    final strikeStack = <bool>[];
    final sizeStack = <String?>[];
    final alignStack = <String?>[];

    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strike = false;
    String? size;
    String? align;

    Map<String, dynamic> currentAttributes() {
      final attributes = <String, dynamic>{};
      if (bold) attributes['bold'] = true;
      if (italic) attributes['italic'] = true;
      if (underline) attributes['underline'] = true;
      if (strike) attributes['strike'] = true;
      if (size != null && size.isNotEmpty) {
        attributes['size'] = size;
      }
      return attributes;
    }

    void pushLine() {
      lines.add(
        _AnnouncementLine(
          segments: List<_AnnouncementSegment>.from(currentSegments),
          align: align,
        ),
      );
      currentSegments.clear();
    }

    void appendText(String text) {
      final normalized = text.replaceAll('\r\n', '\n');
      final parts = normalized.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          currentSegments.add(
            _AnnouncementSegment(
              text: parts[i],
              attributes: currentAttributes(),
            ),
          );
        }
        if (i < parts.length - 1) {
          pushLine();
        }
      }
    }

    var cursor = 0;
    for (final match in tagPattern.allMatches(rawContent)) {
      if (match.start > cursor) {
        appendText(rawContent.substring(cursor, match.start));
      }

      final isClosing = match.group(1) == '/';
      final tag = (match.group(2) ?? '').toLowerCase();
      final value = match.group(3)?.trim();

      if (!isClosing) {
        switch (tag) {
          case 'b':
            boldStack.add(bold);
            bold = true;
            break;
          case 'i':
            italicStack.add(italic);
            italic = true;
            break;
          case 'u':
            underlineStack.add(underline);
            underline = true;
            break;
          case 's':
            strikeStack.add(strike);
            strike = true;
            break;
          case 'size':
            sizeStack.add(size);
            final parsedSize = int.tryParse(value ?? '');
            if (parsedSize != null) {
              size = parsedSize
                  .clamp(_minAnnouncementFontSize, _maxAnnouncementFontSize)
                  .toString();
            }
            break;
          case 'align':
            alignStack.add(align);
            final normalizedAlign = value?.toLowerCase();
            if (normalizedAlign == 'center' ||
                normalizedAlign == 'right' ||
                normalizedAlign == 'justify') {
              align = normalizedAlign;
            } else {
              align = 'left';
            }
            break;
        }
      } else {
        switch (tag) {
          case 'b':
            bold = boldStack.isNotEmpty ? boldStack.removeLast() : false;
            break;
          case 'i':
            italic = italicStack.isNotEmpty ? italicStack.removeLast() : false;
            break;
          case 'u':
            underline =
                underlineStack.isNotEmpty ? underlineStack.removeLast() : false;
            break;
          case 's':
            strike = strikeStack.isNotEmpty ? strikeStack.removeLast() : false;
            break;
          case 'size':
            size = sizeStack.isNotEmpty ? sizeStack.removeLast() : null;
            break;
          case 'align':
            align = alignStack.isNotEmpty ? alignStack.removeLast() : null;
            break;
        }
      }

      cursor = match.end;
    }

    if (cursor < rawContent.length) {
      appendText(rawContent.substring(cursor));
    }

    if (currentSegments.isNotEmpty) {
      pushLine();
    }

    return lines;
  }

  List<_AnnouncementLine> _parseHtmlAnnouncementLines(String rawContent) {
    final lines = <_AnnouncementLine>[];
    final currentSegments = <_AnnouncementSegment>[];
    final tagPattern = RegExp(
      r'<\s*(\/)?([a-zA-Z0-9]+)\b([^>]*)>',
      caseSensitive: false,
    );

    final boldStack = <bool>[];
    final italicStack = <bool>[];
    final underlineStack = <bool>[];
    final strikeStack = <bool>[];
    final sizeStack = <String?>[];
    final colorStack = <String?>[];
    final alignStack = <String?>[];

    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strike = false;
    String? size;
    String? color;
    String? align;

    Map<String, dynamic> currentAttributes() {
      final attributes = <String, dynamic>{};
      if (bold) attributes['bold'] = true;
      if (italic) attributes['italic'] = true;
      if (underline) attributes['underline'] = true;
      if (strike) attributes['strike'] = true;
      if (size != null && size.isNotEmpty) attributes['size'] = size;
      if (color != null && color.isNotEmpty) attributes['color'] = color;
      return attributes;
    }

    void pushLine() {
      lines.add(
        _AnnouncementLine(
          segments: List<_AnnouncementSegment>.from(currentSegments),
          align: align,
        ),
      );
      currentSegments.clear();
    }

    void appendText(String text) {
      final decoded = _decodeAnnouncementHtmlText(text);
      final normalized = decoded.replaceAll('\r\n', '\n');
      final parts = normalized.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          currentSegments.add(
            _AnnouncementSegment(
              text: parts[i],
              attributes: currentAttributes(),
            ),
          );
        }
        if (i < parts.length - 1) {
          pushLine();
        }
      }
    }

    var cursor = 0;
    for (final match in tagPattern.allMatches(rawContent)) {
      if (match.start > cursor) {
        appendText(rawContent.substring(cursor, match.start));
      }

      final isClosing = match.group(1) == '/';
      final tag = (match.group(2) ?? '').toLowerCase();
      final attributesText = match.group(3) ?? '';
      final styleText = _htmlAttributeValue(attributesText, 'style');
      final styleAlign =
          _htmlStyleValue(styleText, 'text-align')?.toLowerCase();
      final styleColor = _htmlStyleValue(styleText, 'color');
      final styleFontSize = _htmlStyleValue(styleText, 'font-size');

      if (!isClosing) {
        switch (tag) {
          case 'strong':
          case 'b':
            boldStack.add(bold);
            bold = true;
            break;
          case 'em':
          case 'i':
            italicStack.add(italic);
            italic = true;
            break;
          case 'u':
            underlineStack.add(underline);
            underline = true;
            break;
          case 's':
          case 'strike':
            strikeStack.add(strike);
            strike = true;
            break;
          case 'span':
            colorStack.add(color);
            sizeStack.add(size);
            if (styleColor != null && styleColor.isNotEmpty) {
              color = styleColor;
            }
            final parsedInlineSize =
                _normalizeAnnouncementHtmlFontSize(styleFontSize);
            if (parsedInlineSize != null) {
              size = parsedInlineSize;
            }
            break;
          case 'p':
          case 'div':
            alignStack.add(align);
            if (styleAlign == 'center' ||
                styleAlign == 'right' ||
                styleAlign == 'justify') {
              align = styleAlign;
            } else if (styleAlign == 'left') {
              align = 'left';
            }
            break;
          case 'br':
            pushLine();
            break;
        }
      } else {
        switch (tag) {
          case 'strong':
          case 'b':
            bold = boldStack.isNotEmpty ? boldStack.removeLast() : false;
            break;
          case 'em':
          case 'i':
            italic = italicStack.isNotEmpty ? italicStack.removeLast() : false;
            break;
          case 'u':
            underline =
                underlineStack.isNotEmpty ? underlineStack.removeLast() : false;
            break;
          case 's':
          case 'strike':
            strike = strikeStack.isNotEmpty ? strikeStack.removeLast() : false;
            break;
          case 'span':
            color = colorStack.isNotEmpty ? colorStack.removeLast() : null;
            size = sizeStack.isNotEmpty ? sizeStack.removeLast() : null;
            break;
          case 'p':
          case 'div':
            pushLine();
            align = alignStack.isNotEmpty ? alignStack.removeLast() : null;
            break;
        }
      }

      cursor = match.end;
    }

    if (cursor < rawContent.length) {
      appendText(rawContent.substring(cursor));
    }

    if (currentSegments.isNotEmpty) {
      pushLine();
    }

    return lines;
  }

  String _decodeAnnouncementHtmlText(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  String? _htmlAttributeValue(String rawAttributes, String name) {
    final pattern = RegExp(
      '$name\\s*=\\s*(["\'])(.*?)\\1',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(rawAttributes);
    return match?.group(2)?.trim();
  }

  String? _htmlStyleValue(String? styleText, String property) {
    if (styleText == null || styleText.trim().isEmpty) return null;

    for (final rule in styleText.split(';')) {
      final parts = rule.split(':');
      if (parts.length != 2) continue;
      if (parts[0].trim().toLowerCase() == property.toLowerCase()) {
        return parts[1].trim();
      }
    }

    return null;
  }

  String? _normalizeAnnouncementHtmlFontSize(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;

    final numeric = rawValue.toLowerCase().replaceAll('px', '').trim();
    final parsed = double.tryParse(numeric);
    if (parsed == null) return null;

    return parsed
        .round()
        .clamp(_minAnnouncementFontSize, _maxAnnouncementFontSize)
        .toString();
  }

  Color? _parseAnnouncementColor(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final hex = text.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  TextStyle _announcementSegmentStyle(Map<String, dynamic> attributes) {
    var decoration = TextDecoration.none;
    if (attributes['underline'] == true) {
      decoration = TextDecoration.underline;
    }
    if (attributes['strike'] == true) {
      decoration = decoration == TextDecoration.none
          ? TextDecoration.lineThrough
          : TextDecoration.combine([decoration, TextDecoration.lineThrough]);
    }

    final fontSize = double.tryParse(attributes['size']?.toString() ?? '');

    return TextStyle(
      color: _parseAnnouncementColor(attributes['color']) ??
          const Color(0xFF4F545A),
      fontSize: fontSize ?? 15,
      height: 1.5,
      fontWeight:
          attributes['bold'] == true ? FontWeight.w700 : FontWeight.w400,
      fontStyle:
          attributes['italic'] == true ? FontStyle.italic : FontStyle.normal,
      decoration: decoration,
    );
  }

  TextAlign _announcementTextAlign(String? align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Widget _buildAnnouncementRichContent(String rawContent) {
    final lines = _parseAnnouncementLines(rawContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          SelectableText.rich(
            TextSpan(
              children: lines[index]
                  .segments
                  .map(
                    (segment) => TextSpan(
                      text: segment.text,
                      style: _announcementSegmentStyle(segment.attributes),
                    ),
                  )
                  .toList(),
            ),
            textAlign: _announcementTextAlign(lines[index].align),
          ),
          if (index != lines.length - 1) const SizedBox(height: 8),
        ],
        if (lines.isEmpty)
          const Text(
            "No announcement details available.",
            style: TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
      ],
    );
  }

  Widget _announcementMetaText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF81888F),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Future<void> _showAnnouncementDetails(Announcement announcement) async {
    await _markAnnouncementsRead([announcement.id]);
    if (!mounted) return;

    final imageUrls = <String>{
      if (announcement.thumbnailUrl.trim().isNotEmpty)
        announcement.thumbnailUrl.trim(),
      ...announcement.imageUrls.where((url) => url.trim().isNotEmpty),
    }.toList();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          int selectedImageIndex = 0;
          final pageController = PageController();

          return StatefulBuilder(
            builder: (routeContext, setRouteState) {
              return Scaffold(
                backgroundColor: const Color(0xFFF7F8FA),
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrls.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: PageView.builder(
                              controller: pageController,
                              itemCount: imageUrls.length,
                              onPageChanged: (index) {
                                setRouteState(() {
                                  selectedImageIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return AppTapSurface(
                                  onTap: () => _showSwipeImageGallery(
                                    imageUrls,
                                    initialIndex: index,
                                  ),
                                  child: Container(
                                    color: const Color(0xFFE9EDF2),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          imageUrls[index],
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                        ),
                                        IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Color(0x66F8F9FA),
                                                  Color(0x00F8F9FA),
                                                ],
                                                stops: [0.0, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            height: 210,
                            width: double.infinity,
                            color: const Color(0xFFE9EDF2),
                            child: const Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFF94A3B8),
                              size: 42,
                            ),
                          ),
                        if (imageUrls.length > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                            child: SizedBox(
                              height: 56,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: imageUrls.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final isSelected =
                                      selectedImageIndex == index;
                                  return AppTapSurface(
                                    onTap: () {
                                      pageController.animateToPage(
                                        index,
                                        duration:
                                            const Duration(milliseconds: 220),
                                        curve: Curves.easeOut,
                                      );
                                      setRouteState(() {
                                        selectedImageIndex = index;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? _brandBlue
                                              : const Color(0xFFE2E8F0),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          imageUrls[index],
                                          width: 76,
                                          height: 52,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                announcement.title.trim().isEmpty
                                    ? "Barangay Update"
                                    : announcement.title.trim(),
                                style: const TextStyle(
                                  color: Color(0xFF2C2F32),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  height: 1.16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _announcementMetaText(
                                    _announcementCreatorLabel(announcement),
                                  ),
                                  const SizedBox(width: 32),
                                  _announcementMetaText(
                                    _formatAnnouncementDate(
                                      announcement.createdAt,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFE2E5E9),
                              ),
                              const SizedBox(height: 14),
                              _buildAnnouncementRichContent(
                                announcement.content,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAnnouncementNotifications() async {
    await _markAnnouncementsRead(
      _announcements.map((announcement) => announcement.id).toList(),
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (routeContext, setRouteState) {
            final filteredAnnouncements = _selectedAnnouncementFilter == "All"
                ? _announcements
                : _announcements.where(
                    (announcement) {
                      final category = _announcementListCategory(announcement);
                      return _selectedAnnouncementFilter == "Communication"
                          ? category == "Community"
                          : category == _selectedAnnouncementFilter;
                    },
                  ).toList();

            return Scaffold(
              backgroundColor: _pageBackground,
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Announcement",
                              style: TextStyle(
                                color: _brandBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildTopActionButton(onTap: () {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _announcementFilters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _announcementFilters[index];
                          return _buildAnnouncementFilterChip(
                            label: filter,
                            isSelected: _selectedAnnouncementFilter == filter,
                            onTap: () {
                              setRouteState(() {
                                _selectedAnnouncementFilter = filter;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _isLoadingAnnouncements
                          ? const Center(child: CircularProgressIndicator())
                          : filteredAnnouncements.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No announcements yet.",
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: filteredAnnouncements.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    return _buildAnnouncementListCard(
                                      filteredAnnouncements[index],
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSwipeImageGallery(
    List<String> imageUrls, {
    int initialIndex = 0,
  }) {
    if (imageUrls.isEmpty) return;
    final controller = PageController(initialPage: initialIndex);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
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

  List<String> get _announcementFilters => const [
        "All",
        "Emergency",
        "Health",
        "Communication",
      ];

  String _announcementListCategory(Announcement announcement) {
    final haystack =
        "${announcement.title} ${announcement.content}".toLowerCase();
    if (haystack.contains("emergency") ||
        haystack.contains("urgent") ||
        haystack.contains("flood") ||
        haystack.contains("storm") ||
        haystack.contains("warning")) {
      return "Emergency";
    }
    if (haystack.contains("health") ||
        haystack.contains("medical") ||
        haystack.contains("consultation") ||
        haystack.contains("clinic")) {
      return "Health";
    }
    return "Community";
  }

  Color _announcementCategoryBackground(String category) {
    switch (category) {
      case "Emergency":
        return const Color(0xFFFFE5E8);
      case "Health":
        return const Color(0xFFA7F3D0);
      default:
        return const Color(0xFFDCEAFE);
    }
  }

  Color _announcementCategoryTextColor(String category) {
    switch (category) {
      case "Emergency":
        return const Color(0xFFE11D48);
      case "Health":
        return const Color(0xFF047857);
      default:
        return const Color(0xFF1D4ED8);
    }
  }

  Widget _buildAnnouncementFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: appMotionDuration(context, 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _brandBlue : const Color(0xFFEDEFF1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementListCard(Announcement announcement) {
    final category = _announcementListCategory(announcement);
    final preview = _plainAnnouncementPreview(announcement);
    final trimmedPreview =
        preview.length > 86 ? "${preview.substring(0, 86)}..." : preview;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _runAction(
          () => _showAnnouncementDetails(announcement),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _announcementCategoryBackground(category),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: _announcementCategoryTextColor(category),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatAnnouncementDate(announcement.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                announcement.title.trim().isEmpty
                    ? "Barangay Update"
                    : announcement.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17181C),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trimmedPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Read more ->",
                style: TextStyle(
                  color: _brandBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _profileEmail {
    final email = _supabase.auth.currentUser?.email?.trim() ?? '';
    return email.isEmpty ? "No email address" : email;
  }

  String _formatLongDate(String? value) {
    if (value == null || value.trim().isEmpty) return "No date";
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    final local = parsed.toLocal();
    return "${months[local.month - 1]} ${local.day}, ${local.year}";
  }

  String _plainAnnouncementPreview(Announcement announcement) {
    final lines = _parseAnnouncementLines(announcement.content);
    final text = lines
        .map(
          (line) => line.segments.map((segment) => segment.text).join(),
        )
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) {
      return "Stay informed with the latest barangay update.";
    }
    if (text.length <= 120) return text;
    return "${text.substring(0, 117)}...";
  }

  String _announcementBadgeLabel(Announcement announcement) {
    final haystack =
        "${announcement.title} ${announcement.content}".toLowerCase();
    if (haystack.contains("severe") ||
        haystack.contains("weather") ||
        haystack.contains("storm") ||
        haystack.contains("flood")) {
      return "SEVERE WEATHER";
    }
    if (haystack.contains("emergency") || haystack.contains("urgent")) {
      return "EMERGENCY";
    }
    return "COMMUNITY ALERT";
  }

  void _openServiceView(_ResidentServiceView view) {
    setState(() {
      _currentTab = 1;
      _serviceView = view;
      if (view != _ResidentServiceView.certificateRequestForm) {
        _selectedCertificateRequest = null;
      }
    });
  }

  void _openCertificateRequestForm(Map<String, dynamic> certificate) {
    _populateCertificateFormDefaults();
    setState(() {
      _selectedCertificateRequest = certificate;
      _selectedCertificatePaymentMethod = "GCash";
      _selectedCertificateVariant = "Good Moral";
      _serviceView = _ResidentServiceView.certificateRequestForm;
    });
  }

  void _populateCertificateFormDefaults() {
    _certificateControllers['full_name']!.text = _fullName;
    _certificateControllers['address']!.text =
        _address == "Address not set" ? "" : _address;
    _certificateControllers['contact_number']!.text =
        _contactNumber == "No contact number" ? "" : _contactNumber;
    _certificateControllers['email']!.text =
        _supabase.auth.currentUser?.email?.trim() ?? "";
  }

  void _resetCertificateRequestForm() {
    for (final entry in _certificateControllers.entries) {
      final keepAutoFilled = entry.key == 'full_name' ||
          entry.key == 'address' ||
          entry.key == 'contact_number' ||
          entry.key == 'email';
      if (!keepAutoFilled) {
        entry.value.clear();
      }
    }
    _selectedCertificatePaymentMethod = "GCash";
    _selectedCertificateVariant = "Good Moral";
    _selectedPaymentProofImage = null;
  }

  bool _validateCertificateRequest() {
    final requiredLabels = <String, String>{
      'full_name': 'Full Name',
      'address': 'Address',
      'contact_number': 'Contact Number',
      'purpose': 'Purpose of Request',
    };

    for (final entry in requiredLabels.entries) {
      if (_certificateControllers[entry.key]!.text.trim().isEmpty) {
        _showSnackBar("Please enter ${entry.value}.");
        return false;
      }
    }

    final certificateKey = _selectedCertificateRequest?['key'] as String? ?? '';
    final certificateSpecificRequired = switch (certificateKey) {
      'certificate_of_indigency' => <String, String>{
          'institution_agency': 'Name of Institution / Agency',
          'reason_for_request': 'Reason for Request',
        },
      'good_moral_residency' => <String, String>{
          'length_of_stay': 'Length of Stay in Barangay',
          'institution_agency': 'Name of School / Employer / Agency',
        },
      'barangay_clearance_for_loan' => <String, String>{
          'loan_purpose': 'Loan Purpose',
          'lending_company': 'Name of Lending Company / Bank',
          'loan_amount': 'Amount to be Borrowed',
          'length_of_stay': 'Length of Stay in Barangay',
        },
      'barangay_id' => <String, String>{
          'gender': 'Gender',
          'occupation': 'Occupation',
          'emergency_contact_name': 'Emergency Contact Name',
          'emergency_contact_number': 'Emergency Contact Number',
        },
      'special_certification' => <String, String>{
          'certification_details': 'Details of Certification Needed',
          'requesting_party': 'Name of Agency / Person Requesting It',
        },
      'store_business_clearance' => <String, String>{
          'business_name': 'Business Name',
          'business_address': 'Business Address',
          'business_type': 'Type of Business',
          'years_of_operation': 'Years of Operation',
        },
      'tricycle_clearance' => <String, String>{
          'operator_name': 'Driver / Operator Name',
          'plate_number': 'Tricycle Plate Number',
          'route_area': 'Route / Area of Operation',
        },
      'banca_clearance' => <String, String>{
          'operator_name': 'Owner / Operator Name',
          'banca_name': 'Banca Name',
          'banca_registration_number': 'Banca Registration Number',
          'operation_area': 'Area of Operation',
        },
      _ => <String, String>{},
    };

    for (final entry in certificateSpecificRequired.entries) {
      if (_certificateControllers[entry.key]!.text.trim().isEmpty) {
        _showSnackBar("Please enter ${entry.value}.");
        return false;
      }
    }

    if (_selectedCertificatePaymentMethod == "GCash") {
      if (_certificateControllers['payment_reference']!.text.trim().isEmpty) {
        _showSnackBar("Please enter the GCash reference number.");
        return false;
      }
      if (_selectedPaymentProofImage == null) {
        _showSnackBar("Please upload your payment proof screenshot.");
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> _buildCertificateRequestPayload(
    Map<String, dynamic> certificate,
    User user, {
    String? paymentProofUrl,
  }) {
    final sanitizedFormData = <String, dynamic>{};

    for (final entry in _certificateControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        sanitizedFormData[entry.key] = value;
      }
    }

    final feeLabel = certificate['fee'] as String? ?? 'Free';

    return {
      'user_id': user.id,
      'resident_id': user.id,
      'resident_name':
          _certificateControllers['full_name']!.text.trim().isNotEmpty
              ? _certificateControllers['full_name']!.text.trim()
              : _fullName,
      'certificate_key': certificate['key'] as String? ?? '',
      'certificate_title':
          certificate['title'] as String? ?? 'Document Request',
      'certificate_variant': certificate['key'] == 'good_moral_residency'
          ? _selectedCertificateVariant
          : null,
      'contact_number': _certificateControllers['contact_number']!.text.trim(),
      'email': _certificateControllers['email']!.text.trim(),
      'address': _certificateControllers['address']!.text.trim(),
      'payment_method': _selectedCertificatePaymentMethod,
      'payment_receiver_name': _selectedCertificatePaymentMethod == 'GCash'
          ? _demoGcashReceiverName
          : null,
      'payment_receiver_number': _selectedCertificatePaymentMethod == 'GCash'
          ? _demoGcashReceiverNumber
          : null,
      'payment_reference': _selectedCertificatePaymentMethod == 'GCash'
          ? _certificateControllers['payment_reference']!.text.trim()
          : null,
      'payment_proof_url': paymentProofUrl,
      'payment_submitted_at': _selectedCertificatePaymentMethod == 'GCash'
          ? DateTime.now().toIso8601String()
          : null,
      'fee_label': feeLabel,
      'fee_amount': _parseCertificateFeeAmount(feeLabel),
      'purpose': _certificateControllers['purpose']!.text.trim(),
      'additional_notes':
          _certificateControllers['additional_notes']!.text.trim().isEmpty
              ? null
              : _certificateControllers['additional_notes']!.text.trim(),
      'form_data': sanitizedFormData,
      'status': _selectedCertificatePaymentMethod == 'GCash'
          ? 'awaiting_payment'
          : 'pending',
    };
  }

  Future<void> _pickPaymentProofImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedPaymentProofImage = File(picked.path);
    });
  }

  Future<String?> _uploadPaymentProofImage(File imageFile) async {
    try {
      final fileName = path.basename(imageFile.path);
      final userId = _supabase.auth.currentUser!.id;
      final filePath =
          "document-payment-proofs/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName";

      await _supabase.storage.from('resident-files').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      return _supabase.storage.from('resident-files').getPublicUrl(filePath);
    } catch (_) {
      return null;
    }
  }

  double _parseCertificateFeeAmount(String feeLabel) {
    final normalizedFee = feeLabel.toLowerCase();
    if (normalizedFee.contains('free')) return 0;

    final digitsOnly = feeLabel.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(digitsOnly) ?? 0;
  }

  Future<void> _submitCertificateRequestForm() async {
    if (!_validateCertificateRequest()) return;

    final user = _supabase.auth.currentUser;
    final certificate = _selectedCertificateRequest;

    if (user == null || certificate == null) {
      _showSnackBar("Unable to submit the request right now.");
      return;
    }

    setState(() => _isSubmittingCertificateRequest = true);

    try {
      String? paymentProofUrl;
      if (_selectedCertificatePaymentMethod == 'GCash' &&
          _selectedPaymentProofImage != null) {
        paymentProofUrl =
            await _uploadPaymentProofImage(_selectedPaymentProofImage!);

        if (paymentProofUrl == null) {
          throw Exception('Payment proof upload failed');
        }
      }

      final payload = _buildCertificateRequestPayload(
        certificate,
        user,
        paymentProofUrl: paymentProofUrl,
      );

      await _supabase.from('document_requests').insert(payload);

      if (!mounted) return;

      final certificateTitle =
          certificate['title'] as String? ?? 'Document Request';
      await _fetchResidentActivity();
      await _showCertificateRequestSubmittedDialog(certificateTitle);
    } on PostgrestException {
      if (!mounted) return;
      _showSnackBar("Unable to submit the request right now.");
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        "We couldn't submit your request right now. Please try again.",
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCertificateRequest = false);
      }
    }
  }

  Future<void> _showCertificateRequestSubmittedDialog(
    String certificateTitle,
  ) async {
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
                  'Request Submitted',
                  style: TextStyle(
                    color: _brandBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your $certificateTitle request has been submitted successfully. Please wait for barangay staff to review your request and payment details.',
                  style: const TextStyle(
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
                      setState(() {
                        _resetCertificateRequestForm();
                        _selectedCertificateRequest = null;
                        _serviceView = _ResidentServiceView.menu;
                        _currentTab = 2;
                      });
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
                      'Done',
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

  void _onDestinationSelected(int index) {
    if (_currentTab == index) return;
    FocusScope.of(context).unfocus();
    setState(() => _currentTab = index);
  }

  void _goBackWithinDashboard() {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_currentTab == 1 && _serviceView != _ResidentServiceView.menu) {
        _serviceView =
            _serviceView == _ResidentServiceView.certificateRequestForm
                ? _ResidentServiceView.certificates
                : _ResidentServiceView.menu;
      } else {
        _currentTab = 0;
      }
    });
  }

  Future<void> _showCategorySheet() async {
    final category = await showAppSelectionSheet(
      context: context,
      title: 'Choose an issue category',
      options: _categories,
      selectedValue: _selectedCategory,
    );
    if (!mounted || category == null) return;
    setState(() => _selectedCategory = category);
  }

  Widget _buildTopActionButton({
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: _topActionSize,
      height: _topActionSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE7E7E7)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _runAction(onTap),
            child: Center(
              child: SvgPicture.asset(
                'lib/assets/bell.svg',
                width: 20,
                height: 20,
                colorFilter:
                    const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                placeholderBuilder: (_) => const Icon(
                  Icons.notifications_none_rounded,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF424751),
              fontSize: 18,
              height: 28 / 18,
              letterSpacing: 0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onAction,
            child: Transform.translate(
              offset: const Offset(0, -1),
              child: Container(
                padding: EdgeInsets.zero,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF003366),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  actionText,
                  style: const TextStyle(
                    color: Color(0xFF003366),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHomeAnnouncementHighlight() {
    if (_isLoadingAnnouncements) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(),
      ));
    }

    if (_announcementsLoadFailed) {
      return AppStatusMessage(
          message: 'Announcements could not be refreshed.',
          icon: Icons.cloud_off_rounded,
          onRetry: _fetchAnnouncements);
    }
    if (_announcements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E9F0)),
        ),
        child: const Text(
          "No announcements posted yet.",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    final contentWidth =
        MediaQuery.of(context).size.width - (_pageHorizontalPadding * 2);
    final cardWidth = (contentWidth * 0.93).clamp(290.0, 340.0).toDouble();
    final previewItems = _announcements.take(5).toList();

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: previewItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _buildHomeAnnouncementCard(
            previewItems[index],
            width: cardWidth,
          );
        },
      ),
    );
  }

  Widget _buildHomeAnnouncementCard(
    Announcement item, {
    required double width,
  }) {
    final imageUrl = item.thumbnailUrl.trim();
    final preview = _plainAnnouncementPreview(item);
    final subtitle =
        preview.length > 56 ? "${preview.substring(0, 56)}..." : preview;

    return Material(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _runAction(
          () => _showAnnouncementDetails(item),
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: 188,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: imageUrl.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00001E40),
                  Color(0x33001E40),
                  Color(0xE6001E40),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD8BE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _announcementBadgeLabel(item) == "COMMUNITY ALERT"
                        ? "UPDATE"
                        : _announcementBadgeLabel(item),
                    style: const TextStyle(
                      color: Color(0xFF7B3E1B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title.trim().isEmpty
                      ? "Barangay Update"
                      : item.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.publicSans(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 22.5 / 18,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xCCFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 16 / 14,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required Color accent,
    required Color bg,
    Color borderColor = const Color(0xFFE2E8F0),
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _runAction(onTap),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF3F3F46),
                        fontSize: 14,
                        height: 1.15,
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

  Widget _buildServiceStatusCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap == null ? null : () => _runAction(onTap),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeActivityLabel(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return "RECENT";
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inHours < 1) return "${diff.inMinutes.clamp(1, 59)}M AGO";
    if (diff.inHours < 24) return "${diff.inHours}H AGO";
    if (diff.inDays == 1) return "YESTERDAY";
    return "${diff.inDays}D AGO";
  }

  Widget _buildHomeHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _pageHorizontalPadding,
                _topBarTopPadding,
                _pageHorizontalPadding,
                14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipOval(
                      child: _profileImage.trim().isNotEmpty
                          ? Image.network(
                              _profileImage.trim(),
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_outline,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                            )
                          : const Icon(
                              Icons.person_outline,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Mabuhay,",
                            style: TextStyle(
                              color: Color(0xFF696969),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 0.5),
                          Text(
                            _fullName.isEmpty ? "Resident" : _fullName,
                            style: const TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.02,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildTopActionButton(
                        onTap: _openAnnouncementNotifications,
                      ),
                      if (_unreadAnnouncementCount > 0)
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Color(0xFF006CBF),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: const Text(
                "Stay updated with the latest community news and access essential barangay services.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledHomeTab() {
    final ongoingReports = _reports
        .where((report) {
          final status =
              (report['status']?.toString().toLowerCase() ?? 'pending');
          return status == 'pending' ||
              status == 'in_progress' ||
              status == 'ongoing';
        })
        .take(2)
        .toList();

    final recentReports = _reports.take(2).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadResidentProfile(),
          _fetchResidentActivity(),
          _fetchAnnouncements(),
        ]);
      },
      child: ListView(
        key: const PageStorageKey('home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildHomeHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                _buildSectionHeader(
                  title: "Announcement",
                  actionText: "View all",
                  onAction: _openAnnouncementNotifications,
                ),
                const SizedBox(height: 14),
                _buildHomeAnnouncementHighlight(),
                const SizedBox(height: 24),
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    color: Color(0xFF424751),
                    fontSize: 18,
                    height: 28 / 18,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  accent: _gold,
                  bg: const Color(0x80F8EEDF),
                  borderColor: const Color(0x33E8A508),
                  icon: Icons.campaign_outlined,
                  title: "File a report",
                  subtitle: "Report a community problem",
                  onTap: () =>
                      _openServiceView(_ResidentServiceView.reportForm),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  accent: const Color(0xFF0D8B83),
                  bg: const Color(0x80E7EFEE),
                  borderColor: const Color(0xFFC0DCD9),
                  icon: Icons.description_outlined,
                  title: "Request document",
                  subtitle: "Apply for certificates",
                  onTap: () =>
                      _openServiceView(_ResidentServiceView.certificates),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Ongoing Services",
                  style: TextStyle(
                    color: Color(0xFF424751),
                    fontSize: 18,
                    height: 28 / 18,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _reportsLoadFailed
                      ? AppStatusMessage(
                          message: 'Activity could not be refreshed.',
                          icon: Icons.cloud_off_rounded,
                          onRetry: _fetchResidentActivity)
                      : _isLoadingReports && _reports.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()))
                          : ongoingReports.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    "No ongoing services right now.",
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                )
                              : Column(
                                  children: List.generate(ongoingReports.length,
                                      (index) {
                                    final report = ongoingReports[index];
                                    final category = (report['category']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ??
                                            false)
                                        ? report['category'].toString()
                                        : "Community concern";
                                    final subtitle =
                                        "Status change to ${_statusLabel(report['status']?.toString() ?? 'pending').toLowerCase()}";
                                    return Column(
                                      children: [
                                        _buildServiceStatusCard(
                                          icon: Icons.campaign_outlined,
                                          iconColor: Color(0xFF17365D),
                                          iconBg: Color(0xFFF1F3F5),
                                          title: category,
                                          subtitle: subtitle,
                                          onTap: () =>
                                              _showReportDetails(report),
                                        ),
                                        if (index != ongoingReports.length - 1)
                                          const Divider(
                                              height: 18,
                                              color: Color(0xFFE8EDF3)),
                                      ],
                                    );
                                  }),
                                ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Recent Activity",
                  style: TextStyle(
                    color: Color(0xFF424751),
                    fontSize: 18,
                    height: 28 / 18,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _reportsLoadFailed
                      ? AppStatusMessage(
                          message: 'Activity could not be refreshed.',
                          icon: Icons.cloud_off_rounded,
                          onRetry: _fetchResidentActivity)
                      : _isLoadingReports && _reports.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()))
                          : recentReports.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    "No recent activity yet.",
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                )
                              : Column(
                                  children: List.generate(recentReports.length,
                                      (index) {
                                    final report = recentReports[index];
                                    final category = (report['category']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ??
                                            false)
                                        ? report['category'].toString()
                                        : "Incident Report";
                                    return Column(
                                      children: [
                                        _buildServiceStatusCard(
                                          icon: Icons.description_outlined,
                                          iconColor: const Color(0xFF64748B),
                                          iconBg: const Color(0xFFF3F5F7),
                                          title: category,
                                          subtitle:
                                              "Assigned status: ${_statusLabel(report['status']?.toString() ?? 'pending')}",
                                          trailing: _relativeActivityLabel(
                                            report['created_at']?.toString(),
                                          ),
                                          onTap: () =>
                                              _showReportDetails(report),
                                        ),
                                        if (index != recentReports.length - 1)
                                          const Divider(
                                              height: 18,
                                              color: Color(0xFFE8EDF3)),
                                      ],
                                    );
                                  }),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: Color(0xFF223B57),
      ),
    );
  }

  Widget _buildServicesTopBar({
    required String sectionLabel,
    required String title,
    required String subtitle,
    bool allowBackToMenu = false,
    VoidCallback? onBack,
  }) {
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 650 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _pageHorizontalPadding,
          _topBarTopPadding,
          _pageHorizontalPadding,
          8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppTapSurface(
                  label: allowBackToMenu ? 'Back to services' : null,
                  onTap: allowBackToMenu
                      ? (onBack ??
                          () {
                            setState(() {
                              _serviceView = _ResidentServiceView.menu;
                            });
                          })
                      : null,
                  child: Text(
                    sectionLabel,
                    style: TextStyle(
                      color: _brandBlue,
                      fontSize: 18,
                      fontWeight:
                          allowBackToMenu ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                _buildTopActionButton(
                  onTap: _openAnnouncementNotifications,
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 30),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF004687),
                fontSize: compact ? 22 : 40,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF424751),
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceEntryCard({
    required Color accent,
    required Color background,
    required Color borderColor,
    required IconData icon,
    required String title,
    required String description,
    required String cta,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _runAction(onTap),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 32, 28, 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: Colors.white, size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF000000),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF424751),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cta,
                    style: const TextStyle(
                      color: _brandBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _brandBlue,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSelectorField({
    required String placeholder,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _runAction(onTap),
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF94A3B8),
            ),
          ),
          child: Text(
            value ?? placeholder,
            style: TextStyle(
              color: value == null
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF334155),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportMapSection() {
    final point = (_reportLatitude != null && _reportLongitude != null)
        ? LatLng(_reportLatitude!, _reportLongitude!)
        : const LatLng(9.7392, 118.7353);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.place_outlined, color: _brandBlue, size: 18),
              SizedBox(width: 6),
              Text(
                "Pin Location",
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            "Where is this issue located?",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 170,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: _reportLatitude == null ? 13 : 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.barangay_mobile_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 42,
                            height: 42,
                            point: point,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.red,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: FilledButton.icon(
                      onPressed:
                          _isFetchingLocation ? null : _captureCurrentLocation,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: Color(0xFFD5DFEC)),
                        ),
                      ),
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_outlined, size: 16),
                      label: const Text(
                        "Current Location",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _reportLatitude == null
                ? "A precise location helps our responders find the issue faster."
                : _reportLocationLabel,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _pickLocationOnMap,
            icon: const Icon(Icons.map_outlined, size: 16),
            label: Text(
              _reportLatitude == null ? "Choose on Map" : "Update Pin on Map",
            ),
            style: TextButton.styleFrom(
              foregroundColor: _brandBlue,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesMenuTab() {
    return Column(
      children: [
        _buildServicesTopBar(
          sectionLabel: "Services",
          title: "How can we assist\nyou today?",
          subtitle:
              "Access essential barangay services, request official documentation, or report local concerns directly to your community leaders.",
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: const AppScrollBehavior(),
            child: ListView(
              key: const PageStorageKey('services'),
              clipBehavior: Clip.none,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                _pageHorizontalPadding,
                26,
                _pageHorizontalPadding,
                24,
              ),
              children: [
                _buildServiceEntryCard(
                  accent: _gold,
                  background: const Color(0x80F8EEDF),
                  borderColor: const Color(0x33E8A508),
                  icon: Icons.campaign_outlined,
                  title: "File a Report",
                  description:
                      "Report non-emergency infrastructure issues or community concerns directly.",
                  cta: "PROCEED",
                  onTap: () {
                    setState(() {
                      _serviceView = _ResidentServiceView.reportForm;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildServiceEntryCard(
                  accent: const Color(0xFF0D8B83),
                  background: const Color(0x80E7EFEE),
                  borderColor: const Color(0xFFC0DCD9),
                  icon: Icons.description_outlined,
                  title: "Request Certificate",
                  description:
                      "Apply for Barangay Clearance, Residency, and other official documents.",
                  cta: "APPLY NOW",
                  onTap: () {
                    setState(() {
                      _serviceView = _ResidentServiceView.certificates;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTab() {
    return Column(
      children: [
        _buildServicesTopBar(
          sectionLabel: "Services",
          title: "Create a New Report",
          subtitle: "Help us maintain the beauty and safety of our barangay.",
          allowBackToMenu: true,
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('report-form'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              _buildReportSectionTitle("Issue Category"),
              const SizedBox(height: 2),
              const Text(
                "What type of concern are you reporting?",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _buildServiceSelectorField(
                placeholder: "Choose a category",
                value: _selectedCategory,
                onTap: _showCategorySheet,
              ),
              const SizedBox(height: 18),
              _buildReportSectionTitle("Incident Details"),
              const SizedBox(height: 2),
              const Text(
                "Describe the issue and provide details.",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      "Enter as much detail as possible to help our team respond quickly...",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _pickReportImage(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: const _DashedServiceRectPainter(
                      color: Color(0xFFB8CBE3),
                      radius: 16,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            color: _brandBlue,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Upload Photo",
                            style: TextStyle(
                              color: _brandBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedReportImages.isEmpty
                                ? "Maximum file size: 10MB. Formats: JPG, PNG."
                                : "${_selectedReportImages.length} photo(s) selected",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedReportImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedReportImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final image = _selectedReportImages[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              image,
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: AppTapSurface(
                              onTap: () => _removeSelectedReportImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _buildReportMapSection(),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmittingReport ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmittingReport
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Submit Report",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.play_arrow_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentRequestDetailsPage(Map<String, dynamic> request) {
    final certificateTitle =
        (request['certificate_title']?.toString().trim().isNotEmpty ?? false)
            ? request['certificate_title'].toString().trim()
            : "Document Request";
    final certificateVariant =
        request['certificate_variant']?.toString().trim() ?? '';
    final status = request['status']?.toString() ?? 'pending';
    final statusLabel = _statusLabel(status);
    final paymentMethod = request['payment_method']?.toString().trim() ?? '';
    final paymentReceiverName =
        request['payment_receiver_name']?.toString().trim() ?? '';
    final paymentReceiverNumber =
        request['payment_receiver_number']?.toString().trim() ?? '';
    final paymentReference =
        request['payment_reference']?.toString().trim() ?? '';
    final paymentProofUrl =
        request['payment_proof_url']?.toString().trim() ?? '';
    final feeLabel = request['fee_label']?.toString().trim() ?? '';
    final purpose = request['purpose']?.toString().trim() ?? '';
    final additionalNotes =
        request['additional_notes']?.toString().trim() ?? '';
    final rejectionReason =
        request['rejection_reason']?.toString().trim() ?? '';
    final createdAt = request['created_at']?.toString();
    final rawFormData = request['form_data'];
    final formData = rawFormData is Map
        ? Map<String, dynamic>.from(rawFormData)
        : <String, dynamic>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF0B4F94),
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Document Request Details",
                    style: TextStyle(
                      color: Color(0xFF0B4F94),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF0B4F94),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              certificateVariant.isNotEmpty
                                  ? "$certificateTitle ($certificateVariant)"
                                  : certificateTitle,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildResidentStatusChip(statusLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildReportDetailsMetaChip(
                        icon: Icons.schedule_outlined,
                        label: _formatDetailedReportDate(createdAt),
                      ),
                      if (paymentMethod.isNotEmpty)
                        _buildReportDetailsMetaChip(
                          icon: Icons.payments_outlined,
                          label: paymentMethod,
                        ),
                      if (feeLabel.isNotEmpty)
                        _buildReportDetailsMetaChip(
                          icon: Icons.receipt_long_outlined,
                          label: feeLabel,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildDocumentDetailSection(
                    title: "Purpose of Request",
                    body: purpose.isEmpty ? "No purpose provided." : purpose,
                  ),
                  if (paymentMethod.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildDocumentFieldRow(
                      label: "Payment Method",
                      value: paymentMethod,
                    ),
                  ],
                  if (paymentReceiverName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDocumentFieldRow(
                      label: "Receiver Name",
                      value: paymentReceiverName,
                    ),
                  ],
                  if (paymentReceiverNumber.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDocumentFieldRow(
                      label: "Receiver Number",
                      value: paymentReceiverNumber,
                    ),
                  ],
                  if (paymentReference.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDocumentFieldRow(
                      label: "Payment Reference",
                      value: paymentReference,
                    ),
                  ],
                  if (paymentProofUrl.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildDocumentPaymentProofCard(paymentProofUrl),
                  ],
                  if (additionalNotes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildDocumentDetailSection(
                      title: "Additional Notes",
                      body: additionalNotes,
                    ),
                  ],
                  if (rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildDocumentDetailSection(
                      title: "Rejection Reason",
                      body: rejectionReason,
                      backgroundColor: const Color(0xFFFFF1F2),
                      borderColor: const Color(0xFFFECDD3),
                    ),
                  ],
                  if (formData.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      "Submitted Information",
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...formData.entries.map((entry) {
                      final value = entry.value?.toString().trim() ?? '';
                      if (value.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildDocumentFieldRow(
                          label: _humanizeRequestFieldLabel(entry.key),
                          value: value,
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                  _buildDocumentFieldRow(
                    label: "Request ID",
                    value: request['id']?.toString() ?? 'Unavailable',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResidentStatusChip(String statusLabel) {
    final statusStyle = _statusChipStyle(statusLabel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusStyle.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel.toUpperCase(),
        style: TextStyle(
          color: statusStyle.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDocumentDetailSection({
    required String title,
    required String body,
    Color backgroundColor = const Color(0xFFF8FAFC),
    Color borderColor = const Color(0xFFE2E8F0),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentFieldRow({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPaymentProofCard(String imageUrl) {
    return AppTapSurface(
      onTap: () => _showSwipeImageGallery([imageUrl], initialIndex: 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Payment Proof",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: const Color(0xFFF8FAFC),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF94A3B8),
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tap to view screenshot",
              style: TextStyle(
                color: _brandBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _humanizeRequestFieldLabel(String key) {
    return key.split('_').map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1);
    }).join(' ');
  }

  Widget _buildRequestCard(Map<String, dynamic> report) {
    final isDocumentRequest = report['activity_type'] == 'document_request';
    final status = (report['status'] as String?) ?? "pending";
    final statusLabel = _statusLabel(status).toUpperCase();
    final statusChipStyle = _statusChipStyle(status);
    final normalizedStatus = status.toLowerCase();
    final category = (report['category'] as String?)?.trim();
    final certificateTitle = (report['certificate_title'] as String?)?.trim();
    final certificateVariant =
        (report['certificate_variant'] as String?)?.trim();
    final title = isDocumentRequest
        ? ((certificateTitle != null && certificateTitle.isNotEmpty)
            ? (certificateVariant != null && certificateVariant.isNotEmpty
                ? "$certificateTitle ($certificateVariant)"
                : certificateTitle)
            : "Document request")
        : (category != null && category.isNotEmpty)
            ? category
            : "Community concern";
    final subtitle = isDocumentRequest
        ? "Document request is ${_statusLabel(status).toLowerCase()}"
        : "Status change to ${_statusLabel(status).toLowerCase()}";
    final iconData = isDocumentRequest
        ? Icons.description_outlined
        : normalizedStatus == "completed" || normalizedStatus == "resolved"
            ? Icons.task_alt_outlined
            : Icons.campaign_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _runAction(
          () => isDocumentRequest
              ? _showDocumentRequestDetails(report)
              : _showReportDetails(report),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5F8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  iconData,
                  color: const Color(0xFF000000),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusChipStyle.bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusChipStyle.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF424751),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _runAction(
                        () => _showReportDetails(report),
                      ),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "View details",
                              style: TextStyle(
                                color: _brandBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _brandBlue,
                              size: 16,
                            ),
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
      ),
    );
  }

  Widget _buildCertificatesTab() {
    return ListView(
      key: const PageStorageKey('certificates'),
      padding: EdgeInsets.zero,
      children: [
        _buildServicesTopBar(
          sectionLabel: "Services",
          title: "Request Document",
          subtitle: "Choose the certificate or permit you need.",
          allowBackToMenu: true,
        ),
        const SizedBox(height: 8),
        ..._certificateOptions.map(_buildCertificateOptionCard),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCertificateOptionCard(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final fee = item['fee'] as String? ?? '';
    final icon = item['icon'] as IconData? ?? Icons.description_outlined;
    final accent = item['accent'] as Color? ?? _brandBlue;
    final background = item['background'] as Color? ?? _softBlue;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        _pageHorizontalPadding,
        0,
        _pageHorizontalPadding,
        10,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _runAction(
            () => _openCertificateRequestForm(item),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9EDF2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A101828),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF2A2F35),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fee,
                          style: const TextStyle(
                            color: Color(0xFF2A2F35),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF98A2B3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateRequestFormTab() {
    final certificate = _selectedCertificateRequest;
    if (certificate == null) {
      return _buildCertificatesTab();
    }

    final title = certificate['title'] as String? ?? 'Document Request';
    final description = certificate['description'] as String? ?? '';
    final fee = certificate['fee'] as String? ?? '';
    final accent = certificate['accent'] as Color? ?? _brandBlue;
    final background = certificate['background'] as Color? ?? _softBlue;
    final icon = certificate['icon'] as IconData? ?? Icons.description_outlined;

    return Column(
      children: [
        _buildServicesTopBar(
          sectionLabel: "Services",
          title: title,
          subtitle: "Complete the request form below.",
          allowBackToMenu: true,
          onBack: () {
            setState(() {
              _selectedCertificateRequest = null;
              _serviceView = _ResidentServiceView.certificates;
            });
          },
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('certificate-form'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE9EDF2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A101828),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF2A2F35),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fee,
                            style: const TextStyle(
                              color: Color(0xFF2A2F35),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildReportSectionTitle("Personal Information"),
              const SizedBox(height: 10),
              _buildCertificateTextField(
                fieldKey: 'full_name',
                label: 'Full Name',
                hint: 'Enter your full name',
              ),
              _buildCertificateTextField(
                fieldKey: 'address',
                label: 'Address',
                hint: 'Enter your address',
              ),
              _buildCertificateTextField(
                fieldKey: 'contact_number',
                label: 'Contact Number',
                hint: 'Enter your contact number',
                keyboardType: TextInputType.phone,
              ),
              _buildCertificateTextField(
                fieldKey: 'email',
                label: 'Email Address',
                hint: 'Enter your email address',
                keyboardType: TextInputType.emailAddress,
              ),
              _buildCertificateTextField(
                fieldKey: 'date_of_birth',
                label: 'Date of Birth',
                hint: 'MM/DD/YYYY',
              ),
              _buildCertificateTextField(
                fieldKey: 'civil_status',
                label: 'Civil Status',
                hint: 'Enter your civil status',
              ),
              const SizedBox(height: 8),
              _buildReportSectionTitle("Request Details"),
              const SizedBox(height: 10),
              ..._buildCertificateSpecificFields(
                certificate['key'] as String? ?? '',
              ),
              _buildCertificateTextField(
                fieldKey: 'purpose',
                label: 'Purpose of Request',
                hint: 'State the purpose of your request',
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              _buildReportSectionTitle("Payment Method"),
              const SizedBox(height: 10),
              _buildCertificatePaymentMethodSelector(),
              if (_selectedCertificatePaymentMethod == "GCash") ...[
                const SizedBox(height: 14),
                _buildGcashPaymentInstructionsCard(),
                const SizedBox(height: 12),
                _buildCertificateTextField(
                  fieldKey: 'payment_reference',
                  label: 'GCash Reference Number',
                  hint: 'Enter the payment reference number',
                ),
                const SizedBox(height: 10),
                _buildPaymentProofUploader(),
              ],
              const SizedBox(height: 8),
              _buildReportSectionTitle("Additional Notes"),
              const SizedBox(height: 10),
              _buildCertificateTextField(
                fieldKey: 'additional_notes',
                label: 'Additional Notes',
                hint: 'Add supporting notes if needed',
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmittingCertificateRequest
                      ? null
                      : _submitCertificateRequestForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isSubmittingCertificateRequest
                        ? "Submitting..."
                        : "Submit Request",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "This is a draft request form and may still be updated once the barangay confirms the final required fields for each certificate.",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCertificateSpecificFields(String certificateKey) {
    switch (certificateKey) {
      case 'certificate_of_indigency':
        return [
          _buildCertificateTextField(
            fieldKey: 'institution_agency',
            label: 'Name of Institution / Agency',
            hint: 'Enter the institution or agency name',
          ),
          _buildCertificateTextField(
            fieldKey: 'reason_for_request',
            label: 'Reason for Request',
            hint: 'Explain why you need this certificate',
            maxLines: 3,
          ),
        ];
      case 'good_moral_residency':
        return [
          _buildCertificateVariantSelector(),
          _buildCertificateTextField(
            fieldKey: 'length_of_stay',
            label: 'Length of Stay in Barangay',
            hint: 'Example: 5 years',
          ),
          _buildCertificateTextField(
            fieldKey: 'institution_agency',
            label: 'Name of School / Employer / Agency',
            hint: 'Enter the requesting school, employer, or agency',
          ),
        ];
      case 'barangay_clearance_for_loan':
        return [
          _buildCertificateTextField(
            fieldKey: 'loan_purpose',
            label: 'Loan Purpose',
            hint: 'State the purpose of the loan',
          ),
          _buildCertificateTextField(
            fieldKey: 'lending_company',
            label: 'Name of Lending Company / Bank',
            hint: 'Enter the lending company or bank name',
          ),
          _buildCertificateTextField(
            fieldKey: 'loan_amount',
            label: 'Amount to be Borrowed',
            hint: 'Enter the loan amount',
            keyboardType: TextInputType.number,
          ),
          _buildCertificateTextField(
            fieldKey: 'length_of_stay',
            label: 'Length of Stay in Barangay',
            hint: 'Example: 5 years',
          ),
        ];
      case 'barangay_id':
        return [
          _buildCertificateTextField(
            fieldKey: 'gender',
            label: 'Gender',
            hint: 'Enter your gender',
          ),
          _buildCertificateTextField(
            fieldKey: 'occupation',
            label: 'Occupation',
            hint: 'Enter your occupation',
          ),
          _buildCertificateTextField(
            fieldKey: 'emergency_contact_name',
            label: 'Emergency Contact Name',
            hint: 'Enter emergency contact name',
          ),
          _buildCertificateTextField(
            fieldKey: 'emergency_contact_number',
            label: 'Emergency Contact Number',
            hint: 'Enter emergency contact number',
            keyboardType: TextInputType.phone,
          ),
        ];
      case 'special_certification':
        return [
          _buildCertificateTextField(
            fieldKey: 'certification_details',
            label: 'Details of Certification Needed',
            hint: 'Describe the certification needed',
            maxLines: 3,
          ),
          _buildCertificateTextField(
            fieldKey: 'requesting_party',
            label: 'Name of Agency / Person Requesting It',
            hint: 'Enter the requesting agency or person',
          ),
        ];
      case 'store_business_clearance':
        return [
          _buildCertificateTextField(
            fieldKey: 'business_name',
            label: 'Business Name',
            hint: 'Enter your business name',
          ),
          _buildCertificateTextField(
            fieldKey: 'business_address',
            label: 'Business Address',
            hint: 'Enter the business address',
          ),
          _buildCertificateTextField(
            fieldKey: 'business_type',
            label: 'Type of Business',
            hint: 'Enter the type of business',
          ),
          _buildCertificateTextField(
            fieldKey: 'years_of_operation',
            label: 'Years of Operation',
            hint: 'Enter years of operation',
          ),
        ];
      case 'tricycle_clearance':
        return [
          _buildCertificateTextField(
            fieldKey: 'operator_name',
            label: 'Driver / Operator Name',
            hint: 'Enter the driver or operator name',
          ),
          _buildCertificateTextField(
            fieldKey: 'plate_number',
            label: 'Tricycle Plate Number',
            hint: 'Enter the plate number',
          ),
          _buildCertificateTextField(
            fieldKey: 'route_area',
            label: 'Route / Area of Operation',
            hint: 'Enter the route or area of operation',
          ),
        ];
      case 'banca_clearance':
        return [
          _buildCertificateTextField(
            fieldKey: 'operator_name',
            label: 'Owner / Operator Name',
            hint: 'Enter the owner or operator name',
          ),
          _buildCertificateTextField(
            fieldKey: 'banca_name',
            label: 'Banca Name',
            hint: 'Enter the banca name',
          ),
          _buildCertificateTextField(
            fieldKey: 'banca_registration_number',
            label: 'Banca Registration Number',
            hint: 'Enter the registration number',
          ),
          _buildCertificateTextField(
            fieldKey: 'operation_area',
            label: 'Area of Operation',
            hint: 'Enter the area of operation',
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _buildCertificateTextField({
    required String fieldKey,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _certificateControllers[fieldKey],
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 14 : 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatePaymentMethodSelector() {
    final options = ["GCash", "Over-the-Counter"];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = _selectedCertificatePaymentMethod == option;
        return AppTapSurface(
          selected: isSelected,
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            setState(() {
              _selectedCertificatePaymentMethod = option;
            });
          },
          child: AnimatedContainer(
            duration: appMotionDuration(context, 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _brandBlue : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? _brandBlue : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475467),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGcashPaymentInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "GCash Payment Instructions",
            style: TextStyle(
              color: _brandBlue,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Send the payment to the GCash receiver below, then enter the reference number and upload a screenshot of your payment confirmation.",
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Receiver Name: $_demoGcashReceiverName",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "GCash Number: $_demoGcashReceiverNumber",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofUploader() {
    final hasImage = _selectedPaymentProofImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment Proof Screenshot",
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        AppTapSurface(
          onTap: _pickPaymentProofImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedPaymentProofImage!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 44,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  hasImage
                      ? "Tap to replace payment proof"
                      : "Tap to upload payment proof",
                  style: const TextStyle(
                    color: _brandBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateVariantSelector() {
    final variants = ["Good Moral", "Residency"];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Type of Certificate",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: variants.map((variant) {
              final isSelected = _selectedCertificateVariant == variant;
              return AppTapSurface(
                selected: isSelected,
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  setState(() {
                    _selectedCertificateVariant = variant;
                  });
                },
                child: AnimatedContainer(
                  duration: appMotionDuration(context, 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _brandBlue : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected ? _brandBlue : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    variant,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF475467),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    final activities = <Map<String, dynamic>>[
      ..._documentRequests,
      ..._reports,
    ]..sort((left, right) {
        final leftDate = DateTime.tryParse(
              left['created_at']?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final rightDate = DateTime.tryParse(
              right['created_at']?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return rightDate.compareTo(leftDate);
      });

    final groupedReports = <String, List<Map<String, dynamic>>>{};

    for (final activity in activities) {
      final label = _formatLongDate(activity['created_at']?.toString());
      groupedReports.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(
            activity,
          );
    }

    final rows = <Object>[
      for (final group in groupedReports.entries) ...[
        group.key,
        ...group.value
      ],
    ];

    return Column(
      children: [
        _buildServicesTopBar(
          sectionLabel: "Activity",
          title: "Monitor your activity",
          subtitle:
              "Monitor the real-time status of your active requests and incident reports.",
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _pageHorizontalPadding,
              8,
              _pageHorizontalPadding,
              12,
            ),
            child: _isLoadingReports && activities.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchResidentActivity,
                    child: ListView.builder(
                      key: const PageStorageKey('activity'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          if (_reportsLoadFailed || _documentsLoadFailed) {
                            return AppStatusMessage(
                              message:
                                  'Some activity could not be refreshed. Please try again.',
                              icon: Icons.cloud_off_rounded,
                              onRetry: _isLoadingReports
                                  ? null
                                  : _fetchResidentActivity,
                            );
                          }
                          return activities.isEmpty
                              ? const AppStatusMessage(
                                  message:
                                      'No activity yet. Your reports and document requests will appear here.')
                              : const SizedBox.shrink();
                        }
                        final row = rows[index - 1];
                        if (row is String) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                                4, index == 1 ? 0 : 10, 4, 10),
                            child: Text(row,
                                style: const TextStyle(
                                    color: Color(0xFF424751),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          );
                        }
                        return _buildRequestCard(row as Map<String, dynamic>);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _runAction(onTap),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF48627E),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7B8794),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 25,
              color: _brandBlue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6F7D8E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderAvatar() {
    const avatarSize = 122.0;
    const badgeBoxSize = avatarSize * 0.36;
    const badgeScale = 1.42;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD7E5F5), width: 3),
            image: _profileImage.trim().isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(_profileImage),
                    fit: BoxFit.cover,
                  ),
          ),
          child: _profileImage.trim().isEmpty
              ? const Icon(
                  Icons.person,
                  size: 66,
                  color: Color(0xFFD0D6DC),
                )
              : null,
        ),
        Positioned(
          right: -(badgeBoxSize * 0.18),
          bottom: -(badgeBoxSize * 0.16),
          child: Container(
            width: badgeBoxSize,
            height: badgeBoxSize,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: badgeScale,
              child: SvgPicture.asset(
                _verifiedCheckAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedResidentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD9EBFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            _verifiedShieldAsset,
            width: 10,
            height: 12,
            colorFilter: const ColorFilter.mode(
              Color(0xFF5B7692),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            "VERIFIED RESIDENT",
            style: TextStyle(
              color: Color(0xFF5B7692),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileContentSheet({
    required String title,
    required List<Widget> children,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 240),
              reverseDuration: Duration(milliseconds: 180)),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF004687),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSheetInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _brandBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF004687),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF424751),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFaqSheet() {
    _showProfileContentSheet(
      title: "FAQ",
      children: const [
        _ProfileFaqItem(
          question: "How do I file a report?",
          answer:
              "Go to Services, tap File a Report, choose a category, add details, upload photos, pin the location, and submit.",
        ),
        _ProfileFaqItem(
          question: "How can I track my report?",
          answer:
              "Open Activity to view your report status. Tap View details to see the timeline and official updates.",
        ),
        _ProfileFaqItem(
          question: "How do I request a document?",
          answer:
              "Go to Services, tap Request Document, choose the certificate you need, and submit the request form.",
        ),
        _ProfileFaqItem(
          question: "Why is my account marked verified?",
          answer:
              "Verified Resident means your account information has been validated by the barangay records team.",
        ),
      ],
    );
  }

  void _showContactBarangaySheet() {
    _showProfileContentSheet(
      title: "Contact Barangay Hall",
      children: [
        _buildProfileSheetInfoRow(
          icon: Icons.location_on_outlined,
          title: "Barangay Hall Address",
          subtitle: "Bancao-Bancao, Puerto Princesa City",
        ),
        _buildProfileSheetInfoRow(
          icon: Icons.call_outlined,
          title: "Contact Number",
          subtitle: "+63 917 123 4567",
        ),
        _buildProfileSheetInfoRow(
          icon: Icons.schedule_outlined,
          title: "Office Hours",
          subtitle: "Monday to Friday, 8:00 AM to 5:00 PM",
        ),
        _buildProfileSheetInfoRow(
          icon: Icons.mail_outline_rounded,
          title: "Email",
          subtitle: "barangay.bancaobancao@example.com",
        ),
      ],
    );
  }

  void _showTermsSheet() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const _BarangayTermsOfServiceScreen(),
      ),
    );
  }

  Future<void> _showNotificationPreferencesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 240),
              reverseDuration: Duration(milliseconds: 180)),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updatePreference(void Function() update) {
              setState(update);
              setSheetState(() {});
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Notification Preferences",
                              style: TextStyle(
                                color: Color(0xFF004687),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      value: _notifyAnnouncements,
                      activeThumbColor: _brandBlue,
                      title: const Text("Barangay announcements"),
                      subtitle:
                          const Text("Get notified about public updates."),
                      onChanged: (value) => updatePreference(
                        () => _notifyAnnouncements = value,
                      ),
                    ),
                    SwitchListTile(
                      value: _notifyReportUpdates,
                      activeThumbColor: _brandBlue,
                      title: const Text("Report updates"),
                      subtitle:
                          const Text("Receive status changes for reports."),
                      onChanged: (value) => updatePreference(
                        () => _notifyReportUpdates = value,
                      ),
                    ),
                    SwitchListTile(
                      value: _notifyDocumentUpdates,
                      activeThumbColor: _brandBlue,
                      title: const Text("Document requests"),
                      subtitle:
                          const Text("Receive certificate request updates."),
                      onChanged: (value) => updatePreference(
                        () => _notifyDocumentUpdates = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileTab() {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('profile'),
        padding: const EdgeInsets.fromLTRB(
          _pageHorizontalPadding,
          _topBarTopPadding,
          _pageHorizontalPadding,
          12,
        ),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Profile",
                  style: TextStyle(
                    color: _brandBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildTopActionButton(
                onTap: _openAnnouncementNotifications,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: _buildProfileHeaderAvatar()),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _fullName.isEmpty ? "Resident" : _fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Center(child: _buildVerifiedResidentBadge()),
          const SizedBox(height: 26),
          const Text(
            "Personal Information",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildProfileInfoRow(
                  icon: Icons.location_on_outlined,
                  label: "RESIDENCY PUROK",
                  text: _address,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileInfoRow(
                  icon: Icons.call_outlined,
                  label: "CONTACT NUMBER",
                  text: _contactNumber,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileInfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: "EMAIL ADDRESS",
                  text: _profileEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            "Account",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildProfileTile(
                  icon: Icons.edit_outlined,
                  title: "Edit Profile",
                  onTap: _openEditProfile,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileTile(
                  icon: Icons.shield_outlined,
                  title: "Privacy & Security",
                  onTap: _openPrivacySecurity,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileTile(
                  icon: Icons.notifications_none_rounded,
                  title: "Notification Preferences",
                  onTap: _showNotificationPreferencesSheet,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileTile(
                  icon: Icons.logout_rounded,
                  title: "Log out",
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            "Help & Support",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildProfileTile(
                  icon: Icons.help_outline_rounded,
                  title: "FAQ",
                  onTap: _showFaqSheet,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileTile(
                  icon: Icons.support_agent_rounded,
                  title: "Contact Barangay Hall",
                  onTap: _showContactBarangaySheet,
                ),
                const Divider(height: 1, color: Color(0xFFF3F6F9)),
                _buildProfileTile(
                  icon: Icons.gavel_rounded,
                  title: "Terms of Service",
                  onTap: _showTermsSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyByTab() {
    switch (_currentTab) {
      case 0:
        return _buildStyledHomeTab();
      case 1:
        switch (_serviceView) {
          case _ResidentServiceView.reportForm:
            return _buildReportTab();
          case _ResidentServiceView.certificates:
            return _buildCertificatesTab();
          case _ResidentServiceView.certificateRequestForm:
            return _buildCertificateRequestFormTab();
          case _ResidentServiceView.menu:
            return _buildServicesMenuTab();
        }
      case 2:
        return _buildActivityTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildStyledHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: PopScope(
        canPop: _currentTab == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _goBackWithinDashboard();
        },
        child: AppContentSwitcher(
            child: KeyedSubtree(
          key: ValueKey(
              Object.hash(_currentTab, _currentTab == 1 ? _serviceView : null)),
          child: _buildBodyByTab(),
        )),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _currentTab,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.white,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: _brandBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        destinations: const [
          NavigationDestination(
            icon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/home_menu.svg',
            ),
            selectedIcon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/home_menu_active.svg',
            ),
            label: "Home",
          ),
          NavigationDestination(
            icon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/services_menu.svg',
            ),
            selectedIcon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/services_menu_active.svg',
            ),
            label: "Services",
          ),
          NavigationDestination(
            icon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/activity_menu.svg',
            ),
            selectedIcon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/activity_menu_active.svg',
            ),
            label: "Activity",
          ),
          NavigationDestination(
            icon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/profile_menu.svg',
            ),
            selectedIcon: _BottomNavSvgIcon(
              assetPath: 'lib/assets/menu_icons/profile_menu_active.svg',
            ),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class _BarangayTermsOfServiceScreen extends StatelessWidget {
  const _BarangayTermsOfServiceScreen();

  static const _sections = [
    (
      title: "1. Purpose of the Service",
      body:
          "This mobile application is provided as a digital channel for residents to communicate with the barangay, submit incident reports, request barangay documents, receive announcements, and monitor the status of submitted services. It supports official barangay operations but does not replace direct coordination with barangay personnel during emergencies or urgent public safety concerns.",
    ),
    (
      title: "2. Resident Account Responsibility",
      body:
          "Residents are responsible for keeping their account information accurate, updated, and secure. Names, contact numbers, email addresses, residency information, and verification details must reflect true resident records. Users must not share account access with another person or use another resident's account to submit requests.",
    ),
    (
      title: "3. Accurate Reports and Requests",
      body:
          "All incident reports, service requests, photos, descriptions, and pinned locations must be truthful and related to legitimate barangay concerns. Reports may include road damage, drainage issues, garbage collection concerns, public safety matters, damaged facilities, or other community service issues. False, misleading, duplicate, malicious, or abusive submissions may be rejected, archived, or referred for review.",
    ),
    (
      title: "4. Emergency and Safety Limitations",
      body:
          "The app may be used to report community concerns, but it is not a substitute for emergency hotlines, rescue units, medical responders, police assistance, or direct barangay emergency response. For immediate threats to life, health, fire, crime, disaster, or serious injury, residents should contact the appropriate emergency hotline or proceed directly to the barangay hall or nearest authority.",
    ),
    (
      title: "5. Document Request Processing",
      body:
          "Requests for barangay clearance, residency certification, and other official documents are subject to verification, eligibility requirements, barangay records, required fees if applicable, and approval by authorized personnel. Submission through the app does not guarantee automatic approval. The barangay may request additional information before releasing any document.",
    ),
    (
      title: "6. Use of Personal Information",
      body:
          "Personal information submitted through the app may be used for resident verification, report validation, document processing, official communication, audit trails, service monitoring, and barangay record keeping. The barangay will handle resident information with reasonable care and will limit access to authorized personnel who need the information for official duties.",
    ),
    (
      title: "7. Photos, Location, and Supporting Evidence",
      body:
          "Residents may upload photos and provide map locations to help barangay personnel identify and assess reported issues. Uploaded images should be relevant to the report and must not intentionally expose private, sensitive, harmful, or unrelated personal content. Location data is used to locate the reported concern and support response planning.",
    ),
    (
      title: "8. Notifications and Official Updates",
      body:
          "The app may send announcements, report status changes, document updates, and other service notifications. Status timelines and official updates are provided for resident convenience and may change as barangay personnel verify, assign, inspect, resolve, or close requests. Residents should review updates regularly and follow any instructions provided by the barangay.",
    ),
    (
      title: "9. Prohibited Use",
      body:
          "Residents must not use the app to harass others, submit offensive content, impersonate another person, upload harmful files, disrupt system operations, attempt unauthorized access, spread false information, or use barangay services for fraudulent activity. Any misuse may result in request rejection, account restriction, or referral to appropriate authorities when necessary.",
    ),
    (
      title: "10. Availability and Technical Limitations",
      body:
          "The barangay aims to keep the app available and useful, but service interruptions may occur due to internet connectivity, maintenance, device issues, server downtime, mapping limitations, or third-party service interruptions. Residents may still contact the barangay hall directly when the app is unavailable or when a request requires immediate attention.",
    ),
    (
      title: "11. Review, Correction, and Follow-Up",
      body:
          "Barangay personnel may review submitted information, correct categorization, update status, contact the resident for clarification, or close requests that are resolved, invalid, incomplete, or outside barangay jurisdiction. Residents may be asked to provide additional details to support proper action.",
    ),
    (
      title: "12. Changes to These Terms",
      body:
          "These terms may be updated to reflect changes in barangay procedures, application features, privacy practices, or service requirements. Continued use of the app after updates means the resident agrees to follow the revised terms. Residents are encouraged to review this page periodically.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF004687),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Terms of Service",
                    style: TextStyle(
                      color: Color(0xFF004687),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Barangay Digital Services Terms",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Last updated: May 16, 2026",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Please read these terms carefully before using the barangay mobile application. These terms explain resident responsibilities, service limitations, and how submitted information may be used for official barangay services.",
                    style: TextStyle(
                      color: Color(0xFF424751),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._sections.map(
              (section) => _TermsSectionCard(
                title: section.title,
                body: section.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSectionCard extends StatelessWidget {
  const _TermsSectionCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF004687),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF424751),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFaqItem extends StatelessWidget {
  const _ProfileFaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: const Color(0xFF0B4F94),
        collapsedIconColor: const Color(0xFF7B8794),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          question,
          style: const TextStyle(
            color: Color(0xFF004687),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              color: Color(0xFF424751),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavSvgIcon extends StatelessWidget {
  const _BottomNavSvgIcon({
    required this.assetPath,
  });

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ResidentDashboardScreenState._bottomNavIconSize,
      height: _ResidentDashboardScreenState._bottomNavIconSize,
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, 5),
          child: SvgPicture.asset(
            assetPath,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _DashedServiceRectPainter extends CustomPainter {
  const _DashedServiceRectPainter({
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
  bool shouldRepaint(covariant _DashedServiceRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
