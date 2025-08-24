import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/pickup_service.dart';

class PickupConfirmation extends StatefulWidget {
  final List<String> selectedWasteTypes;
  final LatLng location;
  final String address;

  const PickupConfirmation({
    super.key,
    required this.selectedWasteTypes,
    required this.location,
    required this.address,
  });

  @override
  State<PickupConfirmation> createState() => _PickupConfirmationState();
}

class _PickupConfirmationState extends State<PickupConfirmation> {
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

    bool _isLoading = false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Pickup'),
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
              'Instant Pickup',
              Icons.access_time,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading
                  // ignore: dead_code
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        await PickupService.createInstantPickup(
                          wasteTypes: selectedWasteTypes,
                          latitude: location.latitude,
                          longitude: location.longitude,
                          address: address,
                        );
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/instant_pickup_order_placed',
                            (route) => false,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Pickup request created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
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
                      color: Colors.green,
                    )
                  : const Text(
                      'Confirm Pickup',
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
