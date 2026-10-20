import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "https://rentit-backend-omega.vercel.app";

class LikeRepository {
  Future<List> fetchLikes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final userId =
        prefs.getInt("userId") ??
        int.tryParse(prefs.getString("userId") ?? "") ??
        0;

    final endpoints = [
      "$baseUrl/like/my",
      "$baseUrl/likes/my",
      if (userId > 0) "$baseUrl/like/user/$userId",
      if (userId > 0) "$baseUrl/likes/user/$userId",
    ];

    for (final ep in endpoints) {
      try {
        final res = await http.get(
          Uri.parse(ep),
          headers: {
            "Content-Type": "application/json",
            if (token.isNotEmpty) "Authorization": "Bearer $token",
            if (userId > 0) "x-user-id": "$userId",
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) return data;
        }
      } catch (_) {}
    }

    return [];
  }

  Future<bool> toggleLike(int id, [String? type]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final userId =
        prefs.getInt("userId") ??
        int.tryParse(prefs.getString("userId") ?? "") ??
        0;

    final queryParams = <String, String>{
      if (type != null && type.isNotEmpty) "type": type,
      if (userId > 0) "userId": "$userId",
    };

    final uri = Uri.parse(
      "$baseUrl/like/$id",
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final res = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token.isNotEmpty) "Authorization": "Bearer $token",
        if (userId > 0) "x-user-id": "$userId",
      },
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data["liked"] == true;
    }

    throw Exception("Toggle like failed (${res.statusCode}): ${res.body}");
  }
}
