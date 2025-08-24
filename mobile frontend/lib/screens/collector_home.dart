import 'package:eco_lift/screens/view_pickup_location.dart';
import 'package:eco_lift/screens/view_pickup_requests_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:eco_lift/services/pickup_service.dart';

class CollectorHomeScreen extends StatefulWidget {
  const CollectorHomeScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends State<CollectorHomeScreen> {
  List<Map<String, dynamic>> _pickups = [];
  bool _isLoading = true;
  String? _error;
  Set<String> _processingRequests = {};

  final Color primaryGreen = const Color(0xFF56AB2F);
  final Color lightGreen = const Color(0xFFA8E063);

  @override
  void initState() {
    super.initState();
    _fetchPickups();
  }

  Future<void> _fetchPickups() async {
    try {
      final pickups = await PickupService.getAllCustomersPendingPickups();
      setState(() {
        _pickups = pickups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptPickup(String requestId) async {
    if (_processingRequests.contains(requestId)) {
      return;
    }

    setState(() {
      _processingRequests.add(requestId);
    });

    try {
      await PickupService.acceptPickupRequest(requestId);

      setState(() {
        _pickups.removeWhere((pickup) => pickup['_id'] == requestId);
        _processingRequests.remove(requestId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup request accepted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Navigator.pushNamedAndRemoveUntil(
      //   context,
      //   '/collector_dashboard',
      //   (route) => false,
      //   arguments: {'initialIndex': 1},
      // );
    } catch (e) {
      setState(() {
        _processingRequests.remove(requestId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept pickup: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _declinePickup(String requestId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Pickup'),
          content:
              const Text('Are you sure want to cancel this pickup request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      setState(() {
        _pickups.removeWhere((pickup) => pickup['_id'] == requestId);
      });
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup request canceled'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<String> _getAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.locality}, ${place.administrativeArea}";
      }
    } catch (e) {
      debugPrint("Error in reverse geocoding: $e");
    }
    return "Location shared via map";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
              color: Colors.green,
            ))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPickups,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'All Pending Orders',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        )),
                    Expanded(
                      child: _pickups.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No pending pickups found.',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _pickups.length,
                              itemBuilder: (context, index) {
                                return _buildPickupCard(_pickups[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPickupCard(Map<String, dynamic> pickup) {
    final customer = pickup['customerDetails'] ?? {};
    final customerName = customer['name'] ?? 'Unknown';
    final customerPhone = customer['phone'] ?? '';

    final requestId = pickup['_id'] ?? '';

    String address = "Location shared via map";
    if (pickup['location']?['coordinates'] != null) {
      final coords = pickup['location']['coordinates'] as List<dynamic>;
      final double longitude = coords[0].toDouble();
      final double latitude = coords[1].toDouble();

      // get friendly address asynchronously
      _getAddress(latitude, longitude).then((value) {
        setState(() {
          pickup['friendlyAddress'] = value;
        });
      });

      address = pickup['friendlyAddress'] ?? "Fetching address...";
    }

    final items = pickup['items'] as List<dynamic>? ?? [];
    final wasteTypes =
        items.map((item) => item['type'] ?? 'Unknown').join(', ');
    final status = pickup['status'] ?? 'Pending';
    final isScheduled =
        (pickup['requestType']?.toLowerCase() ?? '') == 'scheduled';
    final isProcessing = _processingRequests.contains(requestId);

    final scheduledTimeStr = pickup['scheduledTime'];
    String? formattedDate;
    String? formattedTime;

    if (scheduledTimeStr != null) {
      try {
        // Parse as UTC and convert to local
        final scheduledTimeUtc = DateTime.parse(scheduledTimeStr).toUtc();
        final scheduledTimeLocal = scheduledTimeUtc.toLocal();

        formattedDate = DateFormat.yMMMMd().format(scheduledTimeLocal);
        formattedTime = DateFormat.jm().format(scheduledTimeLocal);
      } catch (e) {
        formattedDate = 'Invalid date';
        formattedTime = 'Invalid time';
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.recycling,
              'Waste Type',
              wasteTypes.isEmpty ? 'No waste types specified' : wasteTypes,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on,
                    size: 20, color: Color(0xFF56AB2F)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (pickup['location']?['coordinates'] != null) {
                      final coords =
                          pickup['location']['coordinates'] as List<dynamic>;
                      final double longitude = coords[0].toDouble();
                      final double latitude = coords[1].toDouble();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewPickupLocationScreen(
                            locationData: {
                              'latitude': latitude,
                              'longitude': longitude,
                              'displayName': pickup['friendlyAddress'] ??
                                  'Pickup Location',
                              'fullAddress': pickup['friendlyAddress'],
                            },
                            customerDetails: {
                              'name': customerName,
                              'phone': customerPhone,
                            },
                            notificationData: {
                              'pickupRequestId': pickup['_id'],
                            },
                            cameFromDashboard: true,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location not available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation, color: Color(0xFF56AB2F)),
                  tooltip: 'Navigate',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.schedule, 'Request Type',
                isScheduled ? 'Scheduled' : 'Instant'),
            if (isScheduled && formattedDate != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.date_range, 'Scheduled Date', formattedDate),
            ],
            if (isScheduled && formattedTime != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, 'Scheduled Time', formattedTime),
            ],
            const SizedBox(height: 20),
            if (status.toLowerCase() == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Accept button
                  Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: isProcessing || requestId.isEmpty
                            ? null
                            : () => _acceptPickup(requestId),
                        icon: isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_circle_outline,
                                color: Colors.white),
                        label: isProcessing
                            ? const Text(
                                'Processing...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          disabledBackgroundColor:
                              Colors.green.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // View Details button
                  Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(left: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ViewPickupRequestDetailsScreen(
                                pickupData: pickup,
                              ),
                            ),
                          );
                        },
                        icon:
                            const Icon(Icons.info_outline, color: Colors.white),
                        label: const Text(
                          'View Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
