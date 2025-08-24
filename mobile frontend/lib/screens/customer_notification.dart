import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/customer_notification_service.dart';
import 'package:intl/intl.dart';

class CustomerNotificationScreen extends StatefulWidget {
  const CustomerNotificationScreen({super.key});

  @override
  State<CustomerNotificationScreen> createState() =>
      _CustomerNotificationScreenState();
}

class _CustomerNotificationScreenState extends State<CustomerNotificationScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // Animation controller and animations (same as CustomerActivityScreen)
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Colors (same as CustomerActivityScreen)
  final Color primaryGreen = const Color(0xFF56AB2F);
  final Color lightGreen = const Color(0xFFA8E063);

  @override
  void initState() {
    super.initState();

    // Initialize animations (same as CustomerActivityScreen)
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearAllNotifications() {
    if (CustomerNotificationService.notifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No notifications available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete all notifications'),
          content:
              const Text('Are you sure you want to delete all notifications?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                CustomerNotificationService.clearNotifications();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('All notifications are deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
                setState(() {}); // Refresh UI
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _markAllAsRead() {
    // If there are no notifications at all
    if (CustomerNotificationService.notifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No notifications available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // If all notifications are already read
    bool allRead = CustomerNotificationService.notifications
        .every((n) => n['read'] == true);
    if (allRead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('All notifications are already read'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mark all as read'),
          content: const Text(
              'Are you sure you want to mark all notifications as read?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                CustomerNotificationService.markAllAsRead();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 2),
                  ),
                );
                setState(() {}); // Refresh UI
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  String _formatRelativeTime(String isoString) {
    try {
      DateTime dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      }
      if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      }

      return DateFormat('MMM dd, yyyy – HH:mm').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Same gradient background as CustomerActivityScreen
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
                  // Custom header (same style as CustomerActivityScreen)
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
                        const Expanded(
                          child: Text(
                            'My Notifications',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Action buttons with white icons
                        IconButton(
                          icon: const Icon(Icons.done_all, color: Colors.white),
                          tooltip: 'Mark all as read',
                          onPressed: _markAllAsRead,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever,
                              color: Colors.white),
                          tooltip: 'Clear all notifications',
                          onPressed: _clearAllNotifications,
                        ),
                      ],
                    ),
                  ),
                  // Content area with white rounded background
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable:
                            CustomerNotificationService.notificationsNotifier,
                        builder: (context, notifications, child) {
                          if (notifications.isEmpty) {
                            return _buildNoNotificationsCard();
                          }

                          return ValueListenableBuilder<int?>(
                            valueListenable: CustomerNotificationService
                                .selectedNotificationIndex,
                            builder: (context, selectedIndex, child) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (selectedIndex != null &&
                                    selectedIndex < notifications.length) {
                                  _scrollController.animateTo(
                                    selectedIndex * 90.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              });

                              return ListView.separated(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: notifications.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final notification = notifications[index];
                                  final isSelected = index == selectedIndex;
                                  final isRead = notification['read'] == true;

                                  return Card(
                                    elevation: isSelected ? 8 : 4,
                                    color: isSelected
                                        ? Colors.lightGreen.shade100
                                        : (isRead
                                            ? Colors.white
                                            : Colors.green.shade50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.check_circle,
                                        color: isRead
                                            ? Colors.grey.shade600
                                            : primaryGreen,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                      title: Text(
                                        notification['title'] ??
                                            'Pickup Update',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isSelected
                                              ? primaryGreen
                                              : Colors.black,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 6),
                                          Text(
                                            notification['body'] ??
                                                'Your pickup has been updated',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade800),
                                          ),
                                          const SizedBox(height: 4),
                                          if (notification['data']
                                                  ['collectorName'] !=
                                              null)
                                            Text(
                                              'Collector: ${notification['data']['collectorName']}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: primaryGreen,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatRelativeTime(
                                                notification['date'] ?? ''),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        CustomerNotificationService.markAsRead(
                                            index);
                                        CustomerNotificationService
                                            .selectNotification(index);

                                        // Show pickup details dialog
                                        _showPickupDetailsDialog(
                                            context, notification);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
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

  // Empty state card (same style as CustomerActivityScreen)
  Widget _buildNoNotificationsCard() {
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
              Icon(
                Icons.notifications_off,
                size: 60,
                color: Colors.grey[500],
              ),
              const SizedBox(height: 16),
              const Text(
                "No Notifications Yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your pickup notifications will appear here when collectors accept your requests.",
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

  void _showPickupDetailsDialog(
      BuildContext context, Map<String, dynamic> notification) {
    final data = notification['data'];

    // Helper to format UTC datetime string to local
    String _formatDateTime(String dateTimeStr) {
      try {
        final dateTimeUtc = DateTime.parse(dateTimeStr).toUtc();
        final dateTimeLocal = dateTimeUtc.toLocal();
        return DateFormat('yMMMd').add_jm().format(dateTimeLocal);
      } catch (e) {
        return 'Invalid date';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lightGreen, primaryGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pickup Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ACCEPTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Pickup ID Row
                        _buildInfoRow(
                          icon: Icons.qr_code,
                          title: 'Pickup ID',
                          value: data['pickupId'] ?? 'N/A',
                        ),

                        const SizedBox(height: 16),

                        // Collector Name Row
                        if (data['collectorName'] != null)
                          _buildInfoRow(
                            icon: Icons.person,
                            title: 'Collector',
                            value: data['collectorName'],
                          ),

                        if (data['collectorName'] != null)
                          const SizedBox(height: 16),

                        // Acceptance Time Row
                        if (data['acceptedAt'] != null)
                          _buildInfoRow(
                            icon: Icons.schedule,
                            title: 'Accepted At',
                            value: _formatDateTime(data['acceptedAt']),
                          ),

                        if (data['acceptedAt'] != null)
                          const SizedBox(height: 16),

                        // Scheduled Pickup Time (if any)
                        if (data['scheduledTime'] != null)
                          _buildInfoRow(
                            icon: Icons.access_time,
                            title: 'Scheduled Time',
                            value: _formatDateTime(data['scheduledTime']),
                          ),

                        if (data['scheduledTime'] != null)
                          const SizedBox(height: 16),

                        // Items Row
                        if (data['items'] != null)
                          _buildItemsRow(data['items']),

                        const SizedBox(height: 20),

                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Close'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
      ),
    );
  }

  // Helper method to build items row
  Widget _buildItemsRow(String itemsJson) {
    try {
      final List<dynamic> items = jsonDecode(itemsJson);
      final wasteTypes =
          items.map((item) => item['type'] ?? 'Unknown').join(', ');

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.recycling, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waste Items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wasteTypes,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} item${items.length > 1 ? 's' : ''} selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return _buildInfoRow(
        icon: Icons.recycling,
        title: 'Waste Items',
        value: 'Unable to load items',
      );
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('MMM dd, yyyy – HH:mm').format(dateTime);
    } catch (e) {
      return isoString;
    }
  }
}
