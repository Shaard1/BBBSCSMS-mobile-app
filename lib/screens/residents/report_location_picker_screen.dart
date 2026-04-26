import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ReportLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const ReportLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<ReportLocationPickerScreen> createState() =>
      _ReportLocationPickerScreenState();
}

class _ReportLocationPickerScreenState extends State<ReportLocationPickerScreen> {
  static const LatLng _palawanCenter = LatLng(9.7392, 118.7353);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedPoint;
  bool _isSearching = false;
  bool _isFetchingCurrent = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'jsonv2',
          'limit': '6',
          'countrycodes': 'ph',
          'addressdetails': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'barangay_mobile_app_location_picker',
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Search failed (${response.statusCode}).");
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception("Unexpected search response.");
      }

      final results = decoded
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        if (_searchResults.isEmpty) {
          _searchError = "No locations found. Try another keyword.";
        }
      });

      if (results.isNotEmpty) {
        final firstLat = double.tryParse(results.first['lat']?.toString() ?? '');
        final firstLng = double.tryParse(results.first['lon']?.toString() ?? '');

        if (firstLat != null && firstLng != null) {
          _mapController.move(LatLng(firstLat, firstLng), 16);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = "Unable to search location right now.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetchingCurrent) return;

    setState(() {
      _isFetchingCurrent = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Location service is disabled.");
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
          "Location permission denied forever. Enable it in settings.",
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedPoint = point;
      });

      _mapController.move(point, 17);
      _showSnackBar("Current location pinned.");
    } catch (_) {
      if (!mounted) return;
      _showSnackBar("Failed to get current location.");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCurrent = false;
        });
      }
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;

    final point = LatLng(lat, lng);

    setState(() {
      _selectedPoint = point;
    });

    _mapController.move(point, 17);
  }

  void _confirmLocation() {
    if (_selectedPoint == null) {
      _showSnackBar("Please pin a location on the map first.");
      return;
    }

    Navigator.pop(context, {
      'latitude': _selectedPoint!.latitude,
      'longitude': _selectedPoint!.longitude,
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPoint = _selectedPoint ?? _palawanCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Report Location"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchLocation(),
                    decoration: InputDecoration(
                      hintText: "Search place (street, purok, landmark)",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchLocation,
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Search"),
                ),
              ],
            ),
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _searchError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(vertical: 4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDDE3E5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (_, index) {
                  final item = _searchResults[index];
                  final name = item['display_name']?.toString() ?? 'Unknown place';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectSearchResult(item),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialPoint,
                    initialZoom: 13,
                    onTap: (_, point) {
                      setState(() {
                        _selectedPoint = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.capstone_app',
                    ),
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 44,
                            height: 44,
                            point: _selectedPoint!,
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _selectedPoint == null
                      ? "Tap map to pin exact location."
                      : "Pinned: ${_selectedPoint!.latitude.toStringAsFixed(6)}, ${_selectedPoint!.longitude.toStringAsFixed(6)}",
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isFetchingCurrent ? null : _useCurrentLocation,
                        icon: _isFetchingCurrent
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_outlined),
                        label: const Text("Use Current"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedPoint == null ? null : _confirmLocation,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Confirm Location"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
