import 'dart:convert';
import 'package:eco_lift/screens/collector_dashboard.dart';
import 'package:eco_lift/services/errors.dart';
import 'package:eco_lift/services/pickup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class ViewPickupLocationScreen extends StatefulWidget {
  final Map<String, dynamic> locationData;
  final Map<String, dynamic>? customerDetails;
  final Map<String, dynamic>? notificationData;
  final String? currentStatus;

  final bool cameFromDashboard;

  const ViewPickupLocationScreen({
    super.key,
    required this.locationData,
    this.customerDetails,
    this.notificationData,
    this.cameFromDashboard = false,
    this.currentStatus,
  });

  @override
  State<ViewPickupLocationScreen> createState() =>
      _ViewPickupLocationScreenState();
}

class _ViewPickupLocationScreenState extends State<ViewPickupLocationScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _pickupLocation;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;

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
      _routePoints = []; // Clear previous route
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
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                ),

                // Current location marker
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

                // Pickup location marker
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
                              child: const Text(
                                'Pickup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.place,
                                color: Colors.red, size: 35),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Polyline for the route
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 6,
                        color: Colors.red,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Location info card
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
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            widget.customerDetails?['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Calling ${widget.customerDetails?['phone']}'),
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
                                  color: Colors.black87,
                                ),
                              ),
                              if (widget.locationData['fullAddress'] != null)
                                Text(
                                  widget.locationData['fullAddress'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
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

          // Loading indicator for route
          if (_isLoadingRoute)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            ),

          // Map controls
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
                    if (_pickupLocation != null) {
                      _mapController.move(_pickupLocation!, 16);
                    }
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

          // Refresh route button
          Positioned(
            bottom: 350,
            right: 16,
            child: FloatingActionButton(
              heroTag: "refreshRoute",
              mini: true,
              onPressed: _fetchRoute,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),

          // Action buttons
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Accept Pickup',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      content: const Text(
                          'Do you want to accept this pickup request?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final requestId =
                                widget.notificationData?['pickupRequestId'];
                            if (requestId == null) return;

                            final rootContext = context;

                            try {
                              await PickupService.acceptPickupRequest(
                                  requestId);

                              if (mounted) {
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pickup request accepted!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                Navigator.of(rootContext)
                                    .pop(); // close confirm dialog

                                // Conditionally pop based on source
                                if (widget.cameFromDashboard) {
                                  Navigator.of(rootContext)
                                      .pop(); // 1 additional pop
                                } else {
                                  Navigator.of(rootContext).pop(); // 1 pop
                                  Navigator.of(rootContext).pop(); // 2nd pop
                                }
                              }
                            } on PickupAlreadyAcceptedException {
                              if (mounted) {
                                Navigator.of(rootContext).pop(); // close dialog
                                if (widget.cameFromDashboard) {
                                  Navigator.of(rootContext).pop();
                                } else {
                                  Navigator.of(rootContext).pop();
                                  Navigator.of(rootContext).pop();
                                }
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Pickup request already accepted!'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(rootContext).pop();
                                showDialog(
                                  context: rootContext,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Failed'),
                                    content:
                                        Text('Failed to accept pickup: $e'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Accept'),
                        )
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Accept Pickup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
