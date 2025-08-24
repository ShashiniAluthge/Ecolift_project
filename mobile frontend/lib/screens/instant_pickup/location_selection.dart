import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationSelection extends StatefulWidget {
  final List<String> selectedWasteTypes;
  final DateTime? scheduledDateTime;

  const LocationSelection({
    super.key,
    required this.selectedWasteTypes,
    this.scheduledDateTime,
  });

  @override
  State<LocationSelection> createState() => _LocationSelectionState();
}

class _LocationSelectionState extends State<LocationSelection> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  String _locationDisplayName = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
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

    LatLng current = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentPosition = current;
      _selectedLocation = current;
    });

    _mapController.move(current, 14);
    _updateAddress(current);
  }

  String _buildFriendlyLocationName(Placemark place) {
    if (place.subThoroughfare != null &&
        place.subThoroughfare!.isNotEmpty &&
        place.thoroughfare != null &&
        place.thoroughfare!.isNotEmpty) {
      return "${place.subThoroughfare} ${place.thoroughfare}";
    }

    if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      return place.thoroughfare!;
    }

    if (place.name != null &&
        place.name!.isNotEmpty &&
        !_isPlusCode(place.name!) &&
        place.name!.length > 3) {
      return place.name!;
    }

    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      return place.subLocality!;
    }

    if (place.locality != null && place.locality!.isNotEmpty) {
      return place.locality!;
    }

    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      return place.administrativeArea!;
    }

    return place.country ?? "Unknown Location";
  }

  bool _isPlusCode(String text) {
    return RegExp(r'^[A-Z0-9]{2,}[+][A-Z0-9]{2,}$')
        .hasMatch(text.toUpperCase());
  }

  String _buildFullAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.subThoroughfare != null &&
        place.subThoroughfare!.isNotEmpty &&
        place.thoroughfare != null &&
        place.thoroughfare!.isNotEmpty) {
      addressParts.add("${place.subThoroughfare} ${place.thoroughfare}");
    } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      addressParts.add(place.thoroughfare!);
    }

    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }

    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }

    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }

    return addressParts.isNotEmpty
        ? addressParts.join(", ")
        : "Unknown Location";
  }

  Future<void> _updateAddress(LatLng location) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        setState(() {
          _locationDisplayName = _buildFriendlyLocationName(place);
          _selectedAddress = _buildFullAddress(place);
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = "Unknown Location";
        _locationDisplayName = "Unknown Location";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pickup Location'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _currentPosition ?? const LatLng(6.0535, 80.2210),
                initialZoom: 15,
                maxZoom: 18,
                minZoom: 3,
                onTap: (tapPosition, latlng) {
                  setState(() {
                    _selectedLocation = latlng;
                  });
                  _updateAddress(latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                ),
                if (_currentPosition != null)
                  const CurrentLocationLayer(
                    style: LocationMarkerStyle(
                      marker: DefaultLocationMarker(
                        child: Icon(
                          Icons.location_pin,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      markerSize: Size(40, 40),
                      markerDirection: MarkerDirection.heading,
                    ),
                  ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.place,
                          color: Colors.red,
                          size: 35,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search location...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (query) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce =
                      Timer(const Duration(milliseconds: 500), () async {
                    if (query.isEmpty) return;
                    try {
                      List<Location> locations =
                          await locationFromAddress(query);
                      if (locations.isNotEmpty) {
                        final target = LatLng(
                          locations.first.latitude,
                          locations.first.longitude,
                        );

                        _mapController.move(target, 15);
                        setState(() {
                          _selectedLocation = target;
                        });

                        _updateAddress(target);
                      }
                    } catch (e) {
                      // ignore errors for invalid queries
                    }
                  });
                },
              ),
            ),
          ),
          if (_selectedLocation != null && _locationDisplayName.isNotEmpty)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationDisplayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedAddress,
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
              ),
            ),
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: () {
                    final center = _mapController.camera.center;
                    final zoom = _mapController.camera.zoom + 1;
                    _mapController.move(center, zoom);
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: () {
                    final center = _mapController.camera.center;
                    final zoom = _mapController.camera.zoom - 1;
                    _mapController.move(center, zoom);
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "myLocation",
                  mini: true,
                  onPressed: () {
                    if (_currentPosition != null) {
                      _mapController.move(_currentPosition!, 15);
                      setState(() {
                        _selectedLocation = _currentPosition;
                      });
                      _updateAddress(_currentPosition!);
                    }
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _selectedLocation == null
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        '/instant_pickup_confirmation',
                        arguments: {
                          'selectedWasteTypes': widget.selectedWasteTypes,
                          'location': {
                            'latitude': _selectedLocation!.latitude,
                            'longitude': _selectedLocation!.longitude,
                          },
                          'address': _selectedAddress,
                          'displayName': _locationDisplayName,
                        },
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
