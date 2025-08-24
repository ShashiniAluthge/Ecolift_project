import 'package:eco_lift/screens/collector_dashboard.dart';
import 'package:eco_lift/screens/view_pickup_location.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';

class NotificationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> customerDetails;
  final Map<String, dynamic>? notificationData;

  const NotificationDetailsScreen({
    super.key,
    required this.customerDetails,
    this.notificationData,
  });

  @override
  State<NotificationDetailsScreen> createState() =>
      _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState extends State<NotificationDetailsScreen> {
  String _locationDisplayText = 'Loading location...';
  Map<String, dynamic>? _parsedLocationData;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _processLocationData();
  }

  Future<void> _processLocationData() async {
    final location = widget.notificationData?['location'];

    if (location == null) {
      setState(() {
        _locationDisplayText = 'No location data';
        _isLoadingLocation = false;
      });
      return;
    }

    try {
      // If location is already a readable string (not coordinates)
      if (location is String && !location.contains('coordinates')) {
        setState(() {
          _locationDisplayText = _cleanLocationString(location);
          _isLoadingLocation = false;
        });
        return;
      }

      // If location is a map with displayName or fullAddress
      if (location is Map<String, dynamic>) {
        if (location['displayName'] != null ||
            location['fullAddress'] != null) {
          final displayText = location['displayName'] ??
              location['fullAddress'] ??
              'Unknown Location';
          setState(() {
            _locationDisplayText = _cleanLocationString(displayText);
            _parsedLocationData = location;
            _isLoadingLocation = false;
          });
          return;
        }
      }

      // Parse coordinates and get readable address
      await _parseCoordinatesAndGetAddress(location);
    } catch (e) {
      print('Error processing location: $e');
      setState(() {
        _locationDisplayText = 'Error loading location';
        _isLoadingLocation = false;
      });
    }
  }

  String _cleanLocationString(String locationString) {
    // Remove plus codes (alphanumeric codes like WGXW+VP5)
    String cleaned =
        locationString.replaceAll(RegExp(r'[A-Z0-9]{4}\+[A-Z0-9]{2,3}'), '');

    // Remove any remaining standalone numbers or letter-number combinations
    cleaned = cleaned.replaceAll(RegExp(r'\b[A-Z0-9]{2,}\b'), '');

    // Clean up extra commas and spaces
    cleaned = cleaned.replaceAll(RegExp(r'^,\s*'), ''); // Remove leading comma
    cleaned = cleaned.replaceAll(RegExp(r',\s*,'), ','); // Remove double commas
    cleaned = cleaned.replaceAll(RegExp(r',\s*$'), ''); // Remove trailing comma
    cleaned = cleaned.replaceAll(
        RegExp(r'\s+'), ' '); // Replace multiple spaces with single space
    cleaned = cleaned.trim();

    // If nothing meaningful remains, return a fallback
    if (cleaned.isEmpty || cleaned.length < 3) {
      return 'Location not specified';
    }

    return cleaned;
  }

  Future<void> _parseCoordinatesAndGetAddress(dynamic location) async {
    try {
      Map<String, dynamic>? locationMap;

      // Parse location string if it's a string
      if (location is String) {
        locationMap = jsonDecode(location) as Map<String, dynamic>;
      } else if (location is Map<String, dynamic>) {
        locationMap = location;
      }

      if (locationMap == null) {
        throw Exception('Invalid location format');
      }

      // Extract coordinates
      if (locationMap['type'] == 'Point' &&
          locationMap['coordinates'] != null) {
        final coords = locationMap['coordinates'] as List;
        if (coords.length >= 2) {
          final longitude = coords[0].toDouble();
          final latitude = coords[1].toDouble();

          // Get readable address using reverse geocoding
          String readableAddress =
              await _getAddressFromCoordinates(longitude, latitude);

          setState(() {
            _locationDisplayText = _cleanLocationString(readableAddress);
            _parsedLocationData = {
              'displayName': _cleanLocationString(readableAddress),
              'fullAddress': readableAddress,
              'coordinates': [longitude, latitude],
              'latitude': latitude,
              'longitude': longitude,
              'original': locationMap,
            };
            _isLoadingLocation = false;
          });
        } else {
          throw Exception('Invalid coordinates format');
        }
      } else {
        throw Exception('Location is not a Point type');
      }
    } catch (e) {
      print('Error parsing coordinates: $e');
      // Fallback to showing coordinates
      _showCoordinatesFallback(location);
    }
  }

  Future<String> _getAddressFromCoordinates(
      double longitude, double latitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build address string from placemark components
        List<String> addressParts = [];

        if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
        if (place.subLocality?.isNotEmpty == true)
          addressParts.add(place.subLocality!);
        if (place.locality?.isNotEmpty == true)
          addressParts.add(place.locality!);
        if (place.administrativeArea?.isNotEmpty == true)
          addressParts.add(place.administrativeArea!);

        return addressParts.join(', ');
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    // Fallback to coordinates if geocoding fails
    return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
  }

  void _showCoordinatesFallback(dynamic location) {
    try {
      Map<String, dynamic>? locationMap;

      if (location is String) {
        locationMap = jsonDecode(location) as Map<String, dynamic>;
      } else if (location is Map<String, dynamic>) {
        locationMap = location;
      }

      if (locationMap != null &&
          locationMap['type'] == 'Point' &&
          locationMap['coordinates'] != null) {
        final coords = locationMap['coordinates'] as List;
        if (coords.length >= 2) {
          final longitude = coords[0].toDouble();
          final latitude = coords[1].toDouble();

          setState(() {
            _locationDisplayText =
                'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
            _parsedLocationData = {
              'displayName': _locationDisplayText,
              'fullAddress': _locationDisplayText,
              'coordinates': [longitude, latitude],
              'latitude': latitude,
              'longitude': longitude,
              'original': locationMap,
            };
            _isLoadingLocation = false;
          });
          return;
        }
      }
    } catch (e) {
      print('Error in coordinates fallback: $e');
    }

    setState(() {
      _locationDisplayText = 'Invalid location data';
      _isLoadingLocation = false;
    });
  }

  String _formatRelativeTime(String isoString) {
    try {
      DateTime dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      }
      if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      }

      return DateFormat('MMM dd, yyyy – HH:mm').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  Map<String, dynamic> _getLocationDataForMap() {
    // Use parsed location data if available
    if (_parsedLocationData != null) {
      return _parsedLocationData!;
    }

    final location = widget.notificationData?['location'];

    if (location is Map<String, dynamic> && location['coordinates'] != null) {
      final coords = location['coordinates'] as List<dynamic>;
      if (coords.length == 2) {
        final double longitude = coords[0].toDouble();
        final double latitude = coords[1].toDouble();

        return {
          'latitude': latitude,
          'longitude': longitude,
          'displayName': "Lat: $latitude, Lng: $longitude",
          'original': location,
        };
      }
    } else if (location is String) {
      return {
        'displayName': _cleanLocationString(location),
        'fullAddress': location,
        'original': location,
      };
    }

    return {
      'displayName': 'Unknown Location',
      'fullAddress': 'Unknown Location',
      'original': location,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.notificationData?['date'] != null
        ? _formatRelativeTime(widget.notificationData?['date'])
        : '';
    final wasteTypes =
        widget.notificationData?['wasteTypes'] as List<dynamic>? ?? [];

    final address = widget.customerDetails['address'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pickup Request Details',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                        Icons.access_time, 'Notification Received', dateStr),
                    const Divider(height: 20),
                    _buildDetailRow(Icons.receipt, 'Pickup Request Id',
                        widget.notificationData?['pickupRequestId'] ?? ''),
                    const Divider(height: 20),
                    _buildLocationRow(),
                    const Divider(height: 20),
                    _buildDetailRow(
                      Icons.delete,
                      'Waste Types',
                      wasteTypes.isNotEmpty
                          ? wasteTypes.join(', ')
                          : 'Not specified',
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(Icons.person, 'Customer Name',
                        widget.customerDetails['name'] ?? ''),
                    const Divider(height: 20),
                    _buildDetailRow(Icons.phone, 'Phone Number',
                        widget.customerDetails['phone'] ?? ''),
                    const Divider(height: 20),
                    _buildDetailRow(
                      Icons.home,
                      'Address',
                      '${address['addressNo'] ?? ''}, ${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['district'] ?? ''}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoadingLocation
                      ? null
                      : () {
                          // Navigate to view pickup location screen with location data
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewPickupLocationScreen(
                                locationData: _getLocationDataForMap(),
                                customerDetails: widget
                                    .customerDetails, // pass full customer details
                                notificationData: widget.notificationData,
                                cameFromDashboard: false,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingLocation
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'View Location',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup Location:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _isLoadingLocation
                  ? const Row(
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Loading location...'),
                      ],
                    )
                  : Text(_locationDisplayText),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}
