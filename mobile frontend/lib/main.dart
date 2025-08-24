// lib/main.dart
//import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:eco_lift/firebase_options.dart';
import 'package:eco_lift/screens/collector_home.dart';
import 'package:eco_lift/screens/collector_activities.dart';
import 'package:eco_lift/screens/collector_profile.dart';
import 'package:eco_lift/screens/collector_notification.dart';
import 'package:eco_lift/screens/collector_wallet.dart';
import 'package:eco_lift/screens/customer_activities.dart';
import 'package:eco_lift/screens/customer_notification.dart';
import 'package:eco_lift/screens/view_pickup_location.dart';
import 'package:eco_lift/services/customer_notification_service.dart';
import 'package:eco_lift/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_page.dart';
import 'screens/about_app.dart';
import 'screens/role_selection.dart';
import 'screens/customer_personal_info.dart';
import 'screens/customer_address.dart';
import 'screens/customer_password.dart';
import 'screens/map_location.dart';
import 'screens/collector_personal_info.dart';
import 'screens/collector_vehicle.dart';
import 'screens/collector_waste_types.dart';
import 'screens/collector_password.dart';
import 'screens/collector_registration_success.dart';
import 'screens/customer_welcome.dart';
import 'screens/customer_registration_complete.dart';
import 'screens/collector_welcome.dart';
import 'screens/login_role_selection.dart';
import 'screens/login_screen.dart';
import 'screens/customer_dashboard.dart';
import 'screens/customer_profile.dart';
import 'screens/instant_pickup/waste_type_selection.dart';
import 'screens/instant_pickup/location_selection.dart' as instant_location;
import 'screens/instant_pickup/confirmation.dart' as instant_confirmation;
import 'screens/scheduled_pickup/waste_type_selection.dart';
import 'screens/scheduled_pickup/datetime_selection.dart';
import 'screens/scheduled_pickup/location_selection.dart' as scheduled_location;
import 'screens/scheduled_pickup/confirmation.dart' as scheduled_confirmation;
import 'screens/instant_pickup/order_placed.dart';
import 'models/customer.dart';
import 'screens/collector_location.dart';
import 'screens/collector_dashboard.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up background message handler before Firebase initialization
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EcoLiftApp());

  // Initialize notification services after runApp
  // Only initialize the service based on user type
  // You should determine user type from your app state/preferences
  await _initializeNotificationServices();
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");

  // Initialize Firebase if not already done
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Handle background messages based on notification type
  final notificationType = message.data['type'] ?? '';
  final target = message.data['target'] ?? '';

  if (notificationType == 'PICKUP_ACCEPTED' || target == 'customer') {
    // This is a customer notification - handle it for customers
    print('Background: Customer notification received');
    // You might want to store this for when the app opens
  } else if (notificationType == 'PICKUP_REQUEST' ||
      notificationType == 'NEW_PICKUP_REQUEST' ||
      target == 'collector') {
    // This is a collector notification - handle it for collectors
    print('Background: Collector notification received');
    // You might want to store this for when the app opens
  }
}

Future<void> _initializeNotificationServices() async {
  // Get user type from your app's state management or shared preferences
  final userType =
      await _getUserType(); // Implement this method based on your app

  if (userType == 'customer') {
    await CustomerNotificationService.initialize();
    await CustomerNotificationService.loadStoredNotifications();
    await CustomerNotificationService.setupFirebaseMessaging();
    print('Customer notification service initialized');
  } else if (userType == 'collector') {
    await NotificationService.initialize();
    await NotificationService.loadStoredNotifications();
    await NotificationService.setupFirebaseMessaging();
    print('Collector notification service initialized');
  }
}

// Implement this method based on how you determine user type in your app
Future<String> _getUserType() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_type') ?? 'customer'; // Default to customer

  // Alternative: You might check if user is logged in as customer or collector
  // Or check from your authentication service
  // return AuthService.getCurrentUserType();
}

class EcoLiftApp extends StatelessWidget {
  const EcoLiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    // // Initialize notification service after first frame
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   NotificationService().initialize(context);
    // });
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EcoLift',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/about_app': (context) => const AboutApp(),
        '/role_selection': (context) => const RoleSelection(),
        '/login_role_selection': (context) => const LoginRoleSelection(),
        '/login': (context) => const LoginScreen(),
        '/customer_dashboard': (context) {
          final userData = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CustomerDashboard(userData: userData);
        },
        '/customer_welcome': (context) => const CustomerWelcome(),
        '/customer_personal_info': (context) => const CustomerPersonalInfo(),
        '/instant_pickup': (context) => const WasteTypeSelection(),
        '/instant_pickup_location': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return instant_location.LocationSelection(
            selectedWasteTypes:
                args?['selectedWasteTypes'] as List<String>? ?? [],
          );
        },
        '/scheduled_pickup': (context) => const ScheduledWasteTypeSelection(),
        '/scheduled_pickup_datetime': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return DateTimeSelection(
            selectedWasteTypes:
                args?['selectedWasteTypes'] as List<String>? ?? [],
          );
        },
        '/scheduled_pickup_location': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return scheduled_location.LocationSelection(
            selectedWasteTypes:
                args?['selectedWasteTypes'] as List<String>? ?? [],
            scheduledDateTime: args?['scheduledDateTime'] as DateTime?,
          );
        },
        '/instant_pickup_confirmation': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final locationMap = args?['location'] as Map<String, dynamic>?;

          return instant_confirmation.PickupConfirmation(
            selectedWasteTypes:
                List<String>.from(args?['selectedWasteTypes'] ?? []),
            location: LatLng(
              locationMap?['latitude'] ?? 0.0,
              locationMap?['longitude'] ?? 0.0,
            ),
            address: args?['address'] ?? 'Unknown',
          );
        },
        '/scheduled_pickup_confirmation': (context) =>
            const scheduled_confirmation.ScheduledPickupConfirmation(),
        '/customer_address': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CustomerAddress(
            customer: Customer(
              name: args?['name'] ?? '',
              email: args?['email'] ?? '',
              phone: args?['phone'] ?? '',
            ),
          );
        },
        '/customer_password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CustomerPassword(customerInfo: args ?? {});
        },
        '/customer_registration_complete': (context) {
          final customer =
              ModalRoute.of(context)?.settings.arguments as Customer;
          return CustomerRegistrationComplete(customer: customer);
        },
        '/map_location': (context) => const MapLocation(),
        '/collector_welcome': (context) => const CollectorWelcome(),
        '/collector_personal_info': (context) => const CollectorPersonalInfo(),
        '/collector_vehicle': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CollectorVehicle(personalInfo: args ?? {});
        },
        '/collector_waste_types': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CollectorWasteTypes(collectorInfo: args ?? {});
        },
        '/collector_password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CollectorPassword(collectorInfo: args ?? {});
        },
        '/collector_registration_success': (context) =>
            const CollectorRegistrationSuccess(),
        '/customer_profile': (context) {
          final userData = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CustomerProfile(userData: userData);
        },
        '/instant_pickup_order_placed': (context) => const PickupOrderPlaced(),
        '/collector_location': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CollectorLocation(collectorInfo: args ?? {});
        },
        '/collector_dashboard': (context) {
          final userData = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return CollectorDashboard(userData: userData);
        },
        '/customer_activities': (context) => const CustomerActivityScreen(),
        '/customer_notification': (context) =>
            const CustomerNotificationScreen(),
        '/collector_profile': (context) {
          final userData = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CollectorProfile(userData: userData);
        },
        '/collector_activities': (context) => const CollectorActivities(),
        '/collector_wallet': (context) => const CollectorWalletScreen(),
        '/collector_notification': (context) => const CollectorNotification(),
        '/collector_home': (context) => const CollectorHomeScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade100, Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/ecolift_logo.png',
                height: 200,
              ),
              const SizedBox(height: 20),
              Text(
                'EcoLift',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Making Sri Lanka Cleaner and Greener',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
