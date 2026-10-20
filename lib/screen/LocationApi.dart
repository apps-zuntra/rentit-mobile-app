import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocationApi {
  static Future<void> sendLocation(Map<String, dynamic> loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      print("?? TOKEN: $token");

      if (token == null) {
        print("? TOKEN NULL");
        return;
      }

      final url = Uri.parse(
        "https://rentit-backend-omega.vercel.app/user/location",
      );

      print("?? CALLING API: $url");
      print("?? BODY: $loc");

      final res = await http
          .put(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(loc),
          )
          .timeout(const Duration(seconds: 10)); // ?? ADD TIMEOUT

      print("?? STATUS: ${res.statusCode}");
      print("?? RESPONSE: ${res.body}");
    } catch (e) {
      print("? API ERROR: $e");
    }
  }
}
