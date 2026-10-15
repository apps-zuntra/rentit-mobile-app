import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://rentit-backend-yti9.onrender.com";

  static const Map<String, String> _headers = {
    "Content-Type": "application/json",
  };

  /// SEND OTP
  static Future<void> sendOtp(String mobile) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/send-otp"),
      headers: _headers,
      body: jsonEncode({"mobile": mobile}),
    );

    print(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to send OTP");
    }
  }

  /// VERIFY OTP
  static Future<Map<String, dynamic>> verifyOtp(
    String mobile,
    String otp,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/verify-otp"),
      headers: _headers,
      body: jsonEncode({"mobile": mobile, "otp": otp}),
    );

    print(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("OTP verification failed");
    }
  }
}
