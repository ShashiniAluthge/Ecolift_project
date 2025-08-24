import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ViewPickupRequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> pickupData;

  const ViewPickupRequestDetailsScreen({super.key, required this.pickupData});

  @override
  Widget build(BuildContext context) {
    final customer = pickupData['customerDetails'] ?? {};
    final customerName = customer['name'] ?? 'Unknown';
    final customerPhone = customer['phone'] ?? '';
    final customerEmail = customer['email'] ?? '';

    final items = pickupData['items'] as List<dynamic>? ?? [];
    final wasteTypes =
        items.map((item) => item['type'] ?? 'Unknown').join(', ');

    final status = pickupData['status'] ?? 'Pending';
    final isScheduled =
        (pickupData['requestType']?.toLowerCase() ?? '') == 'scheduled';

    String? formattedDate;
    String? formattedTime;

    // Correct UTC → Local conversion
    if (pickupData['scheduledTime'] != null) {
      try {
        final scheduledTimeUtc =
            DateTime.parse(pickupData['scheduledTime']).toUtc();
        final scheduledTimeLocal = scheduledTimeUtc.toLocal();

        formattedDate = DateFormat.yMMMMd().format(scheduledTimeLocal);
        formattedTime = DateFormat.jm().format(scheduledTimeLocal);
      } catch (e) {
        formattedDate = 'Invalid date';
        formattedTime = 'Invalid time';
      }
    }

    final friendlyAddress =
        pickupData['friendlyAddress'] ?? "Location shared via map";
    final coords = pickupData['location']?['coordinates'] as List<dynamic>?;

    final locationText = (coords != null && coords.length == 2)
        ? '$friendlyAddress '
        : friendlyAddress;

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Pickup Request Details',
            style: TextStyle(color: Colors.white, fontSize: 18),
          )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildInfoRow('Name', customerName),
            _buildInfoRow('Phone', customerPhone),
            _buildInfoRow('Email', customerEmail),
            const Divider(height: 30, thickness: 1.2),
            Text('Pickup Details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildInfoRow('Status', status),
            _buildInfoRow(
                'Request Type', isScheduled ? 'Scheduled' : 'Instant'),
            if (isScheduled)
              _buildInfoRow('Scheduled Date', formattedDate ?? ''),
            if (isScheduled)
              _buildInfoRow('Scheduled Time', formattedTime ?? ''),
            _buildInfoRow(
                'Waste Types', wasteTypes.isEmpty ? 'N/A' : wasteTypes),
            _buildInfoRow('Location', locationText),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Back',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          Expanded(
              child:
                  Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}
