// enquiries.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rentit/feature/visit/VisitProvider.dart';
import 'package:rentit/main/chatscreen.dart';

// --- Avatar colour palette (cycles through by index) ------------------------
const List<Color> _kAvatarBg = [
  Color(0xFFD6E8F7), // light blue
  Color(0xFFDDD6F7), // light purple
  Color(0xFFD6F0E8), // light green
  Color(0xFFF7E8D6), // light peach
  Color(0xFFF7D6E8), // light pink
];

const List<Color> _kAvatarFg = [
  Color(0xFF3A6EA5),
  Color(0xFF6A50A7),
  Color(0xFF2E8B6A),
  Color(0xFFA5703A),
  Color(0xFFA53A6E),
];

Color _avatarBg(int index) => _kAvatarBg[index % _kAvatarBg.length];
Color _avatarFg(int index) => _kAvatarFg[index % _kAvatarFg.length];

// --- Main Screen -------------------------------------------------------------
class EnquiriesScreen extends ConsumerStatefulWidget {
  const EnquiriesScreen({super.key});

  @override
  ConsumerState<EnquiriesScreen> createState() => _EnquiriesScreenState();
}

class _EnquiriesScreenState extends ConsumerState<EnquiriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> chats = [];
  bool chatLoading = true;
  int? userId;

  final String baseUrl = "https://rentit-backend-yti9.onrender.com";
  final Map<String, String> headers = {"Content-Type": "application/json"};

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initChats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // -- Data -------------------------------------------------------------------
  Future<void> _initChats() async {
    final id = await _getUserId();
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }
    userId = id;
    await _fetchChatList();
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final intId = prefs.getInt("userId");
    if (intId != null) return intId;
    final strId = prefs.getString("userId");
    if (strId != null) return int.tryParse(strId);
    return null;
  }

  Future<void> _fetchChatList() async {
    try {
      setState(() => chatLoading = true);
      final res = await http.get(
        Uri.parse("$baseUrl/chat/list?userId=$userId"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          chats = List<Map<String, dynamic>>.from(data);
          chatLoading = false;
        });
      } else {
        throw Exception("Server error");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => chatLoading = false);
      debugPrint("? Chat fetch error: $e");
    }
  }

  // -- Helpers ----------------------------------------------------------------
  String _formatChatTime(String? time) {
    if (time == null) return "";
    try {
      final dt = DateTime.parse(time).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.isNegative) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
      if (diff.inHours < 24) {
        return "${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago";
      }
      return "Yesterday";
    } catch (_) {
      return "";
    }
  }

  int _getOtherUserId(Map chat) =>
      chat["senderId"] == userId ? chat["receiverId"] : chat["senderId"];

  Future<void> _call(String number) async {
    final Uri uri = Uri.parse("tel:$number");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch phone app")),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "confirmed":
        return const Color(0xFF22C55E);
      case "cancelled":
        return Colors.red;
      case "completed":
        return Colors.grey;
      default:
        return const Color(0xFF22C55E);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : "?";
  }

  void _handleBack() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              const PgOwnerNavigationScreen(initialIndex: 1),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  // -- Tab builder (pill style) -----------------------------------------------
  Widget _buildTab(String title, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2F4156),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -- Build ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final visitState = ref.watch(ownerVisitProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      // -- AppBar --------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 0, // We build the header inside the body
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Header ----------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Enquiries",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F4156),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Manage your leads and visits",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -- Pill Tab Bar -----------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E6EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2F4156).withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF2F4156),
                unselectedLabelColor: const Color(0xFF9CA3AF),
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(3),
                tabs: [
                  _buildTab("Contacted", chats.length),
                  _buildTab(
                    "Scheduled",
                    visitState.maybeWhen(
                      data: (v) => v.length,
                      orElse: () => 0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // -- Tab Content ------------------------------------------------------
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildContactedTab(), _buildScheduledTab(visitState)],
            ),
          ),
        ],
      ),
    );
  }

  // -- Contacted Tab ----------------------------------------------------------
  Widget _buildContactedTab() {
    if (chatLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2F4156)),
      );
    }

    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 52,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              "No chats yet",
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final activeCount = chats.where((c) => (c["unreadCount"] ?? 0) > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              "$activeCount active conversation${activeCount > 1 ? 's' : ''}",
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchChatList,
            color: const Color(0xFF2F4156),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              itemCount: chats.length,
              itemBuilder: (_, i) {
                final chat = chats[i];
                final otherUserId = _getOtherUserId(chat);
                final message = chat["message"] ?? "";
                final timeStr = _formatChatTime(chat["createdAt"]);
                final name = chat["otherUserName"] ?? "User";
                final propertyName = chat["propertyName"] ?? "";
                final area = chat["area"] ?? "";
                final unread = chat["unreadCount"] ?? 0;
                final initials = _initials(name);

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        propertyId: chat["propertyId"],
                        ownerId: otherUserId,
                        ownerName: name,
                      ),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF2F4156).withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar with online dot
                        _buildAvatar(initials, i),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF2F4156),
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      message,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  if (unread > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2F4156),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "$unread",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (propertyName.isNotEmpty)
                                Text(
                                  area.isNotEmpty
                                      ? "$propertyName � $area"
                                      : propertyName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
        ),
      ],
    );
  }

  // -- Scheduled Tab ----------------------------------------------------------
  Widget _buildScheduledTab(AsyncValue<List<dynamic>> visitState) {
    return visitState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2F4156)),
      ),
      error: (e, _) => Center(
        child: Text("Error: $e", style: const TextStyle(color: Colors.red)),
      ),
      data: (visits) {
        if (visits.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 52,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                const Text(
                  "No scheduled visits",
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: visits.length,
          itemBuilder: (_, i) {
            final visit = visits[i] as Map<String, dynamic>;
            final property = (visit["property"] ?? {}) as Map<String, dynamic>;
            final user = (visit["user"] ?? {}) as Map<String, dynamic>;

            final propertyName =
                property["propertyName"]?.toString() ?? "Property";
            final mobile = property["mobileNo"]?.toString();
            final userName = user["name"]?.toString() ?? "User";
            final ownerId = property["userId"] ?? 0;

            // Parse visit date/time
            DateTime? dt;
            final rawDate = visit["visitDateTime"];
            if (rawDate != null) {
              dt = DateTime.tryParse(rawDate.toString())?.toLocal();
            }
            if (dt == null && visit["date"] != null && visit["time"] != null) {
              dt = DateTime.tryParse("${visit["date"]} ${visit["time"]}");
            }

            final dateStr = dt != null
                ? DateFormat("EEE, dd MMM").format(dt)
                : "-";
            final timeStr = dt != null ? DateFormat("h:mm a").format(dt) : "-";

            final status = (visit["status"] ?? "pending").toString();
            final isScheduled = status == "pending" || status == "confirmed";

            final initials = _initials(userName);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Row 1: Avatar + Name + Status badge ------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with green online dot
                        _buildAvatar(initials, i),
                        const SizedBox(width: 12),
                        // Name & property
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF2F4156),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                propertyName,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        _buildStatusBadge(isScheduled, status),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // -- Row 2: Date | Time -----------------------------------
                    _buildDateTimeRow(dateStr, timeStr),

                    const SizedBox(height: 12),

                    // -- Row 3: Call | Chat buttons ---------------------------
                    Row(
                      children: [
                        // Call button
                        Expanded(
                          child: _buildCallButton(mobile, () => _call(mobile!)),
                        ),
                        const SizedBox(width: 10),
                        // Chat button
                        Expanded(
                          child: _buildChatButton(() {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  propertyId: property["id"],
                                  ownerId: ownerId,
                                  ownerName: userName,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -- Shared Widgets ---------------------------------------------------------

  /// Avatar circle with initials + green online indicator dot
  Widget _buildAvatar(String initials, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _avatarBg(index),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              color: _avatarFg(index),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        // Green online dot
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isScheduled, String status) {
    final String label = isScheduled ? "Scheduled" : _capitalise(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EF), // light green bg
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB7E4C7), width: 1),
      ),
      child: const Text(
        "Scheduled",
        style: TextStyle(
          color: Color(0xFF2E8B57), // green text
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Date & time info row (white card with vertical divider)
  Widget _buildDateTimeRow(String date, String time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          // Date
          Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            date,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          // Divider
          Expanded(
            child: Center(
              child: Container(
                width: 1,
                height: 18,
                color: const Color(0xFFD1D5DB),
              ),
            ),
          ),
          // Time
          Icon(
            Icons.access_time_rounded,
            size: 15,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  /// Outlined "Call" button
  Widget _buildCallButton(String? mobile, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: mobile != null ? onTap : null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        child: const Text(
          "Call",
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  /// Filled dark "Chat" button
  Widget _buildChatButton(VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2F4156),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          "Chat",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
