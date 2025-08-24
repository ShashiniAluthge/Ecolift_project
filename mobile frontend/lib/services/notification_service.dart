import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final ValueNotifier<List<Map<String, dynamic>>> notificationsNotifier =
      ValueNotifier([]);

  static final ValueNotifier<int?> selectedNotificationIndex =
      ValueNotifier(null);

  static const _storageKey = 'collector_notifications';
  static bool _isInitialized = false;

  // ----------------------------
  // Initialization
  // ----------------------------
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(settings,
        onDidReceiveNotificationResponse: (payload) {
      if (notifications.isNotEmpty) {
        selectNotification(0);
      }
    });

    _isInitialized = true;
  }

  static List<Map<String, dynamic>> get notifications =>
      notificationsNotifier.value;

  static int getUnreadCount() {
    return notifications.where((n) => n['read'] != true).length;
  }

  // ----------------------------
  // Load / Save
  // ----------------------------
  static Future<void> loadStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey) ?? [];
    notificationsNotifier.value =
        stored.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  static Future<void> _saveNotificationsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = notifications.map((n) => jsonEncode(n)).toList();
    await prefs.setStringList(_storageKey, stored);
  }

  // ----------------------------
  // Add Notification
  // ----------------------------
  static Future<void> addNotification(Map<String, dynamic> notification) async {
    final current = List<Map<String, dynamic>>.from(notifications);
    notification['read'] ??= false; // default unread
    current.insert(0, notification);
    notificationsNotifier.value = current;
    await _saveNotificationsToStorage();
    _showLocalNotification(notification);
  }

  static void _showLocalNotification(Map<String, dynamic> notification) {
    _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification['title'],
      notification['body'],
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'collector_channel_id',
          'Collector Notifications',
          channelDescription: 'Notifications for collector pickup requests',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ----------------------------
  // Read / Unread
  // ----------------------------
  static void markAsRead(int index) {
    if (index >= 0 && index < notifications.length) {
      final updated = List<Map<String, dynamic>>.from(notifications);
      updated[index]['read'] = true;
      notificationsNotifier.value = updated;
      _saveNotificationsToStorage();
    }
  }

  static void markAllAsRead() {
    final updated = notifications.map((n) => {...n, 'read': true}).toList();
    notificationsNotifier.value = updated;
    _saveNotificationsToStorage();
  }

  // ----------------------------
  // Clear
  // ----------------------------
  static Future<void> clearNotifications() async {
    notificationsNotifier.value = [];
    selectedNotificationIndex.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ----------------------------
  // Selection
  // ----------------------------
  static void selectNotification(int index) {
    selectedNotificationIndex.value = index;
  }

  static void clearSelectedNotification() {
    selectedNotificationIndex.value = null;
  }

  // ----------------------------
  // Firebase Messaging for Collector - ONLY handles collector notifications
  // ----------------------------
  static Future<void> setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Filter messages to only handle collector notifications
    FirebaseMessaging.onMessage.listen((message) {
      if (_isCollectorNotification(message)) {
        _handleIncomingMessage(message);
      } else {
        print(
            'Collector service ignoring non-collector notification: ${message.data['type']}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_isCollectorNotification(message)) {
        _handleIncomingMessage(message);
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && _isCollectorNotification(message)) {
        _handleIncomingMessage(message);
      }
    });
  }

  // Check if the notification is specifically for collectors
  static bool _isCollectorNotification(RemoteMessage message) {
    final notificationType = message.data['type'] ?? '';
    final target = message.data['target'] ?? '';

    // Only handle notifications specifically meant for collectors
    // Explicitly exclude customer notifications
    if (notificationType == 'PICKUP_ACCEPTED' || target == 'customer') {
      return false;
    }

    // Handle collector-specific notifications
    return notificationType == 'PICKUP_REQUEST' ||
        notificationType == 'NEW_PICKUP_REQUEST' ||
        target == 'collector' ||
        // If no specific target is set and it's not a customer notification,
        // assume it's for collectors (for backward compatibility)
        (target.isEmpty && notificationType != 'PICKUP_ACCEPTED');
  }

  static Future<void> _handleIncomingMessage(RemoteMessage message) async {
    print('Collector FCM data payload: ${message.data}');

    // Double check this is a collector notification
    if (!_isCollectorNotification(message)) {
      print(
          'Collector service: Ignoring notification type: ${message.data['type']}');
      return;
    }

    // Decode items JSON string from FCM data
    List<String> wasteTypes = [];
    final itemsDataStr = message.data['items'] ?? '[]';
    try {
      final List<dynamic> itemsData = jsonDecode(itemsDataStr);
      wasteTypes = itemsData
          .map<String>((item) => item['type']?.toString() ?? '')
          .where((type) => type.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error decoding items: $e');
    }

    // Get readable location
    final locationStr = message.data['location'] ?? '';
    String readableLocation = 'Location not available';

    if (locationStr.isNotEmpty) {
      try {
        readableLocation =
            await LocationHelper.getReadableLocation(locationStr);
      } catch (e) {
        print('Error getting readable location: $e');
        // Fallback: show coordinates if available
        final locationMap = LocationHelper.parseLocationString(locationStr);
        final coordinates = LocationHelper.getCoordinates(locationMap ?? {});
        if (coordinates != null) {
          readableLocation =
              'Lat: ${coordinates[1].toStringAsFixed(6)}, Lng: ${coordinates[0].toStringAsFixed(6)}';
        }
      }
    }

    final newNotification = {
      'id': '${DateTime.now().millisecondsSinceEpoch}_collector', // Unique ID
      'title': message.notification?.title ?? 'New Pickup Request',
      'body': message.notification?.body ?? 'A new pickup request is available',
      'date': DateTime.now().toIso8601String(),
      'data': {
        'customerId': message.data['customerId'],
        'pickupRequestId': message.data['pickupId'],
        'location': locationStr, // Keep original location data
        'readableLocation': readableLocation, // Add readable location
        'wasteTypes': wasteTypes,
        'type': message.data['type'] ?? 'PICKUP_REQUEST',
        'target': 'collector',
      },
      'read': false,
    };

    // Check for duplicates before adding
    final isDuplicate = notifications.any((existing) {
      if (existing['id'] == newNotification['id']) return true;

      final existingData = existing['data'] as Map<String, dynamic>?;
      final newData = newNotification['data'] as Map<String, dynamic>?;

      if (existingData != null && newData != null) {
        return existingData['pickupRequestId'] == newData['pickupRequestId'] &&
            existingData['customerId'] == newData['customerId'];
      }

      return false;
    });

    if (!isDuplicate) {
      await addNotification(newNotification);

      final index =
          notifications.indexWhere((n) => n['id'] == newNotification['id']);

      if (index != -1) {
        selectNotification(index);
      }
    } else {
      print('Duplicate collector notification ignored');
    }
  }
}

class LocationHelper {
  // Parse the location string from notification data
  static Map<String, dynamic>? parseLocationString(String locationStr) {
    try {
      return jsonDecode(locationStr) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing location: $e');
      return null;
    }
  }

  // Extract coordinates from the parsed location
  static List<double>? getCoordinates(Map<String, dynamic> location) {
    try {
      if (location['type'] == 'Point' && location['coordinates'] != null) {
        final coords = location['coordinates'] as List;
        if (coords.length >= 2) {
          return [
            coords[0].toDouble(),
            coords[1].toDouble()
          ]; // [longitude, latitude]
        }
      }
    } catch (e) {
      print('Error extracting coordinates: $e');
    }
    return null;
  }

  // Convert coordinates to readable address using reverse geocoding
  static Future<String> getAddressFromCoordinates(
      double longitude, double latitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build address string from placemark components
        List<String> addressParts = [];

        if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
        if (place.subLocality?.isNotEmpty == true)
          addressParts.add(place.subLocality!);
        if (place.locality?.isNotEmpty == true)
          addressParts.add(place.locality!);
        if (place.administrativeArea?.isNotEmpty == true)
          addressParts.add(place.administrativeArea!);
        if (place.country?.isNotEmpty == true) addressParts.add(place.country!);

        return addressParts.join(', ');
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    // Fallback to coordinates if geocoding fails
    return 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
  }

  // Main function to convert location string to readable address
  static Future<String> getReadableLocation(String locationStr) async {
    // Parse the location string
    final locationMap = parseLocationString(locationStr);
    if (locationMap == null) {
      return 'Invalid location data';
    }

    // Extract coordinates
    final coordinates = getCoordinates(locationMap);
    if (coordinates == null) {
      return 'Invalid coordinates';
    }

    final longitude = coordinates[0];
    final latitude = coordinates[1];

    // Get readable address
    return await getAddressFromCoordinates(longitude, latitude);
  }
}
