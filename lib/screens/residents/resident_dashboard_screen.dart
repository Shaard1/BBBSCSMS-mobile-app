import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/announcement_model.dart';
import '../../services/announcement_service.dart';
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
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  static const String _verifiedShieldAsset =
      'lib/assets/Verified Resident badge.svg';
  static const String _verifiedCheckAsset =
      'lib/assets/Verified check badge.svg';
  final SupabaseClient _supabase = Supabase.instance.client;
  final AnnouncementService _announcementService = AnnouncementService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  static const int _minAnnouncementFontSize = 1;
  static const int _maxAnnouncementFontSize = 144;
  static const Color _teal = Color(0xFF0B7A6D);
  static const Color _brandBlue = Color(0xFF0B4F94);
  static const Color _gold = Color(0xFFF1A400);
  static const Color _softBlue = Color(0xFFEAF3FF);
  static const Color _pageBackground = Color(0xFFF4F6F7);
  static const double _pageHorizontalPadding = 16;
  static const double _topBarTopPadding = 14;
  static const double _topActionSize = 48;

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
  bool _isLoadingAnnouncements = true;
  bool _isSubmittingReport = false;
  bool _isFetchingLocation = false;

  String _fullName = "";
  String _address = "Address not set";
  String _contactNumber = "No contact number";
  String _profileImage = "";
  String _reportLocationLabel = "Tap to choose location on map";

  static const int _maxReportImages = 10;
  final List<File> _selectedReportImages = [];
  double? _reportLatitude;
  double? _reportLongitude;
  List<Map<String, dynamic>> _reports = [];
  List<Announcement> _announcements = [];
  Set<String> _readAnnouncementIds = {};

  int get _unreadAnnouncementCount => _announcements
      .where((announcement) => !_readAnnouncementIds.contains(announcement.id))
      .length;

  List<Map<String, String>> get _certificateOptions => const [
        {
          'title': 'Barangay Clearance',
          'price': '\u20B1 50.00',
          'description':
              'For employment, business permit, or general identification.',
          'meta': '1-2 Working Days',
        },
        {
          'title': 'Cedula / Community Tax Certificate',
          'price': '\u20B1 50.00',
          'description':
              'Required for various government and legal transactions.',
          'meta': 'Instant Issuance',
        },
        {
          'title': 'Indigency Certificate',
          'price': 'FREE',
          'description':
              'For scholarship applications, medical assistance, and social welfare.',
          'meta': 'Evaluation Required',
        },
        {
          'title': 'Residency Certificate',
          'price': 'FREE',
          'description': 'Proof of residency within the barangay.',
          'meta': '1-2 Working Days',
        },
      ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
    _fullName = widget.name.trim();
    _loadResidentProfile();
    _fetchMyReports();
    _fetchAnnouncements();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
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

      if (user != null) {
        try {
          readIds =
              await _announcementService.fetchReadAnnouncementIds(user.id);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _readAnnouncementIds = readIds;
        _isLoadingAnnouncements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _announcements = [];
        _readAnnouncementIds = {};
        _isLoadingAnnouncements = false;
      });
    }
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

  Future<void> _fetchMyReports() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingReports = false;
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
        _reports = List<Map<String, dynamic>>.from(data);
        _isLoadingReports = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reports = [];
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _deleteMyReport(String reportId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar("Session expired. Please log in again.");
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete report?"),
          content: const Text(
            "Are you sure you want to remove this report?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _supabase
          .from('reports')
          .delete()
          .eq('id', reportId)
          .eq('user_id', user.id);

      await _fetchMyReports();
      _showSnackBar("Report deleted.");
    } catch (e) {
      _showSnackBar("Failed to delete report: $e");
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

      await _fetchMyReports();
      _showSnackBar("Report submitted successfully.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingReport = false);
      _showSnackBar("Failed to submit report: $e");
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
    } catch (e) {
      _showSnackBar("Failed to get location: $e");
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _statusChipColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == "completed" || normalized == "resolved") {
      return const Color(0xFF2E7D32);
    }
    if (normalized == "in_process" || normalized == "in progress") {
      return const Color(0xFFEF6C00);
    }
    return const Color(0xFF9E9E00);
  }

  String _statusLabel(String status) {
    final normalized = status.toLowerCase();
    if (normalized == "in_process" || normalized == "in progress") {
      return "In Progress";
    }
    if (normalized == "completed") return "Completed";
    if (normalized == "resolved") return "Resolved";
    return "Pending";
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

  void _showFullReportImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
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
        );
      },
    );
  }

  Widget _buildReportLocationPreview(Map<String, dynamic> report) {
    final latitude = (report['latitude'] as num?)?.toDouble();
    final longitude = (report['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8E1E4)),
        ),
        child: const Text("No location data available."),
      );
    }

    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'com.example.barangay_mobile_app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 40,
                  height: 40,
                  point: point,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          child: SizedBox(
            width: double.infinity,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Report Location",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _formatCoordinates(latitude, longitude),
                    style: const TextStyle(color: Color(0xFF667077)),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    final statusColor =
        _statusChipColor(report['status']?.toString() ?? 'pending');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D8DC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF203036),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Description",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF203036),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            height: 1.5,
                            color: Color(0xFF5F6A71),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          "Submitted",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF203036),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDetailedReportDate(
                              report['created_at']?.toString()),
                          style: const TextStyle(color: Color(0xFF5F6A71)),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          "Images",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF203036),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (images.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8F9),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFD8E1E4)),
                            ),
                            child: const Text("No images uploaded."),
                          )
                        else ...[
                          GestureDetector(
                            onTap: () => _showFullReportImage(images.first),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                images.first,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (images.length > 1) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                separatorBuilder: (context, separatorIndex) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final image = images[index];
                                  return GestureDetector(
                                    onTap: () => _showFullReportImage(image),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        image,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 14),
                        const Text(
                          "Location",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF203036),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildReportLocationPreview(report),
                        if (latitude != null && longitude != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _formatCoordinates(latitude, longitude),
                            style: const TextStyle(color: Color(0xFF5F6A71)),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _showReportLocationDialog(report),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text("Open full map"),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          "Admin Note",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF203036),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD8E1E4)),
                          ),
                          child: Text(
                            adminNote.isEmpty
                                ? "No update from the barangay admin yet."
                                : adminNote,
                            style: const TextStyle(
                              height: 1.4,
                              color: Color(0xFF5F6A71),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD9534F),
                              side: const BorderSide(color: Color(0xFFF2C8C7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              final reportId = report['id']?.toString() ?? '';
                              if (reportId.isNotEmpty) {
                                await _deleteMyReport(reportId);
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text("Delete Report"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

    if (ops.isEmpty) {
      return _parseMarkupAnnouncementLines(rawContent);
    }

    return _buildAnnouncementLinesFromOps(ops);
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
          const Color(0xFF505A60),
      fontSize: fontSize ?? 14,
      height: 1.55,
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E1E4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
              if (index != lines.length - 1) const SizedBox(height: 6),
            ],
            if (lines.isEmpty)
              const Text(
                "No announcement details available.",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAnnouncementDetails(Announcement announcement) async {
    await _markAnnouncementsRead([announcement.id]);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D8DC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203036),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatAnnouncementDate(announcement.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                    if (announcement.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _showFullReportImage(
                          announcement.thumbnailUrl.isNotEmpty
                              ? announcement.thumbnailUrl
                              : announcement.imageUrls.first,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            announcement.thumbnailUrl.isNotEmpty
                                ? announcement.thumbnailUrl
                                : announcement.imageUrls.first,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (announcement.imageUrls.length > 1) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 74,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: announcement.imageUrls.length,
                            separatorBuilder: (context, separatorIndex) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final imageUrl = announcement.imageUrls[index];
                              return GestureDetector(
                                onTap: () => _showFullReportImage(imageUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    width: 74,
                                    height: 74,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    _buildAnnouncementRichContent(announcement.content),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Close",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAnnouncementNotifications() async {
    await _markAnnouncementsRead(
      _announcements.map((announcement) => announcement.id).toList(),
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: _pageBackground,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Notifications",
                          style: TextStyle(
                            color: _brandBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: _buildTopActionButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          color: _brandBlue,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Stay updated with community alerts and local news.",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isLoadingAnnouncements)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_announcements.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: const Text(
                            "No announcements yet.",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        ...List.generate(_announcements.length, (index) {
                          return _buildNotificationCard(
                            _announcements[index],
                            emphasized: index == 0 &&
                                _announcementShouldHighlight(
                                  _announcements[index],
                                ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
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

  String _formatNotificationTime(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) {
      return "Just now";
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return "$minutes min${minutes == 1 ? '' : 's'} ago";
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return "$hours hr${hours == 1 ? '' : 's'} ago";
    }
    return _formatLongDate(value.toIso8601String());
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

  bool _announcementShouldHighlight(Announcement announcement) {
    final haystack =
        "${announcement.title} ${announcement.content}".toLowerCase();
    return haystack.contains("severe") ||
        haystack.contains("weather") ||
        haystack.contains("storm") ||
        haystack.contains("flood") ||
        haystack.contains("warning") ||
        haystack.contains("urgent");
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

  Widget _buildNotificationCard(
    Announcement announcement, {
    required bool emphasized,
  }) {
    final cardColor = emphasized ? const Color(0xFF9C0012) : Colors.white;
    final borderColor =
        emphasized ? Colors.transparent : const Color(0xFFE5EAF1);
    final titleColor = emphasized ? Colors.white : const Color(0xFF1F2937);
    final bodyColor =
        emphasized ? const Color(0xFFFCE7EA) : const Color(0xFF475569);
    final metaColor =
        emphasized ? const Color(0xFFFDE6EA) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: emphasized
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAnnouncementDetails(announcement),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: emphasized
                          ? const Color(0xFF7F000F)
                          : const Color(0xFFFFEEE8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _announcementBadgeLabel(announcement),
                      style: TextStyle(
                        color:
                            emphasized ? Colors.white : const Color(0xFFF0643B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatNotificationTime(announcement.createdAt),
                    style: TextStyle(
                      color: metaColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                announcement.title.trim().isEmpty
                    ? "Barangay Notification"
                    : announcement.title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _plainAnnouncementPreview(announcement),
                style: TextStyle(
                  color: bodyColor,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openServiceView(_ResidentServiceView view) {
    setState(() {
      _currentTab = 1;
      _serviceView = view;
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentTab = index;
      if (index == 1) {
        _serviceView = _ResidentServiceView.menu;
      }
    });
  }

  Future<void> _showCategorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8DEE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Choose an issue category",
                    style: TextStyle(
                      color: Color(0xFF103B69),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._categories.map((category) {
                    final selected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _selectedCategory = category);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFF4F8FD)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? _brandBlue
                                    : const Color(0xFFE4E9F1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: selected
                                          ? _brandBlue
                                          : const Color(0xFF2B3B4D),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: _brandBlue,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: _topActionSize,
      height: _topActionSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE3E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: const Color(0xFF4D5D70), size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: 24,
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
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF344250),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionText,
              style: const TextStyle(
                color: _brandBlue,
                fontWeight: FontWeight.w700,
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
    final cardWidth = (contentWidth * 0.8).clamp(246.0, 286.0).toDouble();
    final previewItems = _announcements.take(5).toList();

    return SizedBox(
      height: 147,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
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

    return InkWell(
      onTap: () => _showAnnouncementDetails(item),
      borderRadius: BorderRadius.circular(6),
      child: Ink(
        width: width,
        height: 147,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
          image: imageUrl.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required Color accent,
    required Color bg,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
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
      onTap: onTap,
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Mabuhay,",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fullName.isEmpty ? "Resident" : _fullName,
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildTopActionButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: _openAnnouncementNotifications,
                      ),
                      if (_unreadAnnouncementCount > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 10,
                            height: 10,
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
              color: _brandBlue,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: const Text(
                "Stay updated with the latest community news and access essential barangay services.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
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
          _fetchMyReports(),
          _fetchAnnouncements(),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHomeHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: "Announcement",
                  actionText: "View all",
                  onAction: _openAnnouncementNotifications,
                ),
                const SizedBox(height: 12),
                _buildHomeAnnouncementHighlight(),
                const SizedBox(height: 24),
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    color: Color(0xFF344250),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  accent: _gold,
                  bg: const Color(0xFFFFFAEF),
                  icon: Icons.campaign_outlined,
                  title: "File a report",
                  subtitle: "Report a community problem",
                  onTap: () =>
                      _openServiceView(_ResidentServiceView.reportForm),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCard(
                  accent: const Color(0xFF0D8B83),
                  bg: const Color(0xFFF2FBFA),
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
                    color: Color(0xFF344250),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ongoingReports.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            "No ongoing services right now.",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : Column(
                          children:
                              List.generate(ongoingReports.length, (index) {
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
                                  iconColor: _brandBlue,
                                  iconBg: _softBlue,
                                  title: category,
                                  subtitle: subtitle,
                                  onTap: () => _showReportDetails(report),
                                ),
                                if (index != ongoingReports.length - 1)
                                  const Divider(
                                      height: 18, color: Color(0xFFE8EDF3)),
                              ],
                            );
                          }),
                        ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Recent Activity",
                  style: TextStyle(
                    color: Color(0xFF344250),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: recentReports.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            "No recent activity yet.",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : Column(
                          children:
                              List.generate(recentReports.length, (index) {
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
                                  onTap: () => _showReportDetails(report),
                                ),
                                if (index != recentReports.length - 1)
                                  const Divider(
                                      height: 18, color: Color(0xFFE8EDF3)),
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
  }) {
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
                GestureDetector(
                  onTap: allowBackToMenu
                      ? () {
                          setState(
                              () => _serviceView = _ResidentServiceView.menu);
                        }
                      : null,
                  child: Text(
                    sectionLabel,
                    style: TextStyle(
                      color: _brandBlue,
                      fontSize: 13,
                      fontWeight:
                          allowBackToMenu ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                _buildTopActionButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: _openAnnouncementNotifications,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                color: _brandBlue,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceEntryCard({
    required Color accent,
    required Color background,
    required IconData icon,
    required String title,
    required String description,
    required String cta,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(28, 26, 24, 22),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0E7F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cta,
                  style: const TextStyle(
                    color: _brandBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: _brandBlue,
                  size: 14,
                ),
              ],
            ),
          ],
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
        onTap: onTap,
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
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildServicesTopBar(
          sectionLabel: "Services",
          title: "How can we assist\nyou today?",
          subtitle:
              "Access essential barangay services, request official documentation, or report local concerns directly to your community leaders.",
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _pageHorizontalPadding,
            28,
            _pageHorizontalPadding,
            24,
          ),
          child: Column(
            children: [
              _buildServiceEntryCard(
                accent: _gold,
                background: const Color(0xFFFFFAEF),
                icon: Icons.campaign_outlined,
                title: "File a Report",
                description:
                    "Report emergencies, infrastructure issues, or community concerns directly.",
                cta: "PROCEED",
                onTap: () => setState(() {
                  _serviceView = _ResidentServiceView.reportForm;
                }),
              ),
              const SizedBox(height: 22),
              _buildServiceEntryCard(
                accent: const Color(0xFF0D8B83),
                background: const Color(0xFFF2FBFA),
                icon: Icons.description_outlined,
                title: "Request Certificate",
                description:
                    "Apply for Barangay Clearance, Residency, and other official certificates.",
                cta: "APPLY NOW",
                onTap: () => setState(() {
                  _serviceView = _ResidentServiceView.certificates;
                }),
              ),
            ],
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
                            child: GestureDetector(
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

  Widget _buildRequestCard(Map<String, dynamic> report) {
    final status = (report['status'] as String?) ?? "pending";
    final statusLabel = _statusLabel(status).toUpperCase();
    final statusColor = _statusChipColor(status);
    final category = (report['category'] as String?)?.trim();
    final description = (report['description'] as String?)?.trim();
    final title = (category != null && category.isNotEmpty)
        ? category
        : "Community concern";
    final subtitle = (description != null && description.isNotEmpty)
        ? description
        : "Track the latest update for this request.";
    final normalizedStatus = status.toLowerCase();
    final iconData =
        normalizedStatus == "completed" || normalizedStatus == "resolved"
            ? Icons.description_outlined
            : Icons.campaign_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconData,
                  color: const Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showReportDetails(report),
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
                                fontSize: 12,
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
      padding: EdgeInsets.zero,
      children: [
        _buildServicesTopBar(
          sectionLabel: "Services",
          title: "Request Document",
          subtitle:
              "Secure your official barangay certifications and permits online. Fast, efficient, and direct.",
          allowBackToMenu: true,
        ),
        const SizedBox(height: 12),
        ..._certificateOptions.map((item) {
          final price = item['price'] ?? '';
          final isFree = price.toUpperCase() == 'FREE';
          return Container(
            margin: const EdgeInsets.fromLTRB(
              _pageHorizontalPadding,
              0,
              _pageHorizontalPadding,
              12,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      price,
                      style: TextStyle(
                        color: isFree ? const Color(0xFFD4263A) : _brandBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['description'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['meta'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        _showSnackBar("${item['title']} request submitted.");
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Request",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivityTab() {
    final groupedReports = <String, List<Map<String, dynamic>>>{};

    for (final report in _reports) {
      final label = _formatLongDate(report['created_at']?.toString());
      groupedReports.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(
            report,
          );
    }

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
            child: _isLoadingReports
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? const Center(
                        child: Text(
                          "No activity yet.",
                          style: TextStyle(color: Color(0xFF667077)),
                        ),
                      )
                    : ListView(
                        children: groupedReports.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(4, 0, 4, 10),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                ...entry.value.map(_buildRequestCard),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final iconColor = danger ? const Color(0xFFEF4444) : _brandBlue;
    final borderColor =
        danger ? const Color(0xFFF6D3D7) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: danger
                            ? const Color(0xFFD9485F)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color:
                    danger ? const Color(0xFFCC6E7A) : const Color(0xFF94A3B8),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF4E657C),
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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
                  size: 58,
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

  Widget _buildProfileTab() {
    return SafeArea(
      bottom: false,
      child: ListView(
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildTopActionButton(
                icon: Icons.notifications_none_rounded,
                onTap: _openAnnouncementNotifications,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: _buildProfileHeaderAvatar()),
          const SizedBox(height: 18),
          Center(
            child: Text(
              _fullName.isEmpty ? "Resident" : _fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _buildVerifiedResidentBadge()),
          const SizedBox(height: 20),
          const Text(
            "Personal Information",
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 14),
          _buildProfileTile(
            icon: Icons.edit_outlined,
            title: "Edit Profile",
            subtitle: "Update your resident details.",
            onTap: _openEditProfile,
          ),
          _buildProfileTile(
            icon: Icons.shield_outlined,
            title: "Privacy & Security",
            subtitle: "Manage your account password and privacy.",
            onTap: _openPrivacySecurity,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD73A49),
                size: 18,
              ),
              label: const Text(
                "Logout from Account",
                style: TextStyle(
                  color: Color(0xFFD73A49),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text(
              "VERSION 2.4.1 (BUILD 82)",
              style: TextStyle(
                color: Color(0xFF9AA5B1),
                fontSize: 10,
                letterSpacing: 0.5,
              ),
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
      body: _buildBodyByTab(),
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
            icon: Icon(Icons.home_outlined, color: Color(0xFF64748B), size: 31),
            selectedIcon:
                Icon(Icons.home_outlined, color: _brandBlue, size: 31),
            label: "Home",
          ),
          NavigationDestination(
            icon: _ServicesNavIcon(color: Color(0xFF64748B)),
            selectedIcon: _ServicesNavIcon(color: _brandBlue),
            label: "Services",
          ),
          NavigationDestination(
            icon:
                Icon(Icons.history_rounded, color: Color(0xFF64748B), size: 31),
            selectedIcon:
                Icon(Icons.history_rounded, color: _brandBlue, size: 31),
            label: "Activity",
          ),
          NavigationDestination(
            icon:
                Icon(Icons.person_outline, color: Color(0xFF64748B), size: 31),
            selectedIcon:
                Icon(Icons.person_outline, color: _brandBlue, size: 31),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

class _ServicesNavIcon extends StatelessWidget {
  const _ServicesNavIcon({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 31,
      height: 31,
      child: Center(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(
            9,
            (_) => Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
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
