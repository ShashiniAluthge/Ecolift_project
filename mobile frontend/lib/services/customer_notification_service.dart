import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class CustomerNotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final ValueNotifier<List<Map<String, dynamic>>> notificationsNotifier =
      ValueNotifier([]);

  static final ValueNotifier<int?> selectedNotificationIndex =
      ValueNotifier(null);

  static const _storageKey = 'customer_notifications';
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
          'customer_channel_id',
          'Customer Notifications',
          channelDescription: 'Notifications for customer pickup updates',
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
  // Firebase Messaging for Customer - ONLY handles customer notifications
  // ----------------------------
  static Future<void> setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Filter messages to only handle customer notifications
    FirebaseMessaging.onMessage.listen((message) {
      if (_isCustomerNotification(message)) {
        handleIncomingMessage(message);
      } else {
        print(
            'Customer service ignoring non-customer notification: ${message.data['type']}');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_isCustomerNotification(message)) {
        handleIncomingMessage(message);
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && _isCustomerNotification(message)) {
        handleIncomingMessage(message);
      }
    });
  }

  // Check if the notification is specifically for customers
  static bool _isCustomerNotification(RemoteMessage message) {
    final notificationType = message.data['type'] ?? '';
    final target = message.data['target'] ?? '';

    // Only handle notifications specifically meant for customers
    return notificationType == 'PICKUP_ACCEPTED' || target == 'customer';
  }

  static Future<void> handleIncomingMessage(RemoteMessage message) async {
    print('Customer FCM data payload: ${message.data}');

    // Double check this is a customer notification
    if (!_isCustomerNotification(message)) {
      print(
          'Customer service: Ignoring notification type: ${message.data['type']}');
      return;
    }

    final notificationType = message.data['type'] ?? '';

    final newNotification = {
      'id': '${DateTime.now().millisecondsSinceEpoch}_customer', // Unique ID
      'title': message.notification?.title ?? 'Pickup Update',
      'body':
          message.notification?.body ?? 'Your pickup request has been updated',
      'date': DateTime.now().toIso8601String(),
      'data': {
        'pickupId': message.data['pickupId'],
        'collectorId': message.data['collectorId'],
        'collectorName': message.data['collectorName'] ?? 'Collector',
        'acceptedAt': message.data['acceptedAt'],
        'location': message.data['location'],
        'items': message.data['items'],
        'type': notificationType,
        'target': 'customer',
      },
      'read': false,
    };

    // Check for duplicates before adding
    final isDuplicate = notifications.any((existing) {
      if (existing['id'] == newNotification['id']) return true;

      final existingData = existing['data'] as Map<String, dynamic>?;
      final newData = newNotification['data'] as Map<String, dynamic>?;

      if (existingData != null && newData != null) {
        return existingData['pickupId'] == newData['pickupId'] &&
            existingData['type'] == newData['type'];
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
      print('Duplicate customer notification ignored');
    }
  }
}
