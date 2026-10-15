// chat_list_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'chatscreen.dart';

// -----------------------------------------------------------------------------
//  PALETTE
// -----------------------------------------------------------------------------

const Color _primary = Color(0xFF1A2B40); // deep navy (brand)
const Color _primaryLight = Color(0xFFE8EDF2); // navy tint for badges/bg
const Color _accent = Color(0xFF0A7C66); // teal accent
const Color _bg = Color(0xFFF5F6F8); // page background
const Color _surface = Colors.white;
const Color _textPrimary = Color(0xFF111827);
const Color _textSecondary = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);
const Color _unreadBorder = Color(0xFF1A2B40);

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

// -----------------------------------------------------------------------------
//  CHAT LIST SCREEN
// -----------------------------------------------------------------------------

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  // -- State ------------------------------------------------------------------
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  bool _isSearchOpen = false;
  int? _userId;

  // -- Controllers ------------------------------------------------------------
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // -- Config -----------------------------------------------------------------
  static const String _baseUrl = "https://rentit-backend-yti9.onrender.com";
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // -- Lifecycle --------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _searchController.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // -- Initialisation ---------------------------------------------------------

  Future<void> _init() async {
    final id = await _loadUserId();
    if (!mounted) return;
    if (id == null) {
      _showSnack('Please login first');
      _handleBack();
      return;
    }
    _userId = id;
    await _fetchChats();
  }

  Future<int?> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId') ??
        int.tryParse(prefs.getString('userId') ?? '');
  }

  // -- Data -------------------------------------------------------------------

  Future<void> _fetchChats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chat/list?userId=$_userId'),
        headers: _headers,
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _chats = data.cast<Map<String, dynamic>>();
          _filteredChats = List.from(_chats);
          _isLoading = false;
        });
        _fadeController.forward(from: 0);
      } else {
        throw Exception('Server error ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load chats');
    }
  }

  // -- Search -----------------------------------------------------------------

  void _onSearchChanged() {
    if (!mounted) return;
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredChats = q.isEmpty
          ? List.from(_chats)
          : _chats.where((c) {
              final name = (c['otherUserName'] ?? '').toString().toLowerCase();
              final prop = (c['propertyName'] ?? '').toString().toLowerCase();
              final loc = (c['locality'] ?? '').toString().toLowerCase();
              return name.contains(q) || prop.contains(q) || loc.contains(q);
            }).toList();
    });
  }

  void _openSearch() {
    setState(() => _isSearchOpen = true);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    setState(() {
      _isSearchOpen = false;
      _searchController.clear();
      _filteredChats = List.from(_chats);
    });
  }

  // -- Navigation -------------------------------------------------------------

  void _handleBack() {
    if (_isSearchOpen) {
      _closeSearch();
      return;
    }
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

  void _openChat(Map<String, dynamic> chat) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    final otherId = _otherUserId(chat);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          propertyId: chat['propertyId'],
          ownerId: otherId,
          ownerName: chat['otherUserName'] ?? 'User',
        ),
      ),
    ).then((_) {
      if (mounted) _fetchChats();
    });
  }

  // -- Helpers ----------------------------------------------------------------

  int _otherUserId(Map<String, dynamic> chat) =>
      chat['senderId'] == _userId ? chat['receiverId'] : chat['senderId'];

  String _formatTime(String? raw) {
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SubHeader(
                  chats: _chats,
                  filtered: _filteredChats,
                  isLoading: _isLoading,
                  isSearchOpen: _isSearchOpen,
                  query: _searchController.text.trim(),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _surface,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    centerTitle: false,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, size: 24, color: _primary),
      onPressed: _handleBack,
    ),
    title: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isSearchOpen
          ? _SearchField(
              key: const ValueKey('search'),
              controller: _searchController,
              focusNode: _searchFocus,
            )
          : const Text(
              'My Chats',
              key: ValueKey('title'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
    ),
    actions: [
      if (!_isSearchOpen)
        IconButton(
          icon: const Icon(Icons.search_rounded, color: _primary),
          onPressed: _openSearch,
        )
      else
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _primary),
          onPressed: _closeSearch,
        ),
      const SizedBox(width: 6),
    ],
  );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
      );
    }
    if (_filteredChats.isEmpty) {
      return _EmptyState(
        isSearch: _isSearchOpen && _searchController.text.trim().isNotEmpty,
      );
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _fetchChats,
        color: _primary,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 6, bottom: 100),
          itemCount: _filteredChats.length,
          itemBuilder: (_, i) => _ChatTile(
            chat: _filteredChats[i],
            initials: _initials(_filteredChats[i]['otherUserName'] ?? ''),
            avatarColor: _avatarColor(_filteredChats[i]['otherUserName'] ?? ''),
            formattedTime: _formatTime(_filteredChats[i]['createdAt']),
            onTap: () => _openChat(_filteredChats[i]),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  SUB HEADER
// -----------------------------------------------------------------------------

class _SubHeader extends StatelessWidget {
  final List<Map<String, dynamic>> chats;
  final List<Map<String, dynamic>> filtered;
  final bool isLoading;
  final bool isSearchOpen;
  final String query;

  const _SubHeader({
    required this.chats,
    required this.filtered,
    required this.isLoading,
    required this.isSearchOpen,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    if (isLoading) {
      label = '';
    } else if (query.isNotEmpty) {
      final c = filtered.length;
      label = c == 0
          ? 'No results for "$query"'
          : '$c result${c == 1 ? '' : 's'} for "$query"';
    } else {
      final c = chats.length;
      label = c == 0
          ? ''
          : '$c active ${c == 1 ? 'conversation' : 'conversations'}';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: label.isEmpty
          ? const SizedBox(key: ValueKey('empty'), height: 6)
          : Container(
              key: ValueKey(label),
              width: double.infinity,
              color: _bg,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
//  SEARCH FIELD
// -----------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: _textPrimary),
      decoration: const InputDecoration(
        hintText: 'Search by name or property�',
        hintStyle: TextStyle(color: _textSecondary, fontSize: 15),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
//  CHAT TILE
// -----------------------------------------------------------------------------

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String initials;
  final Color avatarColor;
  final String formattedTime;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.initials,
    required this.avatarColor,
    required this.formattedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (chat['otherUserName'] ?? 'User').toString();
    final message = (chat['message'] ?? '').toString();
    final propertyName = (chat['propertyName'] ?? '').toString();
    final locality = (chat['locality'] ?? '').toString();
    final unread = (chat['unreadCount'] ?? 0) as int;
    final hasUnread = unread > 0;

    final propertyLine = [
      propertyName,
      locality,
    ].where((e) => e.isNotEmpty).join(' � ');

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
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasUnread ? _unreadBorder.withOpacity(0.30) : _border,
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
                // -- Avatar --------------------------------------------
                _Avatar(
                  initials: initials,
                  color: avatarColor,
                  hasUnread: hasUnread,
                ),
                const SizedBox(width: 12),
                // -- Content -------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Time
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
                                color: _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasUnread ? _primary : _textSecondary,
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
                            color: _textSecondary,
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
                                    ? _textPrimary
                                    : _textSecondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: unread),
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
//  AVATAR
// -----------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final bool hasUnread;

  const _Avatar({
    required this.initials,
    required this.color,
    required this.hasUnread,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: color.withOpacity(0.14),
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: color,
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
              border: Border.all(color: _surface, width: 1.5),
            ),
          ),
        ),
    ],
  );
}

// -----------------------------------------------------------------------------
//  UNREAD BADGE
// -----------------------------------------------------------------------------

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _primary,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
//  EMPTY STATE
// -----------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool isSearch;
  const _EmptyState({required this.isSearch});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            isSearch
                ? Icons.search_off_rounded
                : Icons.chat_bubble_outline_rounded,
            size: 34,
            color: _primary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isSearch ? 'No matches found' : 'No conversations yet',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isSearch
              ? 'Try a different name or property'
              : 'Start chatting with property owners',
          style: const TextStyle(fontSize: 13, color: _textSecondary),
        ),
      ],
    ),
  );
}
