import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'collector_home.dart';
import 'collector_activities.dart';
import 'collector_notification.dart';
import 'collector_profile.dart';

class CollectorDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CollectorDashboard({super.key, required this.userData});

  static _CollectorDashboardState? of(BuildContext context) =>
      context.findAncestorStateOfType<_CollectorDashboardState>();

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  final List<String> _titles = [
    'Home',
    'Activities',
    'Notification',
    'Profile'
  ];

  List<Widget> get _pages => [
        const CollectorHomeScreen(),
        const CollectorActivities(),
        const CollectorNotification(),
        CollectorProfile(userData: widget.userData),
      ];

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    NotificationService.loadStoredNotifications();
    NotificationService.setupFirebaseMessaging().then((_) => setState(() {}));
  }

  void selectTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _selectedIndex = index);
    });
  }

  void _onItemTapped(int index) => selectTab(index);

  /// Badge for top right AppBar
  Widget _buildNotificationBadge() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: NotificationService.notificationsNotifier,
      builder: (context, _, child) {
        final unreadCount = NotificationService.getUnreadCount();
        if (unreadCount == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(right: 16),
          child: Stack(
            children: [
              IconButton(
                onPressed: () => selectTab(2),
                icon: const Icon(Icons.notifications, color: Colors.white),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Badge for bottom navigation bar
  Widget _buildBottomNavNotificationIcon() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: NotificationService.notificationsNotifier,
      builder: (context, _, child) {
        final unreadCount = NotificationService.getUnreadCount();
        return Stack(
          children: [
            const Icon(Icons.notifications),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 12, minHeight: 12),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 25),
        ),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIndex != 2) _buildNotificationBadge(),
        ],
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.pending_actions), label: 'Activities'),
          BottomNavigationBarItem(
            icon: _buildBottomNavNotificationIcon(),
            label: 'Notification',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
