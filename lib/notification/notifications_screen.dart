// notifications_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentit/main/chatscreen.dart';
import 'package:rentit/main/enquires.dart';
import 'package:rentit/notification/notification_service.dart';

// -----------------------------------------------------------------------------
//  PALETTE
// -----------------------------------------------------------------------------

const Color _primary = Color(0xFF1A2B40);
const Color _accent = Color(0xFF0A7C66);
const Color _orange = Color(0xFFF59E0B);
const Color _purple = Color(0xFF7C5CE4);
const Color _text = Color(0xFF111827);
const Color _text2 = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);
const Color _unreadDot = Color(0xFF1E2B45);
const Color _bg = Color(0xFFF5F6F8);

// -----------------------------------------------------------------------------
//  AVATAR COLORS
// -----------------------------------------------------------------------------

const List<Color> _avatarPalette = [
  Color(0xFF1A2B40),
  Color(0xFF0A7C66),
  Color(0xFF2563EB),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFFDC2626),
  Color(0xFF0891B2),
  Color(0xFF059669),
];

Color _avatarColor(String name) {
  if (name.isEmpty) return _avatarPalette[0];
  return _avatarPalette[name.codeUnitAt(0) % _avatarPalette.length];
}

enum _Filter { all, bookings, messages }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  // -- State ------------------------------------------------------------------
  List<AppNotification> _all = [];
  List<Map<String, dynamic>> _chatList = [];
  bool _loading = true;
  bool _chatsLoading = false;
  _Filter _filter = _Filter.all;
  int? _userId;

  static const String _baseUrl = "https://rentit-backend-omega.vercel.app";

  // -- Lifecycle --------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId =
        prefs.getInt('userId') ?? int.tryParse(prefs.getString('userId') ?? '');
    await Future.wait([_loadNotifications(), _loadChats()]);
  }

  // -- Notifications ----------------------------------------------------------

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await NotificationService.getAll();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  // -- Chat list --------------------------------------------------------------

  Future<void> _loadChats() async {
    if (_userId == null) return;
    if (!mounted) return;
    setState(() => _chatsLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/list?userId=$_userId'),
        headers: const {'Content-Type': 'application/json'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _chatList = data.cast<Map<String, dynamic>>();
          _chatsLoading = false;
        });
      } else {
        setState(() => _chatsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _chatsLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadNotifications(), _loadChats()]);
  }

  Future<void> _markAllRead() async {
    HapticFeedback.lightImpact();
    await NotificationService.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _onNotificationTap(AppNotification n) async {
    if (!n.isRead) {
      await NotificationService.markAsRead(n.id);
      if (!mounted) return;
      NotificationService.getAll().then((list) {
        if (!mounted) return;
        setState(() => _all = list);
      });
    }
    if (!mounted) return;
    switch (n.category) {
      case NotificationCategory.message:
        if (n.propertyId != null && n.otherUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                propertyId: n.propertyId!,
                ownerId: n.otherUserId!,
                ownerName: n.otherUserName ?? 'User',
              ),
            ),
          ).then((_) => _loadChats());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open chat � missing info')),
          );
        }
        break;
      case NotificationCategory.booking:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnquiriesScreen()),
        );
        break;
      case NotificationCategory.offer:
      case NotificationCategory.system:
        break;
    }
  }

  Future<void> _deleteNotification(AppNotification n) async {
    await NotificationService.delete(n.id);
    await _loadNotifications();
  }

  void _openChat(Map<String, dynamic> chat) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    final otherId = chat['senderId'] == _userId
        ? chat['receiverId'] as int
        : chat['senderId'] as int;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          propertyId: chat['propertyId'],
          ownerId: otherId,
          ownerName: chat['otherUserName'] ?? 'User',
        ),
      ),
    ).then((_) => _loadChats());
  }

  // -- Computed ---------------------------------------------------------------

  List<AppNotification> get _filteredNotifications {
    switch (_filter) {
      case _Filter.all:
        return _all;
      case _Filter.bookings:
        return _all
            .where((n) => n.category == NotificationCategory.booking)
            .toList();
      case _Filter.messages:
        // Under messages tab we show the chat list, not notification items
        return [];
    }
  }

  int _countFor(_Filter f) {
    switch (f) {
      case _Filter.all:
        return _all.where((n) => !n.isRead).length;
      case _Filter.bookings:
        return _all
            .where(
              (n) => n.category == NotificationCategory.booking && !n.isRead,
            )
            .length;
      case _Filter.messages:
        // Count chats with unread messages
        return _chatList
            .where((c) => (c['unreadCount'] ?? 0) as int > 0)
            .length;
    }
  }

  // -- Helpers ----------------------------------------------------------------

  String _formatChatTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day == today) {
        final h = dt.hour;
        final m = dt.minute.toString().padLeft(2, '0');
        final ampm = h >= 12 ? 'PM' : 'AM';
        final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        return '$hour:$m $ampm';
      }
      if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return '?';
    return name.trim().split(' ').map((e) => e[0]).take(2).join();
  }

  // -- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final unreadAll = _all.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(unreadAll),
            const SizedBox(height: 16),
            _buildTabRow(),
            const SizedBox(height: 2),
            Container(height: 1.5, color: _border),
            Expanded(
              child:
                  (_loading && _filter != _Filter.messages) ||
                      (_chatsLoading && _filter == _Filter.messages)
                  ? const Center(
                      child: CircularProgressIndicator(color: _primary),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      color: _primary,
                      child: _buildBody(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Header -----------------------------------------------------------------

  Widget _buildHeader(int unreadAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: _text,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  unreadAll == 0 ? 'All caught up!' : '$unreadAll unread',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          if (unreadAll > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _text),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded, size: 16, color: _text),
                    SizedBox(width: 6),
                    Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _text,
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

  // -- Tab row ----------------------------------------------------------------

  Widget _buildTabRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Tab(
            label: 'All',
            count: _countFor(_Filter.all),
            active: _filter == _Filter.all,
            onTap: () => setState(() => _filter = _Filter.all),
          ),
          const SizedBox(width: 28),
          _Tab(
            label: 'Bookings',
            count: _countFor(_Filter.bookings),
            active: _filter == _Filter.bookings,
            onTap: () => setState(() => _filter = _Filter.bookings),
          ),
          const SizedBox(width: 28),
          _Tab(
            label: 'Messages',
            count: _countFor(_Filter.messages),
            active: _filter == _Filter.messages,
            onTap: () => setState(() => _filter = _Filter.messages),
          ),
        ],
      ),
    );
  }

  // -- Body router ------------------------------------------------------------

  Widget _buildBody() {
    if (_filter == _Filter.messages) {
      return _buildChatList();
    }
    return _buildNotificationList();
  }

  // -- Notification list ------------------------------------------------------

  Widget _buildNotificationList() {
    final items = _filteredNotifications;
    if (items.isEmpty) return _buildEmptyNotifications();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final n = items[i];
        return _SwipableNotificationTile(
          notification: n,
          onTap: () => _onNotificationTap(n),
          onDelete: () => _deleteNotification(n),
        );
      },
    );
  }

  // -- Chat list --------------------------------------------------------------

  Widget _buildChatList() {
    if (_chatList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Start chatting with property owners',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header count
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            '${_chatList.length} active '
            '${_chatList.length == 1 ? 'conversation' : 'conversations'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: _chatList.length,
            itemBuilder: (_, i) {
              final chat = _chatList[i];
              final name = (chat['otherUserName'] ?? 'User').toString();
              final message = (chat['message'] ?? '').toString();
              final propertyName = (chat['propertyName'] ?? '').toString();
              final locality = (chat['locality'] ?? '').toString();
              final unread = (chat['unreadCount'] ?? 0) as int;
              final hasUnread = unread > 0;
              final time = _formatChatTime(chat['createdAt']?.toString());
              final initials = _initials(name);
              final avatarColor = _avatarColor(name);

              final propertyLine = [
                propertyName,
                locality,
              ].where((e) => e.isNotEmpty).join(' � ');

              return _ChatTile(
                name: name,
                message: message,
                propertyLine: propertyLine,
                time: time,
                unread: unread,
                hasUnread: hasUnread,
                initials: initials,
                avatarColor: avatarColor,
                onTap: () => _openChat(chat),
              );
            },
          ),
        ),
      ],
    );
  }

  // -- Empty notifications ----------------------------------------------------

  Widget _buildEmptyNotifications() {
    final String label;
    final IconData icon;

    switch (_filter) {
      case _Filter.bookings:
        label = 'No booking notifications yet.\nBook a visit to see them here.';
        icon = Icons.event_available_outlined;
        break;
      case _Filter.messages:
        label = 'No message notifications yet.';
        icon = Icons.chat_bubble_outline_rounded;
        break;
      case _Filter.all:
        label = "You're all caught up!\nNo notifications right now.";
        icon = Icons.notifications_none_rounded;
        break;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FAF4),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: _primary),
              ),
              const SizedBox(height: 20),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9CA3AF),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
//  CHAT TILE
// -----------------------------------------------------------------------------

class _ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String propertyLine;
  final String time;
  final int unread;
  final bool hasUnread;
  final String initials;
  final Color avatarColor;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name,
    required this.message,
    required this.propertyLine,
    required this.time,
    required this.unread,
    required this.hasUnread,
    required this.initials,
    required this.avatarColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasUnread
                    ? _primary.withOpacity(0.30)
                    : const Color(0xFFE5E7EB),
                width: hasUnread ? 1.2 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarColor.withOpacity(0.14),
                      child: Text(
                        initials.toUpperCase(),
                        style: TextStyle(
                          color: avatarColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasUnread
                                  ? _primary
                                  : const Color(0xFF6B7280),
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // Property line
                      if (propertyLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          propertyLine,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      // Message + badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: hasUnread
                                    ? const Color(0xFF111827)
                                    : const Color(0xFF6B7280),
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  TAB WIDGET
// -----------------------------------------------------------------------------

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _text : const Color(0xFF94A3B8),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    color: active ? _unreadDot : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: active ? Colors.white : Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: active ? 80 : 0,
            decoration: BoxDecoration(
              color: _unreadDot,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  SWIPABLE NOTIFICATION TILE
// -----------------------------------------------------------------------------

class _SwipableNotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SwipableNotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: const Color(0xFFFFEBEE),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFE53935),
              size: 26,
            ),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: _NotificationTile(notification: notification, onTap: onTap),
    );
  }
}

// -----------------------------------------------------------------------------
//  NOTIFICATION TILE
// -----------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  static const Map<NotificationCategory, _TileStyle> _styles = {
    NotificationCategory.booking: _TileStyle(
      iconBg: Color(0xFFEAF5EF),
      iconColor: Color(0xFF1A2B40),
      icon: Icons.event_note_outlined,
    ),
    NotificationCategory.message: _TileStyle(
      iconBg: Color(0xFFF2ECFA),
      iconColor: Color(0xFF7C5CE4),
      icon: Icons.chat_bubble_outline_rounded,
    ),
    NotificationCategory.offer: _TileStyle(
      iconBg: Color(0xFFFBEFE8),
      iconColor: Color(0xFFF08A3E),
      icon: Icons.local_offer_outlined,
    ),
    NotificationCategory.system: _TileStyle(
      iconBg: Color(0xFFEAF1F9),
      iconColor: Color(0xFF4B8BE5),
      icon: Icons.info_outline_rounded,
    ),
  };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hr${h > 1 ? 's' : ''} ago';
    }
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final style =
        _styles[notification.category] ?? _styles[NotificationCategory.system]!;
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: isUnread ? const Color(0xFFF8FAFF) : Colors.white,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread dot
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: Container(
                    height: 9,
                    width: 9,
                    decoration: const BoxDecoration(
                      color: _unreadDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(width: 21),

              // Category icon
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: style.iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(style.icon, color: style.iconColor, size: 26),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB6BDC9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isUnread ? _text2 : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CategoryChip(category: notification.category),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  CATEGORY CHIP
// -----------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  final NotificationCategory category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    switch (category) {
      case NotificationCategory.booking:
        bg = const Color(0xFFEAF5EF);
        fg = _accent;
        label = 'Booking';
        break;
      case NotificationCategory.message:
        bg = const Color(0xFFF2ECFA);
        fg = _purple;
        label = 'Message';
        break;
      case NotificationCategory.offer:
        bg = const Color(0xFFFFF3E0);
        fg = _orange;
        label = 'Offer';
        break;
      case NotificationCategory.system:
        bg = const Color(0xFFEAF1F9);
        fg = const Color(0xFF4B8BE5);
        label = 'System';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  STYLE VALUE OBJECT
// -----------------------------------------------------------------------------

class _TileStyle {
  final Color iconBg;
  final Color iconColor;
  final IconData icon;

  const _TileStyle({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
  });
}
