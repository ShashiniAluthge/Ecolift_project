import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  static const String baseUrl = 'http://10.0.2.2:4000'; // For Android emulator
  // static const String baseUrl = 'http://localhost:4000'; // For iOS simulator
  // static const String baseUrl = 'http://your-actual-ip:4000'; // For physical device

  static Future<Map<String, dynamic>> registerCollector({
    required String name,
    required String phone,
    required String email,
    required String password,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$baseUrl/api/users/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "name": name,
        "phone": phone,
        "email": email,
        "password": password,
        "role": "collector",
        "location": {
          "type": "Point",
          "coordinates": [longitude, latitude]
        }
      }),
    );

    final body = json.decode(response.body);
    if (response.statusCode == 201) {
      return {"success": true, "data": body};
    } else {
      return {"success": false, "error": body['message'] ?? 'Unknown error'};
    }
  }
}
