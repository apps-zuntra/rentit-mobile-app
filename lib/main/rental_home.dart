// rental_home.dart
// Clean, professional, overflow-free implementation of RentHomeScreen
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/Search/Search.dart';
import 'package:rentit/Search/SearchModel.dart';
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/ApartmentPropertyDetails.dart';
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/ApartmentViewDetails.dart';
import 'package:rentit/ViewDetailsPages/Commercial/CommercialViewDetails.dart';
import 'package:rentit/ViewDetailsPages/Commercial/CommercialPropertyDetails.dart';
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/FlatmateViewDetails.dart';
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/FlatmatePropertyDetails.dart';
import 'package:rentit/core/auth_guard.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/main/Help&Support.dart';
import 'package:rentit/main/knowledge_detail_page.dart';
import 'package:rentit/main/buyer_plans.dart';
import 'package:rentit/main/PropertyDetails.dart';
import 'package:rentit/main/ViewAllpropertys.dart';
import 'package:rentit/notification/notification_service.dart';
import 'package:rentit/notification/notifications_screen.dart';
import 'package:rentit/pg_page/pg_page/pg_post/PostpertyNavscreen.dart';
import 'package:rentit/main/MyActivityScreen.dart';
import 'package:rentit/screen/account_screen.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const String _kBaseUrl = "https://rentit-backend-omega.vercel.app";
const String _kSearchHistoryKey = "search_history";
const int _kMaxHistory = 8;

// Brand colours
const Color kPrimary = Color(0xFF1F4C73);
const Color kOrange = Color(0xFFF97316);
const Color kBg = Color(0xFFFFFBF8);
const Color kText = Color(0xFF1A1A2E);
const Color kText2 = Color(0xFF4B5563);
const Color kText3 = Color(0xFF9CA3AF);
const Color kBorder = Color(0xFFE5E7EB);
const Color kPrimaryLight = Color(0xFFE6FAF8);

// ─── Pure helpers ─────────────────────────────────────────────────────────────
String _inr(int n) {
  if (n <= 0) return "0";
  final s = "$n";
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  String rest = s.substring(0, s.length - 3), result = '';
  int count = 0;
  for (int i = rest.length - 1; i >= 0; i--) {
    result = rest[i] + result;
    count++;
    if (count == 2 && i != 0) {
      result = ',$result';
      count = 0;
    }
  }
  return '$result,$last3';
}

double? _minRent(Map p) {
  final roomType = p["roomType"];
  if (roomType is List && roomType.isNotEmpty) {
    final rents =
        roomType
            .map((r) => double.tryParse(r["rent"]?.toString() ?? "") ?? 0.0)
            .where((r) => r > 0)
            .toList()
          ..sort();
    if (rents.isNotEmpty) return rents.first;
  }
  if (roomType is String) {
    try {
      final parsed = jsonDecode(roomType);
      if (parsed is List && parsed.isNotEmpty) {
        final rents =
            parsed
                .map((r) => double.tryParse(r["rent"]?.toString() ?? "") ?? 0.0)
                .where((r) => r > 0)
                .toList()
              ..sort();
        if (rents.isNotEmpty) return rents.first;
      }
    } catch (_) {}
  }
  final direct = p["rent"] ?? p["expectedRent"];
  if (direct != null) return double.tryParse(direct.toString());
  return null;
}

String _priceLabel(Map p) {
  final r = _minRent(p);
  if (r == null || r <= 0) return "₹0";
  return "₹${_inr(r.toInt())}";
}

String _address(Map p) {
  final parts = [p["locality"], p["street"], p["city"]]
      .where((e) => e != null && "$e".trim().isNotEmpty)
      .map((e) => "$e".trim())
      .toList();
  return parts.isNotEmpty ? parts.join(", ") : (p["city"] ?? "");
}

String _imageUrl(String? url) {
  if (url == null || url.isEmpty) return "";
  return sanitizeImageUrl(url, _kBaseUrl) ?? "";
}

bool _hasFoodType(Map p) {
  final food = p["foodType"];
  if (food == null) return false;
  try {
    final f = food is Map ? food : jsonDecode(food.toString());
    if (f is! Map) return false;
    return (f["breakfast"] == true ||
        f["lunch"] == true ||
        f["dinner"] == true);
  } catch (_) {
    return false;
  }
}

bool _matchesCity(Map p, String selectedCity) {
  final city = (p["city"] ?? p["locality"] ?? p["area"] ?? "")
      .toString()
      .toLowerCase()
      .trim();
  final selected = selectedCity.toLowerCase().trim();
  if (selected.isEmpty || city.isEmpty) return true;
  if (city == selected) return true;
  const Map<String, List<String>> aliases = {
    "bangalore": ["bengaluru", "bangalore", "bangaluru", "blr"],
    "chennai": ["madras", "chennay"],
    "hyderabad": ["hyd", "hyderabad city", "secunderabad"],
    "coimbatore": ["coimbatore city", "kovai", "cbe"],
  };
  final al = aliases[selected] ?? [];
  if (al.contains(city)) return true;
  if (al.any((a) => city.contains(a))) return true;
  if (city.contains(selected) || selected.contains(city)) return true;
  return false;
}

List<String> _getAmenities(Map p) {
  final raw = p["pgAmenities"];
  if (raw == null) return [];
  try {
    final Map<String, dynamic> data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : jsonDecode(raw);
    return data.entries.where((e) => e.value == true).map((e) {
      switch (e.key.toLowerCase()) {
        case "wifi":
          return "WiFi";
        case "powerbackup":
          return "Power Backup";
        case "laundry":
          return "Laundry";
        case "lift":
          return "Lift";
        case "ac":
          return "AC";
        default:
          return e.key;
      }
    }).toList();
  } catch (_) {
    return [];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RentHomeScreen
// ══════════════════════════════════════════════════════════════════════════════
class RentHomeScreen extends StatefulWidget {
  const RentHomeScreen({super.key});

  @override
  State<RentHomeScreen> createState() => _RentHomeScreenState();
}

class _RentHomeScreenState extends State<RentHomeScreen> {
  // ── state ──────────────────────────────────────────────────────────────────
  List<dynamic> _allProps = [];
  bool _loading = true;
  String? _error;

  String selectedCity = "Chennai";
  final List<String> _cities = [
    "Chennai",
    "Bangalore",
    "Coimbatore",
    "Hyderabad",
  ];

  final GlobalKey _locationKey = GlobalKey();
  bool _isDropdownOpen = false;
  bool _dropdownShownOnce = false;
  bool _isHomeScreenActive = false;
  Timer? _openTimer;
  Timer? _closeTimer;

  // search
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showHistory = false;
  List<String> _history = [];

  // smart picks
  String _activeSmartPick = "Under ₹5K";

  // profile popup
  bool _showProfilePopup = false;
  bool _savingProfile = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  Future<List<dynamic>>? _recommendedFuture;
  Map<String, dynamic>? _user;

  bool get _isPremiumActive {
    final raw =
        _user?["isPremiumActive"] ??
        _user?["premium"] ??
        _user?["premiumActive"] ??
        _user?["hasPremium"] ??
        _user?["planActive"] ??
        _user?["plan"]?["active"];
    if (raw is bool) return raw;
    if (raw is String) return raw.toLowerCase() == "true";
    if (raw is num) return raw != 0;
    return false;
  }

  // ── lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _loadNotificationCount();

    _isHomeScreenActive = true;
    _fetchUser();
    _loadHistory();
    _checkProfile();
    _saveUserLocation();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _initApp();
    // });

    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && _history.isNotEmpty) {
        setState(() => _showHistory = true);
      } else if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _showHistory = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _isHomeScreenActive = false;
    super.dispose();
  }

  Future<void> _saveUserLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null) {
        print("❌ No token");
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.put(
        Uri.parse("$_kBaseUrl/user/location"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": position.latitude,
          "longitude": position.longitude,
          "city": selectedCity,
          "locality": "",
          "area": "",
        }),
      );

      print("LOCATION STATUS => ${response.statusCode}");
      print("LOCATION BODY => ${response.body}");
    } catch (e) {
      print("LOCATION ERROR => $e");
    }
  }

  // // ── init helpers ────────────────────────────────────────────────────────────
  // Future<void> _initApp() async {
  //   final ok = await _checkLocationRequired();
  //   if (!ok) return;

  //   _loadSavedCityThenFetch(); // <-- second time
  // }

  // Future<bool> _checkLocationRequired() async {
  //   bool enabled = await Geolocator.isLocationServiceEnabled();
  //   if (!enabled) {
  //     _showLocationDialog();
  //     return false;
  //   }
  //   LocationPermission perm = await Geolocator.checkPermission();
  //   if (perm == LocationPermission.denied)
  //     perm = await Geolocator.requestPermission();
  //   if (perm == LocationPermission.denied ||
  //       perm == LocationPermission.deniedForever) {
  //     _showLocationDialog();
  //     return false;
  //   }
  //   return true;
  // }

  // void _showLocationDialog() {
  //   if (!mounted) return;
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Text("Location Required"),
  //       content: const Text(
  //         "Please enable location to get the best results near you.",
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () async => Geolocator.openLocationSettings(),
  //           child: const Text("Turn ON", style: TextStyle(color: kPrimary)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ── data ────────────────────────────────────────────────────────────────────
  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString("token");

  Future<void> _fetchUser() async {
    try {
      final token = await _token();
      if (token == null) return;
      final res = await http.get(
        Uri.parse("$_kBaseUrl/user/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _user = jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint("fetchUser error: $e");
    }
  }

  Future<void> _loadSavedCityThenFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("selected_city");
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => selectedCity = saved);
    }
    await _fetchAll();
    if (mounted)
      setState(() {
        _recommendedFuture = _fetchRecommended();
      });
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse("$_kBaseUrl/property/all"),
        headers: {if (token != null) "Authorization": "Bearer $token"},
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        throw Exception(
          (jsonDecode(res.body) as Map)["message"]?.toString() ??
              "Server error",
        );
      }
      final all = jsonDecode(res.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _allProps = all;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<int?> _getUserId() async =>
      (await SharedPreferences.getInstance()).getInt("userId");

  Future<List<dynamic>> _fetchRecommended() async {
    try {
      final userId = await _getUserId();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (userId == null || token == null) return [];
      final res = await http.get(
        Uri.parse("$_kBaseUrl/property/recommend/$userId?city=$selectedCity"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    } catch (e) {
      debugPrint("fetchRecommended error: $e");
    }
    return [];
  }

  // ── filtered lists ──────────────────────────────────────────────────────────
  List<dynamic> get _pgOnly => _allProps.where((p) {
    final t = (p as Map)["propertyType"]?.toString().toLowerCase() ?? "";
    return t == "pg" || t.contains("pg");
  }).toList();

  List<dynamic> get _apartments => _allProps.where((p) {
    final t = (p as Map)["propertyType"]?.toString().toLowerCase() ?? "";
    return t.contains("apartment") ||
        t.contains("flat") ||
        t.contains("2bhk") ||
        t.contains("3bhk");
  }).toList();

  List<dynamic> get _villas => _allProps.where((p) {
    final t = (p as Map)["propertyType"]?.toString().toLowerCase() ?? "";
    return t.contains("villa") || t.contains("house") || t.contains("bungalow");
  }).toList();

  List<dynamic> get _commercial => _allProps.where((p) {
    final t = (p as Map)["propertyType"]?.toString().toLowerCase() ?? "";
    return t.contains("commercial") ||
        t.contains("office") ||
        t.contains("cowork");
  }).toList();

  List<dynamic> get _nearYou => _allProps
      .where((p) => _matchesCity(p as Map, selectedCity))
      .take(6)
      .toList();

  // ── search history ──────────────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _history = p.getStringList(_kSearchHistoryKey) ?? []);
  }

  Future<void> _saveQuery(String q) async {
    if (q.trim().isEmpty) return;
    final p = await SharedPreferences.getInstance();
    List<String> h = p.getStringList(_kSearchHistoryKey) ?? [];
    h.remove(q.trim());
    h.insert(0, q.trim());
    if (h.length > _kMaxHistory) h = h.sublist(0, _kMaxHistory);
    await p.setStringList(_kSearchHistoryKey, h);
    if (mounted) setState(() => _history = h);
  }

  Future<void> _clearHistory() async {
    await (await SharedPreferences.getInstance()).remove(_kSearchHistoryKey);
    if (mounted) setState(() => _history = []);
  }

  Future<void> _removeHistoryItem(String item) async {
    final p = await SharedPreferences.getInstance();
    List<String> h = p.getStringList(_kSearchHistoryKey) ?? [];
    h.remove(item);
    await p.setStringList(_kSearchHistoryKey, h);
    if (mounted) setState(() => _history = h);
  }

  void _performSearch(String val) {
    if (val.trim().isEmpty) return;
    _saveQuery(val.trim());
    _searchFocus.unfocus();
    _searchCtrl.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AllPropertiesScreen(queryParams: {"search": val.trim()}),
      ),
    );
  }

  // ── profile ─────────────────────────────────────────────────────────────────
  Future<void> _checkProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null || (prefs.getBool("profilePopupShown") ?? false))
        return;
      final res = await http.get(
        Uri.parse("$_kBaseUrl/user/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data["isProfileComplete"] != true) {
          _nameCtrl.text = data["name"]?.toString() ?? "";
          _emailCtrl.text = data["email"]?.toString() ?? "";
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _showProfilePopup = true);
          });
        }
      }
    } catch (_) {}
  }

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

  Future<void> _submitProfile() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || !email.contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid name & email")),
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final res = await http.put(
        Uri.parse("$_kBaseUrl/user/complete-profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"name": name, "email": email}),
      );
      if (res.statusCode == 200) {
        await prefs.setBool("profilePopupShown", true);
        if (mounted) {
          setState(() => _showProfilePopup = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Profile updated ✓")));
        }
      } else {
        throw Exception("Failed");
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error saving profile")));
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: GestureDetector(
        onTap: () => _searchFocus.unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF7F2), Colors.white],
            ),
          ),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildPostYourProperty(),
                        _buildWhyRentit(),
                        _buildRentSmart(),
                        _buildHelpSupport(),
                        _buildPremium(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Property Knowledge Hub",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 12),

                              buildKnowledgeCard(
                                icon: Icons.info_outline,
                                title: "Occupancy Certificate (OC)",
                                subtitle: "Meaning, Importance & Process",
                                iconBg: const Color(0xFFEEF0FF),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KnowledgeDetailPage(
                                      article:
                                          KnowledgeData.occupancyCertificate,
                                    ),
                                  ),
                                ),
                              ),

                              buildKnowledgeCard(
                                icon: Icons.description_outlined,
                                title: "Sale Deed Explained",
                                subtitle: "Documents, Format & Registration",
                                iconBg: const Color(0xFFFFF4EC),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KnowledgeDetailPage(
                                      article: KnowledgeData.saleDeed,
                                    ),
                                  ),
                                ),
                              ),

                              buildKnowledgeCard(
                                icon: Icons.bar_chart,
                                title:
                                    "Why Real Estate Investment Still Matters",
                                subtitle: "2026 outlook & returns",
                                iconBg: const Color(0xFFF0FFF7),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KnowledgeDetailPage(
                                      article:
                                          KnowledgeData.realEstateInvestment,
                                    ),
                                  ),
                                ),
                              ),

                              buildKnowledgeCard(
                                icon: Icons.work_outline,
                                title: "Property Tax Guide for Homeowners",
                                subtitle: "Calculations & exemptions explained",
                                iconBg: const Color(0xFFF3EEFF),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KnowledgeDetailPage(
                                      article: KnowledgeData.propertyTax,
                                    ),
                                  ),
                                ),
                              ),

                              buildKnowledgeCard(
                                icon: Icons.shield_outlined,
                                title: "RERA Registration Explained",
                                subtitle:
                                    "Rights, compliance & buyer protection",
                                iconBg: const Color(0xFFEFFFEC),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => KnowledgeDetailPage(
                                      article: KnowledgeData.reraRegistration,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // _buildGrowingBanner(),
                        SizedBox(
                          height: 24 + MediaQuery.of(context).padding.bottom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showHistory && _history.isNotEmpty) _buildHistoryOverlay(),
              if (_showProfilePopup) _buildProfilePopup(),
            ],
          ),
        ),
      ),
    );
  }

  int _notificationCount = 0;

  Widget buildKnowledgeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconBg = const Color(0xFFF3F4F6),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B2A).withOpacity(0.08),
              offset: const Offset(0, 2),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 22, color: const Color(0xFF0D1B2A)),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8899AA),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final name = _user?["name"]?.toString() ?? "User";
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Container(
      width: double.infinity,
      color: kBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP ROW: logo + actions ──────────────────────────────────
              Row(
                children: [
                  Image.asset(
                    "assets/rentit_logo.png",
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      "rentit",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: kPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Notification Bell
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );

                      _loadNotificationCount();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          CupertinoIcons.bell,
                          size: 26,
                          color: Color(0xFF1A1A1A),
                        ),

                        if (_notificationCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              height: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: const BoxDecoration(
                                color: kOrange,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _notificationCount > 99
                                      ? "99+"
                                      : _notificationCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyActivityScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      CupertinoIcons.heart,
                      size: 24,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    ),
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: const BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const SizedBox(height: 14),

              // ── SEARCH BAR ───────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(
                      initial: SearchModel(),
                      allProperties: _allProps,
                      onApply: (filter) {
                        Navigator.pushReplacementNamed(
                          context,
                          '/properties',
                          arguments: filter.toQueryParams(),
                        );
                      },
                    ),
                  ),
                ),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.search, color: Colors.grey, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Search PGs, apartments, villas...",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                      VerticalDivider(
                        color: Colors.grey,
                        thickness: 0.8,
                        width: 16,
                      ),
                      Icon(CupertinoIcons.mic, color: Colors.grey, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── CATEGORY CHIPS (4 EVENLY SPACED BOXES) ───────────────────
              Row(
                children: [
                  Expanded(
                    child: _categoryChip(
                      "Apartments",
                      "assets/apartments_icon.png",
                      fallbackIcon: CupertinoIcons.building_2_fill,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ApartmentPropertiesScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _categoryChip(
                      "PGs",
                      "assets/pg_icon.png",
                      fallbackIcon: CupertinoIcons.bed_double,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllPropertiesScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _categoryChip(
                      "Commercial",
                      "assets/commercial_icon.png",
                      fallbackIcon: CupertinoIcons.briefcase,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CommercialPropertiesScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _categoryChip(
                      "Flatmates",
                      "assets/flatmates_icon.png",
                      fallbackIcon: CupertinoIcons.person_2_fill,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FlatmateViewDetailsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(
    String label,
    String imagePath, {
    required IconData fallbackIcon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 48,
              width: 48,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7EAE4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(fallbackIcon, size: 24, color: kOrange),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  RECOMMENDED FOR YOU
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildRecommended() {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Recommended for you",
            "See all",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllPropertiesScreen()),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 340,
            child: FutureBuilder<List<dynamic>>(
              future: _recommendedFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _shimmerRow(260, 340);
                }
                final data = snap.data ?? [];
                if (data.isEmpty) return _emptyPlaceholder(340);
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) =>
                      _recommendedCard(data[i] as Map<String, dynamic>),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // FIX: replaced inner Column with fixed-height layout to stop overflow
  Widget _recommendedCard(Map<String, dynamic> p) {
    final imgs = extractPropertyImages(p, _kBaseUrl);
    final imgUrl = imgs.isNotEmpty ? imgs[0] : "";
    final price = _priceLabel(p);
    final addr = _address(p);
    final name = p["propertyName"]?.toString() ?? "Property";
    final type = p["propertyType"]?.toString() ?? "PG";
    final typeLabel = type.toUpperCase().contains("APARTMENT")
        ? "Apartment"
        : "PG";
    final amenities = _getAmenities(p);
    final extra = amenities.length > 3 ? "+${amenities.length - 3} more" : null;
    final badgeColor = typeLabel == "Apartment"
        ? const Color(0xFFE8F0FF)
        : const Color(0xFFF3E8FF);
    final badgeTextColor = typeLabel == "Apartment"
        ? const Color(0xFF2563EB)
        : const Color(0xFF9333EA);

    return GestureDetector(
      onTap: () {
        final id = int.tryParse(p["id"].toString());
        if (id != null) {
          AuthGuard.protectNavigation(
            context,
            screen: PropertyDetailScreen(propertyId: id),
          );
        }
      },
      child: Container(
        width: 276,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: imgUrl.isNotEmpty
                      ? buildPropertyImage(
                          imgUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          baseUrl: _kBaseUrl,
                          placeholder: () => _noImg(180),
                        )
                      : _noImg(180),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Consumer(
                    builder: (context, ref, _) {
                      ref.watch(likeProvider);
                      final id = int.tryParse(p["id"]?.toString() ?? '') ?? 0;
                      final type =
                          p["bhkType"] != null ||
                              p["propertyType"] == "Apartment"
                          ? "apartment"
                          : (p["propertyType"] == "Commercial"
                                ? "commercial"
                                : (p["tenantType"] != null ||
                                          p["propertyType"] == "Flatmate"
                                      ? "flatmate"
                                      : "pg"));
                      final isLiked =
                          id > 0 &&
                          ref.read(likeProvider.notifier).isLiked(id, type);
                      return GestureDetector(
                        onTap: () {
                          if (id > 0) {
                            AuthGuard.protect(
                              context,
                              onAuthenticated: () {
                                ref
                                    .read(likeProvider.notifier)
                                    .toggle(id, type);
                              },
                            );
                          }
                        },
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLiked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            color: isLiked ? Colors.red : Colors.white,
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // DETAILS — wrapped in Padding only, no nested Column that can overflow
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Price
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const TextSpan(
                          text: " /month",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_solid,
                        size: 13,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          addr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Amenity tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...amenities.take(3).map((a) => _tinyChip(a)),
                      if (extra != null)
                        _tinyChip(
                          extra,
                          color: const Color(0xFFEFF6FF),
                          textColor: const Color(0xFF3B82F6),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  NEAR YOU RIGHT NOW
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildNearYou() {
    final items = _nearYou;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Near You Right Now",
            "See all",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllPropertiesScreen()),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            "Properties within 2 km of you",
            style: TextStyle(fontSize: 12, color: kText3),
          ),
          const SizedBox(height: 14),
          if (_loading)
            _shimmerRow(140, 195)
          else if (items.isEmpty)
            _emptyPlaceholder(160)
          else
            SizedBox(
              height: 195,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _nearYouCard(items[i] as Map<String, dynamic>, i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nearYouCard(Map<String, dynamic> p, int index) {
    final imgs = extractPropertyImages(p, _kBaseUrl);
    final imgUrl = imgs.isNotEmpty ? imgs[0] : "";
    final price = _priceLabel(p);
    final name = p["propertyName"]?.toString() ?? "Property";
    final addr = _address(p);
    const dists = [
      "0.5 km away",
      "0.7 km away",
      "1.2 km away",
      "1.5 km away",
      "1.8 km away",
      "2.0 km away",
    ];
    final dist = dists[index % dists.length];

    return GestureDetector(
      onTap: () {
        final id = int.tryParse(p["id"].toString());
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(propertyId: id),
            ),
          );
        }
      },
      child: Container(
        width: 140,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: imgUrl.isNotEmpty
                      ? buildPropertyImage(
                          imgUrl,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          baseUrl: _kBaseUrl,
                          placeholder: () => _noImg(105),
                        )
                      : _noImg(105),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dist,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$price/mo",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location,
                        size: 10,
                        color: kText3,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          addr.split(",").first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: kText3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  SMART PICKS SECTION
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _filterChip(String label, {bool active = false}) {
    return GestureDetector(
      onTap: () => setState(() => _activeSmartPick = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kPrimary : kBorder, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : kText2,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  PREMIUM LIVING COLLECTION  (FIX: banner inner Column uses mainAxisSize.min)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSmartPicksSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Premium Living Collection",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              GestureDetector(
                child: const Row(
                  children: [
                    Text(
                      "View all",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E4E79),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Color(0xFF1E4E79),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          GestureDetector(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                "assets/luxury_homes.png",
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPropertyCard() {
    if (_allProps.isEmpty) return const SizedBox.shrink();
    final p = _allProps.first as Map;
    final imgs = extractPropertyImages(p, _kBaseUrl);
    final imgUrl = imgs.isNotEmpty ? imgs[0] : "";

    return GestureDetector(
      onTap: () {
        final id = int.tryParse(p["id"].toString());
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(propertyId: id),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imgUrl.isNotEmpty
                  ? buildPropertyImage(
                      imgUrl,
                      fit: BoxFit.cover,
                      baseUrl: _kBaseUrl,
                      placeholder: () => _noImg(200),
                    )
                  : _noImg(200),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.72),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 14,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "₹2,10,000 /mo",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p["propertyName"]?.toString() ?? "Prestige Altima",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 2),
                              Text(
                                "4.9",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "View →",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  FEATURED APARTMENTS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildFeaturedApartments() {
    final items = _apartments.isEmpty
        ? _allProps.take(4).toList()
        : _apartments.take(4).toList();
    return _featuredHorizontalSection(
      title: "Featured Apartments",
      subtitle: "Top-rated flats & gated communities",
      items: items,
      badgeColors: [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)],
      badgeLabels: ["2BHK", "3BHK"],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  FEATURED VILLAS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildFeaturedVillas() {
    final items = _villas.isEmpty
        ? _allProps.skip(2).take(4).toList()
        : _villas.take(4).toList();
    return _featuredHorizontalSection(
      title: "Featured Villas",
      subtitle: "Luxury independent living",
      items: items,
      badgeColors: [const Color(0xFF10B981), const Color(0xFFF59E0B)],
      badgeLabels: ["Luxury", "Premium"],
    );
  }

  Widget _featuredHorizontalSection({
    required String title,
    required String subtitle,
    required List<dynamic> items,
    required List<Color> badgeColors,
    required List<String> badgeLabels,
  }) {
    return Container(
      color: Color(0xffFFFBF8),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title,
            "See all",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllPropertiesScreen()),
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: kText3)),
          const SizedBox(height: 14),
          if (_loading)
            _shimmerRow(190, 225)
          else if (items.isEmpty)
            _emptyPlaceholder(160)
          else
            SizedBox(
              height: 225,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final p = items[i] as Map<String, dynamic>;
                  return _featuredCard(
                    p,
                    badgeLabels[i % badgeLabels.length],
                    badgeColors[i % badgeColors.length],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // FIX: card uses fixed heights / mainAxisSize.min to avoid overflow
  Widget _featuredCard(Map<String, dynamic> p, String badge, Color badgeColor) {
    final imgs = extractPropertyImages(p, _kBaseUrl);
    final imgUrl = imgs.isNotEmpty ? imgs[0] : "";
    final price = _priceLabel(p);
    final name = p["propertyName"]?.toString() ?? "Property";
    final addr = _address(p);

    return GestureDetector(
      onTap: () {
        final id = int.tryParse(p["id"].toString());
        if (id != null) {
          AuthGuard.protectNavigation(
            context,
            screen: PropertyDetailScreen(propertyId: id),
          );
        }
      },
      child: Container(
        width: 208,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: imgUrl.isNotEmpty
                      ? buildPropertyImage(
                          imgUrl,
                          height: 125,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          baseUrl: _kBaseUrl,
                          placeholder: () => _noImg(125),
                        )
                      : _noImg(125),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Consumer(
                    builder: (context, ref, _) {
                      ref.watch(likeProvider);
                      final id = int.tryParse(p["id"]?.toString() ?? '') ?? 0;
                      final type =
                          p["bhkType"] != null ||
                              p["propertyType"] == "Apartment"
                          ? "apartment"
                          : (p["propertyType"] == "Commercial"
                                ? "commercial"
                                : (p["tenantType"] != null ||
                                          p["propertyType"] == "Flatmate"
                                      ? "flatmate"
                                      : "pg"));
                      final isLiked =
                          id > 0 &&
                          ref.read(likeProvider.notifier).isLiked(id, type);
                      return GestureDetector(
                        onTap: () {
                          if (id > 0) {
                            AuthGuard.protect(
                              context,
                              onAuthenticated: () {
                                ref
                                    .read(likeProvider.notifier)
                                    .toggle(id, type);
                              },
                            );
                          }
                        },
                        child: Container(
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isLiked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            size: 14,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$price/mo",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location,
                        size: 11,
                        color: kText3,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          addr.split(",").first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: kText3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  COMMERCIAL HUBS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildCommercialHubs() {
    final items = _commercial.isEmpty
        ? _allProps.skip(1).take(4).toList()
        : _commercial.take(4).toList();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Commercial Hubs",
            "See all",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommercialPropertiesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            "Offices, coworking & retail spaces",
            style: TextStyle(fontSize: 12, color: kText3),
          ),
          const SizedBox(height: 14),
          if (_loading)
            _shimmerRow(190, 225)
          else if (items.isEmpty)
            _emptyPlaceholder(150)
          else
            SizedBox(
              height: 225,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final p = items[i] as Map<String, dynamic>;
                  const labels = ["Coworking", "Private", "Retail", "Office"];
                  const colors = [
                    Color(0xFF3B82F6),
                    Color(0xFF8B5CF6),
                    Color(0xFF10B981),
                    Color(0xFFF97316),
                  ];
                  return _featuredCard(
                    p,
                    labels[i % labels.length],
                    colors[i % colors.length],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  RENT SMART BANNER
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildRentSmartBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1B2B3A),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "RENT SMART,\n",
                            style: TextStyle(
                              color: kOrange,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                            text: "LIVE BETTER!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Find the best PGs near you at the best prices.",
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllPropertiesScreen(
                              queryParams: {"propertyType": "house"},
                            ),
                          ),
                        );
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Explore Now",
                          style: TextStyle(
                            color: Color(0xFF1B2B3A),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                width: 100,
                color: const Color(0xFF263B4D),
                child: const Icon(
                  CupertinoIcons.house_fill,
                  size: 56,
                  color: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  WHY RENTIT
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildWhyRentit() {
    final items = [
      {
        "title": "Verified",
        "subtitle": "100% verified\nlistings",
        "icon": CupertinoIcons.shield_lefthalf_fill,
        "color": const Color(0xFFE3F2FD),
        "ic": const Color(0xFF1565C0),
      },
      {
        "title": "No Brokerage",
        "subtitle": "Zero hidden\ncharges",
        "icon": CupertinoIcons.money_dollar_circle,
        "color": const Color(0xFFFFF3E0),
        "ic": const Color(0xFFEF6C00),
      },
      {
        "title": "Direct Contact",
        "subtitle": "Connect directly\nwith owner",
        "icon": CupertinoIcons.phone,
        "color": const Color(0xFFF3E5F5),
        "ic": const Color(0xFF8E24AA),
      },
      {
        "title": "Easy Booking",
        "subtitle": "Hassle free\nexperience",
        "icon": CupertinoIcons.doc_text,
        "color": const Color(0xFFE8F5E9),
        "ic": const Color(0xFF2E7D32),
      },
    ];

    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Why Rentit?",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: item["color"] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item["icon"] as IconData,
                            color: item["ic"] as Color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item["title"] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item["subtitle"] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: kText3,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  SMART PICKS FILTER (icon row)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSmartPicksFilter() {
    final picks = [
      {
        "label": "Under ₹5K",
        "icon": CupertinoIcons.tag_fill,
        "color": const Color(0xFFFEECDC),
        "ic": const Color(0xFFF97316),
      },
      {
        "label": "Popular PGs",
        "icon": CupertinoIcons.flame_fill,
        "color": const Color(0xFFFFE4E4),
        "ic": const Color(0xFFEF4444),
      },
      {
        "label": "Newly Added",
        "icon": CupertinoIcons.sparkles,
        "color": const Color(0xFFDCFCE7),
        "ic": const Color(0xFF16A34A),
      },
      {
        "label": "Food",
        "icon": CupertinoIcons.location_fill,
        "color": const Color(0xFFE0F2FE),
        "ic": const Color(0xFF0284C7),
      },
      {
        "label": "Top Rated",
        "icon": CupertinoIcons.star_fill,
        "color": const Color(0xFFFEF9C3),
        "ic": const Color(0xFFCA8A04),
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Smart Picks",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Handpicked PGs for you",
                  style: TextStyle(fontSize: 12, color: kText3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final item = picks[i];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: item["color"] as Color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item["icon"] as IconData,
                        color: item["ic"] as Color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item["label"] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kText2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUDGET FRIENDLY PICKS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildBudgetFriendlyPicks() {
    final budgets = [
      {"label": "Under ₹5K", "range": "0-5000", "image": "assets/bud1.png"},
      {
        "label": "₹5K – ₹10K",
        "range": "5000-10000",
        "image": "assets/bud22.png",
      },
      {"label": "Pet Friendly", "range": "0-99999", "image": "assets/bud3.png"},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip("Under ₹5K", active: true),
                  _filterChip("₹5K – ₹10K"),
                  _filterChip("Pet Friendly"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: budgets.length,
              itemBuilder: (_, i) {
                final b = budgets[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllPropertiesScreen(
                        queryParams: {
                          "budget": b["range"]!,
                          "city": selectedCity,
                        },
                      ),
                    ),
                  ),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: AssetImage(b["image"]!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.08),
                                Colors.black.withOpacity(0.55),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                b["label"]!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    "4.5 (128)",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "2.4 km",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  AMENITIES-BASED DISCOVERY
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildAmenitiesDiscovery() {
    final amenities = [
      {"label": "AC", "icon": CupertinoIcons.wind, "query": "AC"},
      {
        "label": "Infinity Pool",
        "icon": CupertinoIcons.drop_fill,
        "query": "pool",
      },
      {"label": "WiFi", "icon": CupertinoIcons.wifi, "query": "WiFi"},
      {
        "label": "Attached Bath",
        "icon": CupertinoIcons.drop,
        "query": "bathroom",
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Text(
              "Amenities-Based Discovery",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: amenities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final a = amenities[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllPropertiesScreen(
                        queryParams: {
                          "amenity": a["query"]! as String,
                          "city": selectedCity,
                        },
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: kBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          a["icon"] as IconData,
                          size: 22,
                          color: const Color(0xFF6366F1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a["label"]! as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: kText2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentSmart() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              "assets/BANNER109.png",
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Content Overlay
          Positioned(
            left: 16,
            top: 20,
            bottom: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      children: [
                        TextSpan(
                          text: "RENT ",
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: "SMART,\n",
                          style: TextStyle(color: Color(0xFFFFA726)),
                        ),
                        TextSpan(
                          text: "LIVE BETTER!",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Find the best PGs\nnear you at the\nbest prices.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const AllPropertiesScreen(
                              queryParams: {"propertyType": "house"},
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF183B63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Explore Now",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  POPULAR LOCALITIES
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildPopularLocalities() {
    final localities = [
      {
        "name": "OMR",
        "count": "99 Properties",
        "image": "assets/chennaiimage.png",
      },
      {
        "name": "Velechery",
        "count": "86 Properties",
        "image": "assets/bangalorecity.png",
      },
      {
        "name": "Taramani",
        "count": "81 Properties",
        "image": "assets/coimimage.png",
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Popular Localities",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(localities.length, (i) {
              final loc = localities[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllPropertiesScreen(
                        queryParams: {
                          "locality": loc["name"]!,
                          "city": selectedCity,
                        },
                      ),
                    ),
                  ),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: i < localities.length - 1 ? 10 : 0,
                    ),
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      image: DecorationImage(
                        image: AssetImage(loc["image"]!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.12),
                                Colors.black.withOpacity(0.60),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.location_solid,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      loc["name"]!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Near IT corridor",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9,
                                ),
                              ),
                              Text(
                                loc["count"]!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPostYourProperty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostPropertyScreen()),
                );
              },
              child: Image.asset(
                "assets/Post_YourProperty_Card.png",
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned(
            left: 10,
            bottom: 20,
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PostPropertyScreen(),
                    ),
                  );
                },

                icon: const Icon(Icons.add, color: Colors.white, size: 18),

                label: const Text(
                  "Post Property Now",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF183654),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  PREMIUM UNLOCK
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildPremiumUnlock() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(initialIndex: 3),
          ),
          (route) => false,
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B2B3A), Color(0xFF2F4352)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "PREMIUM ACCESS",
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Unlock Premium Listings\n& Early Access",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Access verified premium PGs,\npriority owner contact & exclusive deals.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Explore Premium",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.arrow_up_right,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.building_2_fill,
                size: 40,
                color: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremium() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F6145), Color(0xFF1B2B3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🏠', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        const Text(
                          'BUYER PLAN',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Premium Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBuyerFeatureRow('Unlimited property shortlisting'),
                const SizedBox(height: 10),
                _buildBuyerFeatureRow('Priority owner connect'),
                const SizedBox(height: 10),
                _buildBuyerFeatureRow('Zero brokerage guarantee'),
                const SizedBox(height: 24),
                const Text(
                  'Premium Membership Active',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BuyerPlansScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(
                    0xFFB4831B,
                  ), // gold color matching the text
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Manage Plan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerFeatureRow(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.checkmark_alt,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  SMART RECOMMENDATIONS FOR YOU
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSmartRecommendations() {
    final cards = [
      {
        "title": "Because you searched",
        "highlight": "OMR",
        "sub": "46 Apartments found",
        "icon": CupertinoIcons.search,
        "bg": const Color(0xFFF0F9FF),
      },
      {
        "title": "Similar to viewed",
        "highlight": "PGs",
        "sub": "36 PGs found",
        "icon": CupertinoIcons.eye,
        "bg": const Color(0xFFF0FDF4),
      },
      {
        "title": "Based on budget",
        "highlight": "Under ₹10K",
        "sub": "62 Options",
        "icon": CupertinoIcons.money_dollar,
        "bg": const Color(0xFFFFFBEB),
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "Smart Recommendations",
            "See all",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllPropertiesScreen()),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final c = cards[i];
                return Container(
                  width: 155,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: c["bg"] as Color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c["icon"] as IconData,
                        size: 18,
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c["title"] as String,
                        style: const TextStyle(fontSize: 10, color: kText3),
                      ),
                      Text(
                        c["highlight"] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c["sub"] as String,
                        style: const TextStyle(fontSize: 10, color: kText3),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  WISHLIST (SAVED)  —  FIX: changed SizedBox height to 210 for consistent fit
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildWishlist() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Consumer(
        builder: (context, ref, _) {
          final likesAsync = ref.watch(likeProvider);

          return likesAsync.when(
            loading: () => _shimmerRow(160, 210),
            error: (_, __) => _emptyPlaceholder(150),
            data: (items) {
              if (items.isEmpty) {
                return _emptyPlaceholder(150);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Wishlist (Saved)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MainNavigationScreen(initialIndex: 3),
                              ),
                              (route) => false,
                            );
                          },
                          child: const Row(
                            children: [
                              Text(
                                "See all",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 198,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) {
                        final item = items[i] as Map<String, dynamic>;
                        final property =
                            item['apartment'] ??
                            item['Apartment'] ??
                            item['commercial'] ??
                            item['Commercial'] ??
                            item['flatmate'] ??
                            item['Flatmate'] ??
                            item['property'] ??
                            item['pg'] ??
                            item;

                        final imgs = extractPropertyImages(property, _kBaseUrl);
                        final imgUrl = imgs.isNotEmpty ? imgs.first : "";

                        final id =
                            int.tryParse(property["id"]?.toString() ?? '') ??
                            int.tryParse(
                              item["apartmentId"]?.toString() ?? '',
                            ) ??
                            int.tryParse(
                              item["commercialId"]?.toString() ?? '',
                            ) ??
                            int.tryParse(
                              item["flatmateId"]?.toString() ?? '',
                            ) ??
                            int.tryParse(
                              item["propertyId"]?.toString() ?? '',
                            ) ??
                            0;

                        final name =
                            property["propertyName"]?.toString() ??
                            property["bhkType"]?.toString() ??
                            "Property";

                        final price =
                            property["expectedRent"]?.toString() ?? "0";

                        final locality =
                            property["locality"]?.toString() ??
                            property["location"]?.toString() ??
                            "";

                        final isApartment =
                            item['apartment'] != null ||
                            item['Apartment'] != null ||
                            item['apartmentId'] != null ||
                            property['bhkType'] != null;
                        final isCommercial =
                            item['commercial'] != null ||
                            item['Commercial'] != null ||
                            item['commercialId'] != null;
                        final isFlatmate =
                            item['flatmate'] != null ||
                            item['Flatmate'] != null ||
                            item['flatmateId'] != null;

                        return GestureDetector(
                          onTap: () {
                            if (id > 0) {
                              if (isCommercial) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CommercialPropertyDetailScreen(
                                          propertyId: id,
                                        ),
                                  ),
                                );
                              } else if (isFlatmate) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FlatmateDetailScreen(propertyId: id),
                                  ),
                                );
                              } else if (isApartment) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ApartmentPropertyDetailScreen(
                                          propertyId: id,
                                        ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PropertyDetailScreen(propertyId: id),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: 168,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E5E5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Image + Heart ──────────────────────────
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: imgUrl.isNotEmpty
                                          ? buildPropertyImage(
                                              imgUrl,
                                              height: 110,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              baseUrl: _kBaseUrl,
                                              placeholder: () => Container(
                                                height: 110,
                                                width: double.infinity,
                                                color: Colors.grey.shade200,
                                                child: const Icon(
                                                  Icons.home_outlined,
                                                  size: 48,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              height: 110,
                                              width: double.infinity,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.home_outlined,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),

                                    // Heart badge
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (id > 0) {
                                            final type = isCommercial
                                                ? 'commercial'
                                                : (isFlatmate
                                                      ? 'flatmate'
                                                      : (isApartment
                                                            ? 'apartment'
                                                            : 'pg'));
                                            ref
                                                .read(likeProvider.notifier)
                                                .toggle(id, type);
                                          }
                                        },
                                        child: Container(
                                          height: 36,
                                          width: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.35,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.heart_fill,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // ── Info ───────────────────────────────────
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Property name
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Price
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "₹$price",
                                              style: const TextStyle(
                                                color: Color(0xFF111827),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: " /month",
                                              style: TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // Location
                                      Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons.location_solid,
                                            size: 13,
                                            color: Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              locality,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  TRENDING SEARCHES
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildTrendingSearches() {
    const tags = [
      "PGs near IT parks",
      "Apartment near Beach",
      "Cheap villas OMR",
      "PG under ₹7K",
      "Apartments",
      "Villas in ECR",
      "PG near Tidel Park",
      "Sea-facing homes",
      "Family Apartments",
    ];

    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trending Searches",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1C),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => GestureDetector(
                    onTap: () => _performSearch(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 12, color: kText2),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  HELP & SUPPORT
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildHelpSupport() {
    final items = [
      {
        "label": "Talk to Expert",
        "icon": CupertinoIcons.person,
        "color": Color(0xFFD1FAF0), // green
        "ic": Color(0xFF1FAF8B),
      },
      {
        "label": "Call Support",
        "icon": CupertinoIcons.phone,
        "color": Color(0xFFDBEAFE), // blue
        "ic": Color(0xFF2563EB),
      },
      {
        "label": "FAQs",
        "icon": CupertinoIcons.question_circle,
        "color": Color(0xFFEDE9FE), // purple
        "ic": Color(0xFF7C3AED),
      },
    ];

    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Help & Support",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kText,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: items.map((item) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    switch (item["label"]) {
                      case "Talk to Expert":
                        showTalkToExpertSheet(context);
                        break;

                      case "Call Support":
                        showCallSupportSheet(context);
                        break;

                      case "FAQs":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpAndSupportScreen(),
                          ),
                        );
                        break;
                    }
                  },
                  child: Container(
                    height: 120,
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
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: item["color"] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item["icon"] as IconData,
                            size: 26,
                            color: item["ic"] as Color,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item["label"] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
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
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  WE ARE GROWING BANNER
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildGrowingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "We are growing!",
                    style: TextStyle(
                      color: Color(0xff2F4253),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  "Now in Bangalore",
                  style: TextStyle(
                    color: Color(0xff2F4253),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "More cities coming soon",
                  style: TextStyle(color: Color(0xff2F4253), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AllPropertiesScreen(
                  queryParams: {"city": "Bangalore"},
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Color(0xff2F4253),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Explore Bangalore",
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  HISTORY OVERLAY
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryOverlay() {
    final top = MediaQuery.of(context).padding.top + 52.0;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Searches",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: _clearHistory,
                    child: const Text(
                      "Clear all",
                      style: TextStyle(
                        color: kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final item = _history[i];
                return InkWell(
                  onTap: () => _performSearch(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: kText3),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeHistoryItem(item),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: kText3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  PROFILE POPUP
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildProfilePopup() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Complete Your Profile",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: "Your name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: "Your email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _savingProfile ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _savingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Submit",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showProfilePopup = false),
                  child: const Text(
                    "Skip for now",
                    style: TextStyle(color: kText3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: kText,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                action,
                style: const TextStyle(
                  color: Color(0xFF1F4C73),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tinyChip(String text, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: textColor ?? kText2),
      ),
    );
  }

  Widget _noImg(double h) => Container(
    height: h,
    width: double.infinity,
    color: kPrimaryLight,
    child: const Center(
      child: Icon(Icons.apartment_outlined, size: 32, color: kPrimary),
    ),
  );

  Widget _shimmerRow(double w, double h) {
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0F3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _emptyPlaceholder(double h) => Container(
    height: h,
    width: double.infinity,
    decoration: BoxDecoration(
      color: kPrimaryLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.apartment_outlined, size: 32, color: kPrimary),
        SizedBox(height: 8),
        Text(
          "No properties found",
          style: TextStyle(color: kText3, fontSize: 12),
        ),
      ],
    ),
  );
}
