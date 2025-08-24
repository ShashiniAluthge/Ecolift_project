import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../services/pickup_service.dart';

class ScheduledPickupConfirmation extends StatefulWidget {
  const ScheduledPickupConfirmation({super.key});

  @override
  State<ScheduledPickupConfirmation> createState() =>
      _ScheduledPickupConfirmationState();
}

class _ScheduledPickupConfirmationState
    extends State<ScheduledPickupConfirmation> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Error: No data received. Please go back and try again.',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    final List<String> selectedWasteTypes = args['selectedWasteTypes'];
    final Map<String, dynamic> locationMap = args['location'];
    final double latitude = locationMap['latitude'];
    final double longitude = locationMap['longitude'];
    final LatLng location = LatLng(latitude, longitude);
    final String address = args['address'];

    // Safely parse scheduledDateTime
    final scheduledDateTimeRaw = args['scheduledDateTime'];
    print(
        "🕒 scheduledDateTime raw: $scheduledDateTimeRaw (${scheduledDateTimeRaw.runtimeType})");

    final DateTime scheduledDateTime = scheduledDateTimeRaw is DateTime
        ? scheduledDateTimeRaw
        : DateTime.tryParse(scheduledDateTimeRaw.toString()) ?? DateTime.now();

    String formattedDate = "Invalid date";
    try {
      formattedDate =
          DateFormat('yyyy-MM-dd – hh:mm a').format(scheduledDateTime);
    } catch (e) {
      print("❌ Date formatting failed: $e");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Scheduled Pickup'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pickup Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailCard(
              'Waste Types',
              selectedWasteTypes.join(', '),
              Icons.category,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              'Location',
              address,
              Icons.location_on,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              'Pickup Type',
              'Scheduled Pickup',
              Icons.schedule,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              'Scheduled Date & Time',
              formattedDate,
              Icons.calendar_today,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      print("🚀 Button pressed");
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        print(
                            "📡 Calling PickupService.createScheduledPickup...");
                        PickupService.createScheduledPickup(
                          wasteTypes: selectedWasteTypes,
                          latitude: location.latitude,
                          longitude: location.longitude,
                          address: address,
                          scheduledDateTime: scheduledDateTime,
                        );
                        print("✅ Pickup created successfully");

                        if (!mounted) return;

                        // show snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Scheduled pickup request created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        print("📢 Snackbar shown");

                        // reset loading BEFORE navigation
                        setState(() {
                          _isLoading = false;
                        });

                        // short delay to allow snackbar
                        Future.delayed(const Duration(milliseconds: 500));

                        print("➡️ Navigating to /customer_dashboard");
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/customer_dashboard',
                          (route) => false,
                        );
                      } catch (e, st) {
                        print("❌ Error: $e\n$st");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          print("🔄 Resetting loading in finally");
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text(
                      'Confirm Scheduled Pickup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
