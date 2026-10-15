// dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/main/Listingscreen.dart';
import 'package:rentit/main/chatscreen.dart';
import 'package:rentit/notification/notification_service.dart';
import 'package:rentit/notification/notifications_screen.dart';
import 'package:rentit/pg_page/pg_page/pg_post/PostpertyNavscreen.dart';
import 'package:rentit/screen/account_screen.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/main/plans.dart';
import 'package:rentit/core/image_utils.dart';

const String _kApiBase = "https://rentit-backend-yti9.onrender.com";

// ─────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF5F6F8);
  static const white = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const navy = Color(0xFF1B2B3A);
  static const text = Color(0xFF111827);
  static const sub = Color(0xFF6B7280);
  static const muted = Color(0xFF9CA3AF);
  static const teal = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
  static const purple = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;

  // user
  String _userName = "";
  String _userInitial = "T";

  // stats
  int _activeListings = 0;
  int _newEnquiries = 0;
  int _totalViews = 0;
  int _activeChats = 0;
  int _unreadTotal = 0;

  String _listingsDelta = "";
  String _enquiriesDelta = "";
  String _viewsDelta = "";
  String _chatsDelta = "";

  // recent enquiries
  List<Map<String, dynamic>> _recentEnquiries = [];

  // active listings (for the "Active Listings" card section — max 1 shown)
  List<Map<String, dynamic>> _activeListingsList = [];

  // avatar colours pool
  static const List<Color> _avatarColors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  Color _avatarColor(String name) {
    final i = name.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length;
    return _avatarColors[i];
  }

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _loadNotificationCount();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    await _loadNotificationCount();

    try {
      await Future.wait([_loadUserName(), _loadProperties(), _loadChats()]);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  int _notificationCount = 0;

  Future<void> _loadNotificationCount() async {
    try {
      final count = await NotificationService.unreadCount();

      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      debugPrint("Notification Count Error: $e");
    }
  }

  // ── user name ──────────────────────────────
  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) return;

      final res = await http.get(
        Uri.parse("$_kApiBase/user/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final name = (data["name"] ?? "").toString();
        if (!mounted) return;
        setState(() {
          _userName = name;
          _userInitial = name.isNotEmpty ? name[0].toUpperCase() : "?";
        });
      }
    } catch (e) {
      debugPrint("User load error: $e");
    }
  }

  // ── properties + views ─────────────────────
  Future<void> _loadProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final userId =
          prefs.getInt("userId") ??
          int.tryParse(prefs.getString("userId") ?? "") ??
          0;
      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      // Always start with a fresh empty list
      final List<Map<String, dynamic>> all = [];

      // PG
      try {
        final r = await http.get(
          Uri.parse("$_kApiBase/property/my"),
          headers: headers,
        );
        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          if (decoded is List) {
            final items = List<Map<String, dynamic>>.from(decoded);
            for (final e in items) e['_listingType'] = 'pg';
            all.addAll(items);
          }
        }
      } catch (_) {}

      // Commercial
      try {
        final r = await http.get(
          Uri.parse("$_kApiBase/commercial"),
          headers: headers,
        );
        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          if (decoded is List) {
            final items = List<Map<String, dynamic>>.from(decoded);
            for (final e in items) e['_listingType'] = 'commercial';
            all.addAll(items);
          }
        }
      } catch (_) {}

      // Apartment
      try {
        final r = await http.get(
          Uri.parse("$_kApiBase/apartment/my"),
          headers: headers,
        );
        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          if (decoded is List) {
            final items = List<Map<String, dynamic>>.from(decoded);
            for (final e in items) e['_listingType'] = 'apartment';
            all.addAll(items);
          }
        }
      } catch (_) {}

      // Flatmate
      try {
        final r = await http.get(
          Uri.parse("$_kApiBase/flatmate/all"),
          headers: headers,
        );
        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          if (decoded is List) {
            final items = List<Map<String, dynamic>>.from(
              decoded,
            ).where((e) => e["userId"] == userId).toList();
            for (final e in items) e['_listingType'] = 'flatmate';
            all.addAll(items);
          }
        }
      } catch (_) {}

      if (!mounted) return;

      // Active listings
      final activeList = all.where((p) {
        if (p['_listingType'] == 'flatmate') return true;
        return p["isDraft"] == false && (p["currentStep"] ?? 0) == 7;
      }).toList();

      // New this week
      final now = DateTime.now();
      final thisWeek = all.where((p) {
        final t = DateTime.tryParse(p["createdAt"] ?? "");
        return t != null && now.difference(t).inDays <= 7;
      }).length;

      // Total views — sum viewscount across all property types
      int totalViews = 0;
      for (final p in all) {
        final v = p["viewscount"];
        if (v is int) {
          totalViews += v;
        } else if (v is double) {
          totalViews += v.toInt();
        } else if (v is String) {
          totalViews += int.tryParse(v) ?? 0;
        }
      }

      setState(() {
        _activeListings = activeList.length;
        _activeListingsList = activeList;
        _listingsDelta = thisWeek > 0 ? "+$thisWeek this week" : "No change";
        _totalViews = totalViews;
        _viewsDelta = "All listings";
      });
    } catch (e) {
      debugPrint("Properties error: $e");
    }
  }

  // ── chats ──────────────────────────────────
  Future<void> _loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId =
          prefs.getInt("userId") ??
          int.tryParse(prefs.getString("userId") ?? "") ??
          0;
      final r = await http.get(
        Uri.parse("$_kApiBase/chat/list?userId=$userId"),
        headers: {"Content-Type": "application/json"},
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return;
        final chats = List<Map<String, dynamic>>.from(decoded);
        chats.sort((a, b) {
          final at = DateTime.tryParse(a["createdAt"] ?? "") ?? DateTime(2000);
          final bt = DateTime.tryParse(b["createdAt"] ?? "") ?? DateTime(2000);
          return bt.compareTo(at);
        });
        final now = DateTime.now();
        final last30 = chats.where((c) {
          final t = DateTime.tryParse(c["createdAt"] ?? "");
          return t != null && now.difference(t).inDays <= 30;
        }).length;
        final last7 = chats.where((c) {
          final t = DateTime.tryParse(c["createdAt"] ?? "");
          return t != null && now.difference(t).inDays <= 7;
        }).length;
        int unread = 0;
        for (final c in chats) {
          final u = c["unreadCount"];
          if (u is int) unread += u;
        }
        final today = chats.where((c) {
          final t = DateTime.tryParse(c["createdAt"] ?? "");
          return t != null && now.difference(t).inDays == 0;
        }).length;

        setState(() {
          _newEnquiries = last30;
          _activeChats = last7;
          _unreadTotal = unread;
          _recentEnquiries = chats.take(3).toList();
          _enquiriesDelta = today > 0 ? "+$today today" : "No new today";
          _chatsDelta = unread > 0 ? "$unread unread" : "All read";
        });
      }
    } catch (e) {
      debugPrint("Chats error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
      if (diff.inHours < 24)
        return "${diff.inHours} hr${diff.inHours > 1 ? 's' : ''} ago";
      if (diff.inDays == 1) return "Yesterday";
      return "${diff.inDays} days ago";
    } catch (_) {
      return "";
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length >= 2) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : "?";
  }

  String _listingTitle(Map<String, dynamic> p) {
    final t = p['_listingType'] ?? '';
    if (t == 'flatmate') {
      return p["apartmentName"] ?? p["apartmentType"] ?? "Flatmate Listing";
    }
    return p["propertyName"] ??
        p["commercialPropertyType"] ??
        p["propertyType2"] ??
        p["propertyType"] ??
        "Property";
  }

  String _listingAddress(Map<String, dynamic> p) {
    final street = (p["street"] ?? "").toString().trim();
    final landmark = (p["landmark"] ?? "").toString().trim();
    final city = (p["city"] ?? "").toString().trim();

    final parts = <String>[];

    if (street.isNotEmpty && street.toLowerCase() != "null") {
      parts.add(street);
    }

    if (landmark.isNotEmpty &&
        landmark.toLowerCase() != "null" &&
        landmark != street) {
      parts.add(landmark);
    }

    if (city.isNotEmpty && city.toLowerCase() != "null") {
      parts.add(city);
    }

    return parts.isNotEmpty ? parts.join(", ") : "Location not available";
  }

  String? _firstImage(Map<String, dynamic> p) {
    final images = p["images"];
    if (images is List && images.isNotEmpty) return images[0].toString();
    return null;
  }

  void _navigateToAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountScreen()),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.navy))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: _C.navy,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPromoCard(),
                          const SizedBox(height: 20),
                          _buildStatsGrid(),
                          const SizedBox(height: 28),
                          _buildActiveListingsSection(),
                          const SizedBox(height: 28),
                          _buildRecentEnquiries(),
                          const SizedBox(height: 28),
                          _buildQuickActions(),
                          const SizedBox(height: 28),
                          _buildSupportCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    final greeting = _userName.isNotEmpty
        ? "Welcome back.., $_userName!"
        : "Welcome back!";

    return Container(
      color: _C.navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Manage your PGs and grow your\nbusiness.",
                  style: TextStyle(fontSize: 13, color: Color(0xFFABB8C3)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );

              _loadNotificationCount();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (_notificationCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _notificationCount > 99
                              ? "99+"
                              : _notificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _navigateToAccount,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _userInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PROMO CARD
  // ─────────────────────────────────────────────
  Widget _buildPromoCard() {
    return Container(
      height: 158,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF8A90FF), Color(0xFF4A5DAA)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: Image.asset(
                "assets/pg_img.png",
                width: 165,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 150, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Looking to rent a PG?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Find verified PGs for yourself",
                    style: TextStyle(
                      color: Colors.white.withOpacity(.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20344F),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Explore PGs",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STATS GRID (2×2)
  // ─────────────────────────────────────────────
  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                iconWidget: _iconBox(
                  Icons.grid_view_rounded,
                  const Color(0xFFEFF6FF),
                  _C.teal,
                ),
                value: _activeListings.toString(),
                label: "Active Listings",
                delta: _listingsDelta.isNotEmpty
                    ? _listingsDelta
                    : "+0 this week",
                deltaColor: _C.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                iconWidget: _iconBox(
                  Icons.chat_bubble_outline_rounded,
                  const Color(0xFFECFDF5),
                  _C.green,
                ),
                value: _newEnquiries.toString(),
                label: "New Enquiries",
                delta: _enquiriesDelta.isNotEmpty
                    ? _enquiriesDelta
                    : "+0 today",
                deltaColor: _C.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                iconWidget: _iconBox(
                  Icons.remove_red_eye_outlined,
                  const Color(0xFFF5F3FF),
                  _C.purple,
                ),
                value: _totalViews.toString(),
                label: "Total Views",
                delta: _viewsDelta.isNotEmpty ? _viewsDelta : "All listings",
                deltaColor: _C.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                iconWidget: _iconBox(
                  Icons.people_outline_rounded,
                  const Color(0xFFFFFBEB),
                  _C.orange,
                ),
                value: _activeChats.toString(),
                label: "Active Chats",
                delta: _chatsDelta.isNotEmpty ? _chatsDelta : "0 unread",
                deltaColor: _C.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required Widget iconWidget,
    required String value,
    required String label,
    required String delta,
    required Color deltaColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _C.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: _C.sub)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.arrow_upward_rounded, size: 12, color: deltaColor),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  delta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: deltaColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 19, color: iconColor),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIVE LISTINGS SECTION
  // ─────────────────────────────────────────────
  Widget _buildActiveListingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Active Listings ($_activeListings)",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyListingsScreen()),
              ),
              child: const Row(
                children: [
                  Text(
                    "View All",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.text,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 14, color: _C.text),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activeListingsList.isEmpty)
          _emptyCard("No active listings yet")
        else
          _buildSingleListingCard(_activeListingsList.first),
      ],
    );
  }

  Widget _buildSingleListingCard(Map<String, dynamic> p) {
    final images = extractPropertyImages(p, _kApiBase);
    final imageUrl = images.isNotEmpty ? images.first : null;
    final title = _listingTitle(p);
    final address = _listingAddress(p);

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: buildPropertyImage(
                  imageUrl,
                  width: double.infinity,
                  height: 185,
                  fit: BoxFit.cover,
                  baseUrl: _kApiBase,
                  placeholder: () => _imgPlaceholder(),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _C.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Active",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz, size: 18, color: _C.text),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: _C.sub,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 12, color: _C.sub),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: _C.sub,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$_newEnquiries Enquiries",
                      style: const TextStyle(fontSize: 12, color: _C.sub),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyListingsScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _C.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Edit",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _C.text,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MainNavigationScreen(initialIndex: 3),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Boost",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.navy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: double.infinity,
    height: 185,
    color: const Color(0xFFF0F2F5),
    child: const Icon(
      Icons.apartment_rounded,
      color: Color(0xFFD1D5DB),
      size: 50,
    ),
  );

  // ─────────────────────────────────────────────
  // RECENT ENQUIRIES
  // ─────────────────────────────────────────────
  Widget _buildRecentEnquiries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          "Recent Enquiries",
          onViewAll: () => Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  const PgOwnerNavigationScreen(initialIndex: 3),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _recentEnquiries.isEmpty
            ? _emptyCard("No enquiries yet")
            : Container(
                decoration: BoxDecoration(
                  color: _C.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: _recentEnquiries.asMap().entries.map((entry) {
                    final i = entry.key;
                    final chat = entry.value;

                    final name = (chat["otherUserName"] ?? "User") as String;
                    final lastMessage = (chat["message"] ?? "")
                        .toString()
                        .trim();
                    final time = _formatTime(chat["createdAt"] as String?);
                    final unread = (chat["unreadCount"] as int?) ?? 0;
                    final prop = lastMessage.isNotEmpty
                        ? lastMessage
                        : "New enquiry";

                    final online = unread > 0;
                    final isLast = i == _recentEnquiries.length - 1;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final userId =
                                prefs.getInt("userId") ??
                                int.tryParse(prefs.getString("userId") ?? "") ??
                                0;
                            final otherUserId = chat["senderId"] == userId
                                ? chat["receiverId"]
                                : chat["senderId"];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  propertyId: chat["propertyId"] ?? 0,
                                  ownerId: otherUserId,
                                  ownerName: chat["otherUserName"] ?? "User",
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: _avatarColor(name),
                                      child: Text(
                                        _initials(name),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 1,
                                      right: 1,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: online ? _C.green : _C.muted,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _C.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _C.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        prop,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _C.sub,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _C.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: _C.muted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            color: Colors.grey.shade100,
                            indent: 14,
                            endIndent: 14,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.add_circle_outline_rounded,
        bg: const Color(0xFFEAF8F2),
        iconColor: const Color(0xFF10B981),
        label: "Add New PG",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostPropertyScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.bolt_rounded,
        bg: const Color(0xFFFFF4E8),
        iconColor: const Color(0xFFF97316),
        label: "Boost\nListing",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlansScreen()),
          );
        },
      ),
      _QuickAction(
        icon: Icons.chat_bubble_outline_rounded,
        bg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF3B82F6),
        label: "View\nMessages",
        onTap: () => Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                const PgOwnerNavigationScreen(initialIndex: 3),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
      ),
      _QuickAction(
        icon: Icons.grid_view_rounded,
        bg: const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF8B5CF6),
        label: "Manage\nListings",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyListingsScreen()),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: actions.map((action) {
            return Expanded(
              child: GestureDetector(
                onTap: action.onTap,
                child: Container(
                  height: 112,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 47,
                        height: 47,
                        decoration: BoxDecoration(
                          color: action.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          action.icon,
                          color: action.iconColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SUPPORT CARD
  // ─────────────────────────────────────────────
  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.headset_mic_outlined,
              size: 24,
              color: _C.sub,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Need help with your\nproperty listing?",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Our team is here to help you anytime.",
                  style: TextStyle(fontSize: 11, color: _C.sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(
              Icons.phone_outlined,
              size: 14,
              color: Colors.white,
            ),
            label: const Text(
              "Call Support",
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REUSABLE WIDGETS
  // ─────────────────────────────────────────────
  Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Row(
              children: [
                Text(
                  "View All",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.text,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward, size: 14, color: _C.text),
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Text(
        message,
        style: const TextStyle(color: _C.muted, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.bg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
}
