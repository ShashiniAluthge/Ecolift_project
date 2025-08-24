import 'dart:convert';
import 'package:eco_lift/services/pickup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class ViewAcceptedPickupLocationScreen extends StatefulWidget {
  final Map<String, dynamic> locationData;
  final Map<String, dynamic> customerDetails;
  final String currentStatus;
  final String pickupRequestId;

  const ViewAcceptedPickupLocationScreen({
    super.key,
    required this.locationData,
    required this.customerDetails,
    required this.currentStatus,
    required this.pickupRequestId,
  });

  @override
  State<ViewAcceptedPickupLocationScreen> createState() =>
      _ViewAcceptedPickupLocationScreenState();
}

class _ViewAcceptedPickupLocationScreenState
    extends State<ViewAcceptedPickupLocationScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _pickupLocation;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeLocations();
  }

  Future<void> _initializeLocations() async {
    await _getCurrentPosition();
    _setPickupLocation();

    if (_currentPosition != null && _pickupLocation != null) {
      await _fetchRoute();
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting current position: $e');
    }
  }

  void _setPickupLocation() {
    try {
      final lat = widget.locationData['latitude']?.toDouble();
      final lng = widget.locationData['longitude']?.toDouble();

      if (lat != null && lng != null) {
        setState(() {
          _pickupLocation = LatLng(lat, lng);
        });

        _mapController.move(_pickupLocation!, 15);
        return;
      }

      // fallback to Colombo
      setState(() {
        _pickupLocation = const LatLng(6.9271, 79.8612);
      });
      _mapController.move(_pickupLocation!, 15);
    } catch (e) {
      print('Error setting pickup location: $e');
      setState(() {
        _pickupLocation = const LatLng(6.9271, 79.8612);
      });
      _mapController.move(_pickupLocation!, 15);
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null || _pickupLocation == null) return;

    setState(() {
      _isLoadingRoute = true;
      _routePoints = [];
    });

    try {
      final points = await getRoutePoints(_currentPosition!, _pickupLocation!);
      setState(() {
        _routePoints = points;
      });
    } catch (e) {
      print('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch route: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/"
      "${start.longitude},${start.latitude};"
      "${end.longitude},${end.latitude}?overview=full&geometries=polyline",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception('No route found');
      }

      final geometry = data['routes'][0]['geometry'];
      return _decodePolyline(geometry);
    } else {
      throw Exception('Failed to fetch route: ${response.statusCode}');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> _startPickup() async {
    try {
      // Ensure current location is available
      if (_currentPosition == null) {
        await _getCurrentPosition();
      }

      if (_currentPosition != null) {
        // 1. Send collector location to backend
        await PickupService.updateCollectorLocation(
          widget.pickupRequestId,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      // 2. Update pickup status to "In Progress"
      await PickupService.updatePickupStatus(
        widget.pickupRequestId,
        "In Progress",
      );
      Navigator.pop(context);

      // Show confirmation / Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pickup started successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to start pickup: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completePickup() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await PickupService.updatePickupStatus(
          widget.pickupRequestId, 'Completed');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup completed!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // go back after completing pickup
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Location',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pickupLocation ?? const LatLng(6.9271, 79.8612),
                initialZoom: 15,
                maxZoom: 19,
                minZoom: 3,
              ),
              children: [
                TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                if (_currentPosition != null)
                  const CurrentLocationLayer(
                    style: LocationMarkerStyle(
                      marker: DefaultLocationMarker(
                        child: Icon(Icons.my_location,
                            color: Colors.white, size: 20),
                      ),
                      markerSize: Size(35, 35),
                      markerDirection: MarkerDirection.heading,
                    ),
                  ),
                if (_pickupLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pickupLocation!,
                        width: 50,
                        height: 80,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Pickup',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const Icon(Icons.place,
                                color: Colors.red, size: 35),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                          points: _routePoints,
                          strokeWidth: 6,
                          color: Colors.red),
                    ],
                  ),
              ],
            ),
          ),

          // Customer & Location info card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.customerDetails['name'] ?? 'Unknown',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Calling ${widget.customerDetails['phone']}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.locationData['displayName'] ??
                                    'Unknown Location',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                              if (widget.locationData['fullAddress'] != null)
                                Text(
                                  widget.locationData['fullAddress'],
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isLoadingRoute)
            const Center(child: CircularProgressIndicator(color: Colors.green)),

          // Floating buttons for map control
          Positioned(
            bottom: 120,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1),
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1),
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "pickup",
                  mini: true,
                  onPressed: () {
                    if (_pickupLocation != null)
                      _mapController.move(_pickupLocation!, 16);
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.place, color: Colors.white),
                ),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: "myLocation",
                    mini: true,
                    onPressed: () => _mapController.move(_currentPosition!, 15),
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),

          // Action button at bottom
          if (widget.currentStatus.toLowerCase() == 'accepted')
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _startPickup,
                icon: _isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Icon(Icons.local_shipping, color: Colors.white),
                label: Text(
                  _isProcessing ? 'Starting...' : 'Start Pickup',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else if (widget.currentStatus.toLowerCase() == 'in progress')
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _completePickup,
                icon: _isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  _isProcessing ? 'Completing...' : 'Complete Pickup',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
