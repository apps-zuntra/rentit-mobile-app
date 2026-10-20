// notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
//  CONSTANTS
// -----------------------------------------------------------------------------

const String kBaseUrl = "https://rentit-backend-omega.vercel.app";

// -----------------------------------------------------------------------------
//  ENUMS
// -----------------------------------------------------------------------------

enum NotificationCategory { booking, message, offer, system }

// -----------------------------------------------------------------------------
//  MODEL
// -----------------------------------------------------------------------------

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final NotificationCategory category;
  final int? visitId;
  final int? propertyId;
  final String? propertyType;
  final int? otherUserId; // chat counterparty
  final String? otherUserName; // chat counterparty name

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.category,
    this.visitId,
    this.propertyId,
    this.propertyType,
    this.otherUserId,
    this.otherUserName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'category': category.name,
    'visitId': visitId,
    'propertyId': propertyId,
    'propertyType': propertyType,
    'otherUserId': otherUserId,
    'otherUserName': otherUserName,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    createdAt: _parseDate(j['createdAt']),
    isRead: j['isRead'] as bool? ?? false,
    category: NotificationCategory.values.firstWhere(
      (c) => c.name == j['category'],
      orElse: () => NotificationCategory.system,
    ),
    visitId: _parseInt(j['visitId']),
    propertyId: _parseInt(j['propertyId']),
    propertyType: j['propertyType']?.toString(),
    otherUserId: _parseInt(j['otherUserId']),
    otherUserName: j['otherUserName']?.toString(),
  );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    category: category,
    visitId: visitId,
    propertyId: propertyId,
    propertyType: propertyType,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
  );

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

// -----------------------------------------------------------------------------
//  SERVICE
// -----------------------------------------------------------------------------

class NotificationService {
  NotificationService._();

  static const String _kCacheKey = 'app_notifications_v2';

  // -- Auth -------------------------------------------------------------------

  static Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');

  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // -- Cache ------------------------------------------------------------------

  static Future<List<AppNotification>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCache(List<AppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCacheKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  // -- Read -------------------------------------------------------------------

  static Future<List<AppNotification>> getAll() async {
    final token = await _token();

    if (token != null && token.isNotEmpty) {
      try {
        final res = await http
            .get(
              Uri.parse('$kBaseUrl/notification/my'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List)
              .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          await _saveCache(list);
          return list;
        }
      } catch (e) {
        debugPrint('??  getAll remote error: $e � using cache');
      }
    }

    final cached = await _loadCache();
    cached.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return cached;
  }

  static Future<int> unreadCount() async {
    final list = await getAll();
    return list.where((n) => !n.isRead).length;
  }

  // -- Write ------------------------------------------------------------------

  static Future<void> markAsRead(String id) async {
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      try {
        await http
            .patch(
              Uri.parse('$kBaseUrl/notification/$id/read'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('??  markAsRead remote error: $e');
      }
    }
    final list = await _loadCache();
    final updated = list
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    await _saveCache(updated);
  }

  static Future<void> markAllAsRead() async {
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      try {
        await http
            .patch(
              Uri.parse('$kBaseUrl/notification/read-all'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('??  markAllAsRead remote error: $e');
      }
    }
    final list = await _loadCache();
    final updated = list.map((n) => n.copyWith(isRead: true)).toList();
    await _saveCache(updated);
  }

  static Future<void> delete(String id) async {
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      try {
        await http
            .delete(
              Uri.parse('$kBaseUrl/notification/$id'),
              headers: _headers(token),
            )
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('??  delete remote error: $e');
      }
    }
    final list = await _loadCache();
    final updated = list.where((n) => n.id != id).toList();
    await _saveCache(updated);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
  }

  // -- Send to another user ---------------------------------------------------

  static Future<void> sendToUser({
    required int recipientId,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.booking,
    int? visitId,
    int? propertyId,
    String? propertyType,
    int? otherUserId,
    String? otherUserName,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      debugPrint('??  sendToUser: no token');
      return;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$kBaseUrl/notification/send'),
            headers: _headers(token),
            body: jsonEncode({
              'recipientId': recipientId,
              'title': title,
              'body': body,
              'category': category.name,
              'visitId': visitId,
              'propertyId': propertyId,
              'propertyType': propertyType,
              'otherUserId': otherUserId,
              'otherUserName': otherUserName,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('? Notification sent to user $recipientId');
      } else {
        debugPrint('??  sendToUser failed: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('? sendToUser error: $e');
    }
  }

  // -- Message notification ---------------------------------------------------

  /// Call this whenever a chat message is sent.
  /// [recipientId]   = the user who should receive the notification
  /// [senderName]    = name of the person sending the message
  /// [senderId]      = userId of the sender (so recipient can open the chat)
  /// [message]       = preview text
  /// [propertyId]    = the property this chat is about
  static Future<void> sendMessageNotification({
    required int recipientId,
    required String senderName,
    required int senderId,
    required String message,
    required int propertyId,
  }) async {
    await sendToUser(
      recipientId: recipientId,
      title: 'New message from $senderName',
      body: message,
      category: NotificationCategory.message,
      propertyId: propertyId,
      otherUserId: senderId,
      otherUserName: senderName,
    );
  }

  // -- Visit booked -----------------------------------------------------------

  static Future<AppNotification> addVisitBookedNotification({
    required String propertyName,
    required String propertyType,
    required String date,
    required String time,
    required int propertyId,
    int? visitId,
    int? ownerUserId,
    String? ownerName,
    int? tenantUserId,
    String? tenantName,
  }) async {
    final token = await _token();
    AppNotification? saved;

    if (token != null && token.isNotEmpty) {
      try {
        final res = await http
            .post(
              Uri.parse('$kBaseUrl/notification/send'),
              headers: _headers(token),
              body: jsonEncode({
                'recipientId': null,
                'title': '?? Visit Booked!',
                'body':
                    'Your visit to $propertyName ($propertyType) is scheduled for $date at $time.',
                'category': NotificationCategory.booking.name,
                'visitId': visitId,
                'propertyId': propertyId,
                'propertyType': propertyType,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          saved = AppNotification.fromJson(
            data is Map<String, dynamic> ? data : data['notification'],
          );
        }
      } catch (e) {
        debugPrint('??  addVisitBookedNotification error: $e');
      }
    }

    saved ??= AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '?? Visit Booked!',
      body:
          'Your visit to $propertyName ($propertyType) is scheduled for $date at $time.',
      createdAt: DateTime.now(),
      isRead: false,
      category: NotificationCategory.booking,
      visitId: visitId,
      propertyId: propertyId,
      propertyType: propertyType,
    );

    final cached = await _loadCache();
    // Avoid duplicates by visitId
    if (visitId != null) {
      cached.removeWhere(
        (n) =>
            n.visitId == visitId && n.category == NotificationCategory.booking,
      );
    }
    cached.insert(0, saved);
    await _saveCache(cached);

    if (ownerUserId != null && ownerUserId > 0) {
      await sendToUser(
        recipientId: ownerUserId,
        title: '?? New Visit Booked',
        body:
            'A tenant has booked a visit to $propertyName ($propertyType) on $date at $time.',
        category: NotificationCategory.booking,
        visitId: visitId,
        propertyId: propertyId,
        propertyType: propertyType,
        otherUserId: tenantUserId,
        otherUserName: tenantName,
      );
    }

    return saved;
  }

  // -- Visit rescheduled ------------------------------------------------------

  static Future<AppNotification> addVisitRescheduledNotification({
    required String propertyName,
    required String propertyType,
    required String date,
    required String time,
    required int propertyId,
    int? visitId,
    int? ownerUserId,
    String? ownerName,
    int? tenantUserId,
    String? tenantName,
  }) async {
    final token = await _token();
    AppNotification? saved;

    if (token != null && token.isNotEmpty) {
      try {
        final res = await http
            .post(
              Uri.parse('$kBaseUrl/notification/send'),
              headers: _headers(token),
              body: jsonEncode({
                'recipientId': null,
                'title': '?? Visit Rescheduled',
                'body':
                    'Your visit to $propertyName ($propertyType) has been rescheduled to $date at $time.',
                'category': NotificationCategory.booking.name,
                'visitId': visitId,
                'propertyId': propertyId,
                'propertyType': propertyType,
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          saved = AppNotification.fromJson(
            data is Map<String, dynamic> ? data : data['notification'],
          );
        }
      } catch (e) {
        debugPrint('??  addVisitRescheduledNotification error: $e');
      }
    }

    saved ??= AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '?? Visit Rescheduled',
      body:
          'Your visit to $propertyName ($propertyType) has been rescheduled to $date at $time.',
      createdAt: DateTime.now(),
      isRead: false,
      category: NotificationCategory.booking,
      visitId: visitId,
      propertyId: propertyId,
      propertyType: propertyType,
    );

    final cached = await _loadCache();
    cached.insert(0, saved);
    await _saveCache(cached);

    if (ownerUserId != null && ownerUserId > 0) {
      await sendToUser(
        recipientId: ownerUserId,
        title: '?? Visit Rescheduled',
        body:
            'A tenant rescheduled their visit to $propertyName ($propertyType) to $date at $time.',
        category: NotificationCategory.booking,
        visitId: visitId,
        propertyId: propertyId,
        propertyType: propertyType,
        otherUserId: tenantUserId,
        otherUserName: tenantName,
      );
    }

    return saved;
  }

  // -- Generic add -----------------------------------------------------------

  static Future<AppNotification> add({
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
    int? visitId,
    int? propertyId,
    String? propertyType,
    int? recipientId,
    int? otherUserId,
    String? otherUserName,
  }) async {
    final n = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now(),
      isRead: false,
      category: category,
      visitId: visitId,
      propertyId: propertyId,
      propertyType: propertyType,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
    );

    if (recipientId != null) {
      await sendToUser(
        recipientId: recipientId,
        title: title,
        body: body,
        category: category,
        visitId: visitId,
        propertyId: propertyId,
        propertyType: propertyType,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
      );
    } else {
      final list = await _loadCache();
      list.insert(0, n);
      await _saveCache(list);
    }

    return n;
  }
}
