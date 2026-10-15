import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "https://rentit-backend-yti9.onrender.com";

class VisitRepository {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token") ?? "";
  }

  Future<List> fetchVisits() async {
    final res = await http.get(
      Uri.parse("$baseUrl/visit/my"),
      headers: {"Authorization": "Bearer ${await _getToken()}"},
    );
    if (res.statusCode != 200) throw Exception("Failed to fetch visits");
    return jsonDecode(res.body);
  }

  Future<List> fetchOwnerVisits() async {
    final token = await _getToken();

    print("TOKEN => $token");

    final res = await http.get(
      Uri.parse("$baseUrl/visit/owner"),
      headers: {"Authorization": "Bearer $token"},
    );

    print("STATUS => ${res.statusCode}");
    print("BODY => ${res.body}");

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body);
  }

  Future<void> cancelVisit(int id) async {
    await http.patch(
      Uri.parse("$baseUrl/visit/$id/cancel"),
      headers: {"Authorization": "Bearer ${await _getToken()}"},
    );
  }
}
