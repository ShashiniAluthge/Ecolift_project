import 'package:eco_lift/screens/view_live_location.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../services/pickup_service.dart'; // Make sure the path is correct

class CustomerActivityScreen extends StatefulWidget {
  final int? highlightedIndex;
  const CustomerActivityScreen({super.key, this.highlightedIndex});

  @override
  State<CustomerActivityScreen> createState() => _CustomerActivityScreenState();
}

class _CustomerActivityScreenState extends State<CustomerActivityScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Future<List<Map<String, dynamic>>> _futureActivities;

  final Color primaryGreen = const Color(0xFF56AB2F);
  final Color lightGreen = const Color(0xFFA8E063);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    _futureActivities = _fetchAllActivities();
  }

  Future<List<Map<String, dynamic>>> _fetchAllActivities() async {
    try {
      final inProgress =
          await PickupService.getCustomerActivitiesByStatus("in progress");
      final pending =
          await PickupService.getCustomerActivitiesByStatus("pending");
      final accepted =
          await PickupService.getCustomerActivitiesByStatus("accepted");
      final completed =
          await PickupService.getCustomerActivitiesByStatus("completed");

      // Combine into a single list
      return [...inProgress, ...pending, ...accepted, ...completed];
    } catch (e) {
      debugPrint("Error fetching activities: $e");
      return [];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [lightGreen, primaryGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'My Activity',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _futureActivities,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                              color: Colors.green,
                            ));
                          } else if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          } else if (snapshot.data == null ||
                              snapshot.data!.isEmpty) {
                            return _buildNoActivitiesCard();
                          } else {
                            final activities = snapshot.data!;

                            // Custom status priority
                            const statusOrder = {
                              'in progress': 0,
                              'accepted': 1,
                              'pending': 2,
                              'completed': 3,
                            };

                            activities.sort((a, b) {
                              final aStatus =
                                  (a['status'] ?? '').toString().toLowerCase();
                              final bStatus =
                                  (b['status'] ?? '').toString().toLowerCase();
                              final aIndex = statusOrder[aStatus] ?? 99;
                              final bIndex = statusOrder[bStatus] ?? 99;
                              return aIndex.compareTo(bIndex);
                            });

                            return ListView.builder(
                              itemCount: activities.length,
                              itemBuilder: (context, index) {
                                return _buildActivityCard(
                                    activities[index], index);
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final isHighlighted = widget.highlightedIndex == index;
    final isScheduled = activity['requestType']?.toLowerCase() == 'scheduled';

    String address = "Location shared via map";

    if (activity['location']?['coordinates'] != null) {
      final coords = activity['location']['coordinates'] as List<dynamic>;
      final double longitude = coords[0].toDouble();
      final double latitude = coords[1].toDouble();

      // get friendly address asynchronously
      _getAddress(latitude, longitude).then((value) {
        setState(() {
          activity['friendlyAddress'] = value;
        });
      });

      address = activity['friendlyAddress'] ?? "Fetching address...";
    }

    final items = activity['items'] as List<dynamic>;
    final wasteTypes = items.map((item) => item['type']).join(', ');

    final scheduledTimeStr = activity['scheduledTime'];
    final status = activity['status'] ?? 'Pending';

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

    final isInProgress = status.toString().toLowerCase() == 'in progress';

    return Stack(
      children: [
        Card(
          color: isHighlighted ? Colors.lightGreen.shade100 : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isHighlighted ? 8 : 4,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildInfoRow(Icons.recycling, 'Waste Type', wasteTypes),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on, 'Location', address),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.schedule, 'Selection Type',
                    isScheduled ? 'Scheduled' : 'Instant'),
                if (isScheduled && formattedDate != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                      Icons.date_range, 'Scheduled Date', formattedDate),
                ],
                if (isScheduled && formattedTime != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                      Icons.access_time, 'Scheduled Time', formattedTime),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toString().toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (isInProgress)
          Positioned(
            bottom: 30,
            right: 12,
            child: InkWell(
              onTap: () async {
                final collectorData =
                    activity['collector'] ?? activity['collectorId'];
                print("==== DEBUG: Full activity object ====");
                print(activity);
                print("==== DEBUG: collector field ====");
                print(collectorData);

                final collectorId =
                    collectorData is Map ? collectorData['_id'] : collectorData;
                print("==== DEBUG: extracted collectorId ====");
                print(collectorId);

                if (collectorId == null || collectorId.toString().isEmpty) {
                  print(
                      " No collector assigned (collectorId is null or empty)");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Collector not assigned yet'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                //  Pass collectorId to PickupService
                LatLng? collectorLocation =
                    await PickupService.getCollectorLocation(collectorId);

                if (collectorLocation == null) {
                  print(" Failed to fetch collector location from backend");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to fetch collector location'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                print(" Collector location fetched: $collectorLocation");

                // Navigate to ViewLiveLocation screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewLiveLocationScreen(
                      startLocation: collectorLocation,
                      destinationLocation: LatLng(
                        activity['location']['coordinates'][1],
                        activity['location']['coordinates'][0],
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFD3D3D3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
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

  Widget _buildNoActivitiesCard() {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[500]),
              const SizedBox(height: 16),
              const Text(
                "No Activities Yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your past and current waste pickup activities will appear here.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
