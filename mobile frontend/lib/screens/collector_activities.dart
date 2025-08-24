import 'dart:async';
import 'package:eco_lift/screens/view_accepted_pickup_location.dart';
import 'package:eco_lift/screens/view_pickup_requests_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:eco_lift/services/pickup_service.dart';

class CollectorActivities extends StatefulWidget {
  const CollectorActivities({Key? key}) : super(key: key);

  @override
  State<CollectorActivities> createState() => _CollectorActivitiesState();
}

class _CollectorActivitiesState extends State<CollectorActivities>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _acceptedPickups = [];
  List<Map<String, dynamic>> _inProgressPickups = [];
  List<Map<String, dynamic>> _completedPickups = [];

  bool _isLoading = true;
  String? _error;
  final Set<String> _processingRequests = {};
  final Set<String> _processingStart = {};
  final Set<String> _processingCancel = {};

  late TabController _tabController;
  bool _isInProgressLoading = false;

  late Timer _realtimeTimer;

  final Color primaryGreen = const Color(0xFF56AB2F);
  final Color lightGreen = const Color(0xFFA8E063);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllPickups();

    // Realtime updates every 10 seconds
    _realtimeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchAllPickups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchAllPickups() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        PickupService.getAcceptedPickups(),
        PickupService.getInProgressPickups(),
        PickupService.getCompletedPickups(),
      ]);

      if (mounted) {
        setState(() {
          _acceptedPickups = results[0];
          _inProgressPickups = results[1];
          _completedPickups = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAcceptedPickups() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final pickups = await PickupService.getAcceptedPickups();
      setState(() {
        _acceptedPickups = pickups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getPickupsByStatus(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return _acceptedPickups;
      case 'in progress':
        return _inProgressPickups;
      case 'completed':
        return _completedPickups;
      default:
        return [];
    }
  }

  Future<void> _updatePickupStatus(String requestId, String newStatus) async {
    if (_processingRequests.contains(requestId)) return;

    setState(() {
      _processingRequests.add(requestId);
    });

    try {
      await PickupService.updatePickupStatus(requestId, newStatus);
      await _fetchAllPickups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pickup status updated to $newStatus'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(requestId);
      });
    }
  }

  Future<void> _cancelPickup(String requestId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this pickup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (_processingRequests.contains(requestId)) return;

    setState(() {
      _processingRequests.add(requestId);
    });

    try {
      await PickupService.cancelPickup(requestId);
      await _fetchAllPickups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup cancelled successfully'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel pickup: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(requestId);
      });
    }
  }

  Future<void> _startPickup(String requestId) async {
    final pickup = _acceptedPickups.firstWhere((p) => p['_id'] == requestId,
        orElse: () => {});
    if (pickup.isEmpty) return;

    setState(() {
      _acceptedPickups.removeWhere((p) => p['_id'] == requestId);
      _inProgressPickups.insert(0, pickup);
      _processingStart.add(requestId);
      _isInProgressLoading = true;
    });

    try {
      await PickupService.updatePickupStatus(requestId, 'In Progress');
      await _fetchAllPickups();
    } catch (e) {
      setState(() {
        _inProgressPickups.removeWhere((p) => p['_id'] == requestId);
        _acceptedPickups.insert(0, pickup);
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error starting pickup: $e')));
      }
    } finally {
      setState(() {
        _processingStart.remove(requestId);
        _isInProgressLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final acceptedPickups = _getPickupsByStatus('accepted');
    final inProgressPickups = _getPickupsByStatus('in progress');
    final completedPickups = _getPickupsByStatus('completed');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.green,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'To Do (${acceptedPickups.length})'),
                  Tab(text: 'In Progress (${inProgressPickups.length})'),
                  Tab(text: 'Completed (${completedPickups.length})'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.green,
                      ),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetchAllPickups,
                          color: primaryGreen,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPickupList(acceptedPickups, 'accepted'),
                              _buildPickupList(
                                  inProgressPickups, 'in progress'),
                              _buildPickupList(completedPickups, 'completed'),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error loading tasks',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[300],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchAcceptedPickups,
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getEmptyStateIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.assignment_outlined;
      case 'in progress':
        return Icons.local_shipping_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.assignment_outlined;
    }
  }

  Widget _buildPickupList(
      List<Map<String, dynamic>> pickups, String currentStatus) {
    // Show loading spinner for in-progress tab while syncing
    if (currentStatus.toLowerCase() == 'in progress' && _isInProgressLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (pickups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getEmptyStateIcon(currentStatus),
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _getEmptyStateMessage(currentStatus),
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pickups.length,
      itemBuilder: (context, index) {
        return _buildPickupCard(pickups[index], currentStatus);
      },
    );
  }

  String _getEmptyStateMessage(String status) {
    switch (status) {
      case 'accepted':
        return 'No new tasks to do';
      case 'in progress':
        return 'No pickups in progress';
      case 'completed':
        return 'No completed pickups';
      default:
        return 'No pickups found';
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

  Widget _buildPickupCard(Map<String, dynamic> pickup, String currentStatus) {
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
    final status = pickup['status'] ?? 'Accepted';
    final isScheduled =
        (pickup['requestType']?.toLowerCase() ?? '') == 'scheduled';
    final isProcessing = _processingRequests.contains(requestId);

    final acceptedTimeStr = pickup['acceptedAt'];
    String? acceptedTime;
    if (acceptedTimeStr != null) {
      try {
        final accepted = DateTime.parse(acceptedTimeStr);
        acceptedTime = DateFormat('MMM dd, yyyy • hh:mm a').format(accepted);
      } catch (e) {
        acceptedTime = 'Unknown time';
      }
    }

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
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                if (acceptedTime != null)
                  Text(
                    'Accepted: $acceptedTime',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.recycling, 'Waste Type',
                wasteTypes.isEmpty ? 'No waste types specified' : wasteTypes),
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
                if (status.toLowerCase() != 'completed')
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
                            builder: (context) =>
                                ViewAcceptedPickupLocationScreen(
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
                              pickupRequestId: pickup['_id'],
                              currentStatus: status,
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
                    icon:
                        const Icon(Icons.navigation, color: Color(0xFF56AB2F)),
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
            _buildActionButtons(requestId, currentStatus, isProcessing, pickup),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    String requestId,
    String currentStatus,
    bool isProcessing,
    Map<String, dynamic> pickup,
  ) {
    final isStartProcessing = _processingStart.contains(requestId);
    final isCancelProcessing = _processingCancel.contains(requestId);

    switch (currentStatus.toLowerCase()) {
      case 'accepted':
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to the map screen if pickup location exists
                    if (pickup['location']?['coordinates'] != null) {
                      final coords =
                          pickup['location']['coordinates'] as List<dynamic>;
                      final double longitude = coords[0].toDouble();
                      final double latitude = coords[1].toDouble();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewAcceptedPickupLocationScreen(
                            locationData: {
                              'latitude': latitude,
                              'longitude': longitude,
                              'displayName': pickup['friendlyAddress'] ??
                                  'Pickup Location',
                              'fullAddress': pickup['friendlyAddress'],
                            },
                            customerDetails: {
                              'name': pickup['customerDetails']?['name'] ??
                                  'Unknown',
                              'phone':
                                  pickup['customerDetails']?['phone'] ?? '',
                            },
                            pickupRequestId: pickup['_id'],
                            currentStatus: 'Accepted',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pickup location not available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    disabledBackgroundColor: Colors.purple.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: isStartProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.local_shipping, color: Colors.white),
                  label: Text(
                    isStartProcessing ? 'Starting...' : 'Start Pickup',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: isCancelProcessing || requestId.isEmpty
                      ? null
                      : () => _cancelPickup(requestId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: isCancelProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cancel, color: Colors.white),
                  label: Text(
                    isCancelProcessing ? 'Cancelling...' : 'Cancel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'in progress':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: isStartProcessing || requestId.isEmpty
                  ? null
                  : () => _updatePickupStatus(requestId, 'Completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.green.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isStartProcessing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                isStartProcessing ? 'Completing...' : 'Mark as Completed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );

      case 'completed':
        return ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewPickupRequestDetailsScreen(
                  pickupData: pickup,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.1),
            foregroundColor: Colors.green,
            minimumSize: const Size(double.infinity, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.green, width: 2),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'View Details',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
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
