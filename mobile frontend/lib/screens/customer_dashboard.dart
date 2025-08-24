import 'package:eco_lift/services/customer_notification_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'customer_profile.dart';

class CustomerDashboard extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const CustomerDashboard({super.key, this.userData});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late String _greeting;
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Color primaryGreen = const Color(0xFF56AB2F);
  final Color lightGreen = const Color(0xFFA8E063);
  final Color accentGreen = const Color(0xFF4CAF50);
  final Color darkGreen = const Color(0xFF2E7D32);

  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _loadNotifications();

    CustomerNotificationService.initialize();
    CustomerNotificationService.loadStoredNotifications();
    CustomerNotificationService.setupFirebaseMessaging().then((_) {
      _loadNotifications();
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _updateGreeting();
      });
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _updateGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning!';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon!';
    } else {
      _greeting = 'Good Evening!';
    }
  }

  void _loadNotifications() {
    final notifications = CustomerNotificationService.notifications;
    // Count only unread notifications
    final unreadCount = notifications.where((n) => n['read'] != true).length;
    setState(() {
      _notificationCount = unreadCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    String userName =
        widget.userData?['fullName'] ?? widget.userData?['name'] ?? 'User';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightGreen, primaryGreen],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi $userName,',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _greeting,
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withAlpha(230)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border:
                                  Border.all(color: Colors.white.withAlpha(77)),
                            ),
                            child: Row(
                              children: [
                                Image.asset('assets/images/splash.png',
                                    width: 25, height: 25),
                                const SizedBox(width: 8),
                                const Text(
                                  'ECO',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Pickup options
                      const Text(
                        'Choose Pickup Type',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select how you want to manage your waste',
                        style: TextStyle(
                            fontSize: 16, color: Colors.white.withAlpha(230)),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPickupCard(
                              'Instant Pickup',
                              Icons.flash_on,
                              'Get your waste collected immediately',
                              accentGreen,
                              () => Navigator.pushNamed(
                                  context, '/instant_pickup'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildPickupCard(
                              'Scheduled Pickup',
                              Icons.calendar_today,
                              'Schedule a pickup for later',
                              darkGreen,
                              () => Navigator.pushNamed(
                                  context, '/scheduled_pickup'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Info banner
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(77)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: Image.asset('assets/images/splash.png',
                                      width: 25, height: 25),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Eco-Friendly Waste Management',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Join us in making Sri Lanka cleaner and greener! Our certified waste collectors ensure proper disposal and recycling of your waste.',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withAlpha(230),
                                  height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryGreen,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Learn More'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);

          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/customer_activities')
                  .then((_) => setState(() => _selectedIndex = 0));
              break;
            case 2:
              Navigator.pushNamed(context, '/customer_notification').then((_) {
                _loadNotifications(); // Update badge after reading notifications
                setState(() => _selectedIndex = 0);
              });
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        CustomerProfile(userData: widget.userData)),
              ).then((_) => setState(() => _selectedIndex = 0));
              break;
            default:
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'Activities'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10)),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_notificationCount',
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
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildPickupCard(String title, IconData icon, String description,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 250,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withAlpha(25)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withAlpha(25), shape: BoxShape.circle),
                    child: Icon(Icons.arrow_forward, color: color, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
