import 'dart:convert';
import 'package:eco_lift/services/errors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PickupService {
  static String baseUrl = 'http://10.0.2.2:5000'; // For Android emulator
  // static const String baseUrl = 'http://localhost:5000'; // For iOS simulator
  // static const String baseUrl = 'http://your-actual-ip:5000'; // For physical device

  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> createInstantPickup({
    required List<String> wasteTypes,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    // Convert waste types to items format expected by backend
    final items = wasteTypes
        .map((type) => {
              'type': type,
              'quantity': 1, // Default quantity of 1 for each waste type
              'description': 'Instant pickup request for $type waste'
            })
        .toList();

    final response = await http.post(
      Uri.parse('$baseUrl/api/pickups'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'location': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
        'items': items,
        // No scheduledTime for instant pickup
      }),
    );

    if (response.statusCode != 201) {
      final errorBody = jsonDecode(response.body);
      print(jsonDecode(response.body));
      throw Exception(
          'Failed to create instant pickup: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<void> createScheduledPickup({
    required List<String> wasteTypes,
    required double latitude,
    required double longitude,
    required String address,
    required DateTime scheduledDateTime,
  }) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    // Convert waste types to items format expected by backend
    final items = wasteTypes
        .map((type) => {
              'type': type,
              'quantity': 1, // Default quantity of 1 for each waste type
              'description': 'Scheduled pickup request for $type waste'
            })
        .toList();

    final response = await http.post(
      Uri.parse('$baseUrl/api/pickups'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'location': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
        'items': items,
        'scheduledTime': scheduledDateTime.toIso8601String(),
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
          'Failed to create scheduled pickup: ${response.body.isNotEmpty ? response.body : "Unknown error"}');
    }
  }

  static Future<List<Map<String, dynamic>>> getCustomerActivitiesByStatus(
      String status) async {
    print('--- getCustomerActivitiesByStatus called ---');
    print('Requested status: $status');

    final authToken = await _getAuthToken();
    if (authToken == null) {
      print('❌ Error: Authentication token not found.');
      throw Exception('Authentication token not found. Please login again.');
    }

    final url = '$baseUrl/api/pickups/activities/$status';
    print('API URL: $url');
    print('Auth Token (first 20 chars): ${authToken.substring(0, 20)}...');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    print('Response status: ${response.statusCode}');
    print('Raw response body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final List<dynamic> data = jsonDecode(response.body);
        print('Decoded JSON length: ${data.length}');
        for (var i = 0; i < data.length; i++) {
          print('Activity[$i]: ${data[i]}');
        }

        return data
            .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
            .toList();
      } catch (e) {
        print('❌ JSON decode error: $e');
        throw Exception('Failed to parse pickups data: $e');
      }
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        print('❌ Error response: $errorBody');
        throw Exception(
            'Failed to fetch pickups: ${errorBody['message'] ?? response.body}');
      } catch (e) {
        print('❌ Non-JSON error response: ${response.body}');
        throw Exception('Failed to fetch pickups: ${response.body}');
      }
    }
  }

  static Future<List<Map<String, dynamic>>>
      getAllCustomersPendingPickups() async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/pickups/allPendings'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    print('🔹 Response status: ${response.statusCode}');
    print('🔹 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('✅ Pending orders details: $data');
      return data
          .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
          .toList();
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        print('❌ Error response parsed: $errorBody');
        throw Exception(
            'Failed to fetch all customers pending pickups: ${errorBody['message'] ?? response.body}');
      } catch (e) {
        print('❌ Error response raw: ${response.body}');
        throw Exception(
            'Failed to fetch all customers pending pickups. Raw body: ${response.body}');
      }
    }
  }

  static Future<Map<String, dynamic>> acceptPickupRequest(
      String requestId) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    // print('🚀 Attempting to accept pickup with ID: $requestId');
    // print('🔗 Request URL: $baseUrl/api/pickups/$requestId/accept');
    // print('🔑 Auth token exists: ${authToken.isNotEmpty}');

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/pickups/$requestId/accept'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      // print('📊 Response status code: ${response.statusCode}');
      // print('📄 Response headers: ${response.headers}');
      // print('📝 Raw response body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html>')) {
        // print('❌ Server returned HTML error page instead of JSON');
        throw Exception(
            'Server error: Received HTML response instead of JSON. Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          // print('✅ Successfully parsed JSON response');
          return data;
        } catch (jsonError) {
          // print('❌ JSON parsing failed: $jsonError');
          // print('📄 Response body that failed to parse: ${response.body}');
          throw Exception('Invalid JSON response from server: $jsonError');
        }
      } else {
        // Handle non-200 status codes
        if (response.statusCode != 200) {
          throw PickupAlreadyAcceptedException();
        }

        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(
              'Failed to accept pickup request: ${errorBody['message'] ?? response.body}');
        } catch (jsonError) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      // print('❌ Network/Request error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAcceptedPickups() async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/pickups/accepted'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
          .toList();
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
          'Failed to fetch accepted pickups: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getInProgressPickups() async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/pickups/inProgress'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
          .toList();
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
          'Failed to fetch inprogress pickups: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<Map<String, dynamic>> updatePickupStatus(
    String requestId,
    String status,
  ) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/pickups/$requestId/status'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'status': status,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
          'Failed to update pickup status: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<Map<String, dynamic>> cancelPickup(String requestId) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/pickups/$requestId/cancel'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
          'Failed to cancel pickup: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<Map<String, dynamic>> startPickup(String requestId) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/api/pickups/$requestId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'status': 'In Progress',
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
          'Failed to start pickup: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getCompletedPickups() async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/pickups/completed'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
          .toList();
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(
          'Failed to fetch completed pickups: ${errorBody['message'] ?? response.body}');
    }
  }

  static Future<Map<String, dynamic>> getRequestedPickupDetails(
      String userId) async {
    final authToken = await _getAuthToken();
    if (authToken == null) {
      throw Exception('Authentication token not found. Please login again.');
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:4000/api/users/customer/requested/$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Try to decode JSON safely
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data.containsKey('customer')) {
            print('Customer details fetched successfully: ${data['customer']}');
            return data;
          } else {
            throw Exception('Response JSON does not contain "customer" field.');
          }
        } catch (e) {
          print('Failed to parse JSON: ${e}');
          throw Exception('Invalid JSON response from server');
        }
      } else {
        // Handle non-200 responses
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(
              'Failed to fetch customer details: ${errorData['message'] ?? response.body}');
        } catch (_) {
          // If body is not JSON (HTML error), just throw raw body
          throw Exception(
              'Server error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      print('Error fetching customer details: $e');
      rethrow;
    }
  }

  static Future<void> updateCollectorLocation(
      String requestId, double latitude, double longitude) async {
    try {
      print('--- updateCollectorLocation called ---');
      print('Request ID: $requestId');
      print('Latitude: $latitude, Longitude: $longitude');

      final authToken = await _getAuthToken();
      if (authToken == null) {
        print('Error: Authentication token not found');
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await http.patch(
        Uri.parse('http://10.0.2.2:4000/api/users/collectors/location'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinates': [longitude, latitude],
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update collector location');
      }

      print('Collector location updated successfully!');
    } catch (e) {
      print('Error in updateCollectorLocation: $e');
      rethrow;
    }
  }

  static Future<LatLng?> getCollectorLocation(String collectorId) async {
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:4000/api/users/collectors/location?collectorId=$collectorId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      print('--- getCollectorLocation called ---');
      print('Collector ID: $collectorId');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch collector location');
      }

      final data = jsonDecode(response.body);
      final coords = data['location'] as List<dynamic>;
      return LatLng(
          coords[1], coords[0]); // convert [lng, lat] → LatLng(lat, lng)
    } catch (e) {
      print('Error fetching collector location: $e');
      return null;
    }
  }
}
