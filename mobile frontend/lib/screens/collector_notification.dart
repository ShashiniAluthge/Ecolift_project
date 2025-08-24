import 'package:eco_lift/screens/notification_details.dart';
import 'package:eco_lift/services/pickup_service.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

class CollectorNotification extends StatefulWidget {
  const CollectorNotification({super.key});

  @override
  State<CollectorNotification> createState() => _CollectorNotificationState();
}

class _CollectorNotificationState extends State<CollectorNotification> {
  final ScrollController _scrollController = ScrollController();

  void _clearAllNotifications() {
    if (NotificationService.notifications.isEmpty) {
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
                NotificationService.clearNotifications();

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
    if (NotificationService.notifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No notifications available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // If all notifications are already read
    bool allRead =
        NotificationService.notifications.every((n) => n['read'] == true);
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
                NotificationService.markAllAsRead();

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green,
        title: const Text("All Notifications",
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            tooltip: 'Clear all notifications',
            onPressed: _clearAllNotifications,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: NotificationService.notificationsNotifier,
        builder: (context, notifications, child) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No notifications yet",
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ValueListenableBuilder<int?>(
            valueListenable: NotificationService.selectedNotificationIndex,
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isSelected = index == selectedIndex;
                  final isRead = notification['read'] == true;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.shade100
                          : (isRead ? Colors.white : Colors.blue.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.green, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: ListTile(
                        leading: Icon(
                          Icons.notifications_active,
                          color: isRead ? Colors.grey.shade600 : Colors.blue,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        title: Text(
                          notification['title'] ?? 'No title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected
                                ? Colors.green.shade900
                                : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              notification['body'] ?? 'No body',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatRelativeTime(notification['date'] ?? ''),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        onTap: () async {
                          try {
                            NotificationService.markAsRead(index);
                            NotificationService.selectNotification(index);

                            final notification =
                                NotificationService.notifications[index];
                            final customerId =
                                notification['data']['customerId'];
                            if (customerId == null)
                              throw Exception('No customerId in notification');

                            final requestId =
                                notification['data']['pickupRequestId'];
                            print('pickup id:$requestId');

                            // Fetch customer details
                            final response =
                                await PickupService.getRequestedPickupDetails(
                                    customerId);

                            final customerDetails = response['customer'];
                            print(
                                'Customer details fetched successfully: $customerDetails');

                            // Use notification data for wasteTypes & location
                            final notificationData = {
                              'date': notification['date'] ?? '',
                              'pickupRequestId': notification['data']
                                  ['pickupRequestId'],
                              'wasteTypes':
                                  notification['data']['wasteTypes'] ?? [],
                              'location': notification['data']['location'] ??
                                  customerDetails['location'] ??
                                  '',
                            };
                            print(
                                'notification data fetched successfully: $notificationData');

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationDetailsScreen(
                                  customerDetails: customerDetails,
                                  notificationData: notificationData,
                                ),
                              ),
                            );
                          } catch (e) {
                            print('Error fetching customer details: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Failed to load customer details')),
                            );
                          }
                        }),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
