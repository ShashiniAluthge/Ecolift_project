import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ViewLiveLocationScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destinationLocation;

  const ViewLiveLocationScreen({
    super.key,
    required this.startLocation,
    required this.destinationLocation,
  });

  @override
  State<ViewLiveLocationScreen> createState() => _ViewLiveLocationScreenState();
}

class _ViewLiveLocationScreenState extends State<ViewLiveLocationScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;
  double _currentZoom = 15; // keep track of zoom manually

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    _currentPosition = widget.startLocation;
    _destination = widget.destinationLocation;

    if (_currentPosition != null && _destination != null) {
      _routePoints = await _fetchRoute(_currentPosition!, _destination!);
    }

    setState(() {
      _isLoadingRoute = false;
    });
  }

  Future<List<LatLng>> _fetchRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};"
        "${end.longitude},${end.latitude}?overview=full&geometries=polyline",
      );

      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception('Failed to fetch route');

      final data = jsonDecode(response.body);
      final geometry = data['routes'][0]['geometry'];
      return _decodePolyline(geometry);
    } catch (e) {
      print('Error fetching route: $e');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
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

  void _zoomIn() {
    setState(() {
      _currentZoom += 1;
      if (_currentZoom > 19) _currentZoom = 19;
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, _currentZoom);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom -= 1;
      if (_currentZoom < 3) _currentZoom = 3;
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, _currentZoom);
      }
    });
  }

  void _goToCurrent() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _currentZoom);
    }
  }

  void _goToDestination() {
    if (_destination != null) {
      _mapController.move(_destination!, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Live Location',
            style: TextStyle(color: Colors.white),
          )),
      body: Stack(
        children: [
          _isLoadingRoute
              ? const Center(
                  child: CircularProgressIndicator(
                  color: Colors.green,
                ))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _currentPosition ?? const LatLng(6.9271, 79.8612),
                    // zoom: _currentZoom,
                    maxZoom: 19,
                    minZoom: 3,
                  ),
                  children: [
                    TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.my_location,
                                color: Colors.blue, size: 30),
                          ),
                        ],
                      ),
                    if (_destination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destination!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.place,
                                color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                              points: _routePoints,
                              color: const Color.fromARGB(255, 0, 140, 255),
                              strokeWidth: 5),
                        ],
                      ),
                  ],
                ),

          // Side floating buttons
          Positioned(
            right: 16,
            bottom: 80,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "currentLoc",
                  mini: true,
                  onPressed: _goToCurrent,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "destination",
                  mini: true,
                  onPressed: _goToDestination,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.place, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
