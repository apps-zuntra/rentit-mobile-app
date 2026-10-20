// account_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/feature/auth/auth_wrapper.dart';
import 'package:rentit/main/Help&Support.dart';
import 'package:rentit/main/Terms&Conditions.dart';
import 'package:rentit/main/buyer_plans.dart';
import 'package:rentit/notification/notifications_screen.dart';
import 'package:rentit/screen/location_service.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBaseUrl = "https://rentit-backend-omega.vercel.app";

// ─────────────────────────────────────────────
// COLOURS
// ─────────────────────────────────────────────
class _C {
  static const scaffold = Color(0xFFF2F3F5);
  static const headerBg = Color(0xFF1B2B3A);
  static const cardBg = Colors.white;
  static const primaryText = Color(0xFF1A1A1A);
  static const subText = Color(0xFF6B7280);
  static const divider = Color(0xFFE5E7EB);

  static const planGreen = Color(0xFF1E7C5A);
  static const planGreenDk = Color(0xFF165C43);

  static const premiumBg = Color(0xFFF59E0B);

  static const heartRed = Color(0xFFEF4444);
  static const calBlue = Color(0xFF00998A);
  static const chatPurple = Color(0xFF8B5CF6);
  static const statBg = Color(0xFFFFF7F7);
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? user;
  bool isLoading = true;
  bool showLogoutSheet = false; // ← overlay toggle

  String _location = "Chennai , Tamil Nadu";
  String _language = "English";

  int chatCount = 0;
  int savedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    fetchUser();
    fetchChatCount();
    fetchSavedCount();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLoc = prefs.getString("user_location");
      final savedLang = prefs.getString("app_language");
      if (mounted) {
        setState(() {
          if (savedLoc != null && savedLoc.trim().isNotEmpty) {
            _location = savedLoc;
          }
          if (savedLang != null && savedLang.trim().isNotEmpty) {
            _language = savedLang;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> fetchSavedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId =
          prefs.getInt("userId") ??
          int.tryParse(prefs.getString("userId") ?? "");

      if (userId == null) return;

      final res = await http.get(Uri.parse("$kBaseUrl/likes/user/$userId"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;

        if (mounted) {
          setState(() {
            savedCount = data.length;
          });
        }
      }
    } catch (e) {
      debugPrint("Saved Count Error => $e");
    }
  }

  Future<void> fetchChatCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId");

      if (userId == null) return;

      final res = await http.get(
        Uri.parse(
          "https://rentit-backend-omega.vercel.app/chat/list?userId=$userId",
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;

        debugPrint("CHAT COUNT => ${data.length}");

        if (mounted) {
          setState(() {
            chatCount = data.length;
          });
        }
      }
    } catch (e) {
      debugPrint("Chat Count Error: $e");
    }
  }

  // ── fetch user ──────────────────────────────
  Future<void> fetchUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      if (token == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final res = await http.get(
        Uri.parse("$kBaseUrl/user/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        user = data;
        final loc = data?["location"] ?? data?["city"];
        if (loc != null && loc.toString().trim().isNotEmpty) {
          _location = loc.toString();
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching user: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── location picker ────────────────────────
  Future<void> _showLocationPicker() async {
    final searchCtrl = TextEditingController();
    final allCities = [
      "Chennai , Tamil Nadu",
      "Bengaluru , Karnataka",
      "Hyderabad , Telangana",
      "Mumbai , Maharashtra",
      "Delhi NCR",
      "Coimbatore , Tamil Nadu",
      "Madurai , Tamil Nadu",
      "Pune , Maharashtra",
      "Kochi , Kerala",
      "Tiruchirappalli , Tamil Nadu",
      "Salem , Tamil Nadu",
      "Mysuru , Karnataka",
      "Visakhapatnam , Andhra Pradesh",
      "Kolkata , West Bengal",
      "Ahmedabad , Gujarat",
    ];
    var filteredCities = List<String>.from(allCities);
    bool isLocating = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Select Location",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (val) {
                          setModalState(() {
                            if (val.trim().isEmpty) {
                              filteredCities = List.from(allCities);
                            } else {
                              filteredCities = allCities
                                  .where(
                                    (c) => c.toLowerCase().contains(
                                      val.toLowerCase().trim(),
                                    ),
                                  )
                                  .toList();
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: "Search city or area...",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Use Current Location
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLocating
                            ? null
                            : () async {
                                setModalState(() => isLocating = true);
                                try {
                                  final locData =
                                      await LocationService.getLocation();
                                  final city =
                                      locData["city"]?.toString() ??
                                      locData["locality"]?.toString() ??
                                      "Chennai";
                                  final formatted = "$city , Tamil Nadu";
                                  await _updateLocation(formatted);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Could not fetch GPS location: $e",
                                      ),
                                    ),
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => isLocating = false);
                                  }
                                }
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                                child: isLocating
                                    ? const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Use Current Location",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                    Text(
                                      "Using GPS location",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF8B5CF6),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  // City List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: filteredCities.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (context, i) {
                        final city = filteredCities[i];
                        final isSelected =
                            _location.toLowerCase().trim() ==
                                city.toLowerCase().trim() ||
                            _location.toLowerCase().contains(
                              city.split(',')[0].toLowerCase().trim(),
                            );
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: isSelected
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF9CA3AF),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            city,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF8B5CF6),
                                  size: 22,
                                )
                              : null,
                          onTap: () async {
                            await _updateLocation(city);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateLocation(String newLoc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_location", newLoc);
    final cityName = newLoc.split(',')[0].trim();
    await prefs.setString("user_city", cityName);
    if (mounted) {
      setState(() {
        _location = newLoc;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Location set to $newLoc"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── language picker ────────────────────────
  Future<void> _showLanguagePicker() async {
    final languages = [
      {"name": "English", "native": "English"},
      {"name": "Tamil", "native": "தமிழ்"},
      {"name": "Hindi", "native": "हिन्दी"},
      {"name": "Telugu", "native": "తెలుగు"},
      {"name": "Kannada", "native": "ಕನ್ನಡ"},
      {"name": "Malayalam", "native": "മലയാളം"},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Choose Language",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: languages.map((lang) {
                        final isSelected = _language == lang["name"];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.language_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            lang["native"]!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          subtitle: Text(
                            lang["name"]!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF10B981),
                                  size: 22,
                                )
                              : null,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              "app_language",
                              lang["name"]!,
                            );
                            if (mounted) {
                              setState(() {
                                _language = lang["name"]!;
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── logout ─────────────────────────────────
  Future<void> _confirmLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  // ── back ───────────────────────────────────
  void _handleBack() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  void _showLogoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // icon
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF1F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 42,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Sign Out?",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Are you sure you want to sign out ?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Your saved searches and wishlist will be preserved.",
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Sign out button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmLogout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: const Text(
                        "Yes, Sign Out",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.scaffold,
      body: Stack(
        children: [
          // ── Main content ──────────────────────
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDarkHeader(),
                        const SizedBox(height: 16),
                        _buildPlanCard(),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 20),

                        // Plans & Benefits
                        _buildSection(
                          label: "PLANS & BENEFITS",
                          tiles: [
                            _TileData(
                              icon: Icons.hexagon_outlined,
                              iconColor: const Color(0xFFE8A020),
                              iconBg: const Color(0xFFFFF4E0),
                              title: "Premium Plans",
                              subtitle: "Upgrade to access exclusive benefits",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BuyerPlansScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Account
                        _buildSection(
                          label: "ACCOUNT",
                          tiles: [
                            _TileData(
                              icon: Icons.person_outline_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              iconBg: const Color(0xFFEFF6FF),
                              title: "Notifications",
                              subtitle: "Manage your alerts and updates",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                            _TileData(
                              icon: Icons.language_rounded,
                              iconColor: const Color(0xFF10B981),
                              iconBg: const Color(0xFFECFDF5),
                              title: "Language",
                              subtitle: _language.isNotEmpty
                                  ? _language
                                  : "English",
                              onTap: _showLanguagePicker,
                            ),
                            _TileData(
                              icon: Icons.location_on_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              iconBg: const Color(0xFFF5F3FF),
                              title: "Location",
                              subtitle: _location,
                              onTap: _showLocationPicker,
                              showDivider: false,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Support & Legal
                        _buildSection(
                          label: "SUPPORT & LEGAL",
                          tiles: [
                            _TileData(
                              icon: Icons.help_outline_rounded,
                              iconColor: const Color(0xFF2196F3),
                              iconBg: const Color(0xFFE3F2FD),
                              title: "Help & Support",
                              subtitle: "Get answers to your questions",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HelpAndSupportScreen(),
                                ),
                              ),
                            ),
                            _TileData(
                              icon: Icons.description_outlined,
                              iconColor: const Color(0xFF0A7C66),
                              iconBg: const Color(0xFFE6F3EF),
                              title: "Terms & Conditions",
                              subtitle:
                                  "Read this to stay informed and protected",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TermsAndConditionsScreen(),
                                ),
                              ),
                              showDivider: false,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        _buildSignOutTile(),
                        const SizedBox(height: 32),
                        _buildFooter(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

          // ── Logout Overlay ────────────────────
          if (showLogoutSheet)
            GestureDetector(
              onTap: () => setState(() => showLogoutSheet = false),
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // prevent tap-through
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon circle
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF1F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.logout,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "Sign Out?",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Are you sure you want to sign out ?",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),

                          const SizedBox(height: 20),

                          // Warning box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7EC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Your saved searches and wishlist will be preserved.",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Yes Sign Out button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _confirmLogout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                "Yes, Sign Out",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Cancel button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () =>
                                  setState(() => showLogoutSheet = false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF2F2F2),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
  // DARK HEADER
  // ─────────────────────────────────────────────
  Widget _buildDarkHeader() {
    final name = user?["name"] ?? "Arjun Kumar";
    final location = _location;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : initial;

    return Container(
      color: _C.headerBg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: const Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "My Profile",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C7A5C),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _C.premiumBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                "Premium",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Member since Jan 2025",
                          style: TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // GREEN PLAN CARD
  // ─────────────────────────────────────────────
  Widget _buildPlanCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.planGreen, _C.planGreenDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              const Text(
                "BUYER PLAN",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: const Text(
                  "ACTIVE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Text(
            "Premium Plan",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          ...[
            "Unlimited property shortlisting",
            "Priority owner connect",
            "Zero brokerage guarantee",
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  "Valid till 24 Feb 2026",
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BuyerPlansScreen(),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Manage Plan",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.planGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STATS ROW
  // ─────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      _StatData(
        icon: Icons.favorite_border,
        iconColor: _C.heartRed,
        iconBg: const Color(0xFFFFEEEE),
        count: savedCount.toString(),
        label: "Saved",
      ),
      _StatData(
        icon: Icons.calendar_today_outlined,
        iconColor: _C.calBlue,
        iconBg: const Color(0xFFEFF6FF),
        count: user?["visitCount"]?.toString() ?? "3",
        label: "Visits",
      ),
      _StatData(
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: _C.chatPurple,
        iconBg: const Color(0xFFF5F3FF),
        count: chatCount.toString(),
        label: "Chats",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: stats
            .map(
              (s) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (s.label == "Chats") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const MainNavigationScreen(initialIndex: 1),
                        ),
                      );
                    } else if (s.label == "Visits") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNavigationScreen(
                            initialIndex: 2,
                            activityTabIndex: 1,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNavigationScreen(
                            initialIndex: 2,
                            activityTabIndex: 0,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: s == stats.last ? 0 : 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: s.iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 18, color: s.iconColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.count,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _C.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _C.subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SECTION
  // ─────────────────────────────────────────────
  Widget _buildSection({
    required String label,
    required List<_TileData> tiles,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: tiles.asMap().entries.map((entry) {
              final index = entry.key;
              final tile = entry.value;
              final isLast = index == tiles.length - 1;
              return Column(
                children: [
                  _buildTile(tile),
                  if (!isLast && (tile.showDivider ?? true))
                    const Divider(height: 1, indent: 68, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(_TileData tile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tile.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tile.icon, color: tile.iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _C.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFD1D5DB),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SIGN OUT TILE
  // ─────────────────────────────────────────────
  Widget _buildSignOutTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _showLogoutSheet,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "Sign Out",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FOOTER
  // ─────────────────────────────────────────────
  Widget _buildFooter() {
    return const Center(
      child: Text(
        "Rentit v2.4.0 · Made in Chennai",
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPER DATA CLASSES
// ─────────────────────────────────────────────

class _TileData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool? showDivider;

  const _TileData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider,
  });
}

class _StatData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String count;
  final String label;

  const _StatData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.count,
    required this.label,
  });
}
