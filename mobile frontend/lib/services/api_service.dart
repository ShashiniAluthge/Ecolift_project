import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ApiService {
  // Get the appropriate base URL depending on platform
  static String get baseUrl {
    if (kIsWeb) {
      // For web platform
      return 'http://localhost:4000/api/users';
    } else if (Platform.isAndroid) {
      // For Android emulator
      return 'http://10.0.2.2:4000/api/users';
    } else {
      // For iOS simulator or physical devices
      return 'http://localhost:4000/api/users';
    }
  }

  Future<String?> getFcmToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    return token;
  }

  static Future<Map<String, dynamic>> registerCustomer(
      Customer customer) async {
    try {
      // Use the customer's toJson method to create the request body
      final requestBody = customer.toJson();

      final response = await http
          .post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please try again.');
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseData['message'] ?? 'Registration successful',
          'data': responseData['user'] ?? responseData,
        };
      } else {
        String message;
        try {
          final responseData = jsonDecode(response.body);
          message = responseData['message'] ??
              responseData['error'] ??
              'Server error occurred';
        } catch (e) {
          message = 'Server error occurred';
        }

        return {
          'success': false,
          'message': message,
        };
      }
    } catch (e) {
      String errorMessage;

      if (e is TimeoutException) {
        errorMessage = 'Connection timed out. Please try again.';
      } else if (e.toString().contains('XMLHttpRequest error')) {
        errorMessage =
            'CORS error: Please ensure the backend server has CORS enabled';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage =
            'Could not connect to the server. Please ensure the backend is running on port 4000';
      } else {
        errorMessage = 'Network error: ${e.toString()}';
      }

      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  Future<Map<String, dynamic>> login(
      String email, String password, String role) async {
    try {
      String? fcmToken = await getFcmToken();
      print(' login FCM Token: $fcmToken');
      final response = await http
          .post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': role,
          'fcmToken': fcmToken,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please try again.');
        },
      );

      final responseData = jsonDecode(response.body);
      print(' api service fcm token: $fcmToken');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'token': responseData['token'],
          'user': responseData['user'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      String errorMessage;

      if (e is TimeoutException) {
        errorMessage = 'Connection timed out. Please try again.';
      } else if (e.toString().contains('XMLHttpRequest error')) {
        errorMessage =
            'CORS error: Please ensure the backend server has CORS enabled';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage =
            'Could not connect to the server. Please ensure the backend is running on port 4000';
      } else {
        errorMessage = 'Network error: Failed to connect to server';
      }

      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Deprecated: Use login() instead
  Future<Map<String, dynamic>> loginCustomer(
      String email, String password) async {
    return login(email, password, 'customer');
  }

  // Helper method for collector login
  Future<Map<String, dynamic>> loginCollector(
      String email, String password) async {
    return login(email, password, 'collector');
  }
}
