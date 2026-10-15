import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rentit/main/AiSearchSheet.dart';
import 'package:rentit/main/ChatListScreen.dart';
import 'package:rentit/main/plans.dart';
import 'package:rentit/main/rental_home.dart';
import 'package:rentit/main/MyActivityScreen.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final int activityTabIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.activityTabIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isNavigating = false;

  late final List<Widget> _pages;

  static const _navItems = [
    _NavItem(icon: CupertinoIcons.house_alt, label: 'Home', index: 0),
    _NavItem(icon: CupertinoIcons.sparkles, label: 'Premium', index: 3),
    _NavItem(icon: CupertinoIcons.graph_square, label: 'Activity', index: 2),

    _NavItem(icon: CupertinoIcons.chat_bubble, label: 'Chat', index: 1),

    _NavItem(
      icon: CupertinoIcons.square_grid_2x2,
      label: 'List Property',
      index: 4,
    ),
  ];

  static const Color _activeColor = Color(0xFF2F4253);
  static const Color _inactiveColor = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      const RentHomeScreen(),
      const ChatListScreen(),
      MyActivityScreen(initialIndex: widget.activityTabIndex),
      const PlansScreen(),
    ];
  }

  // ✅ SAFE TAP HANDLER
  Future<void> _onTap(int index) async {
    if (_isNavigating) return;

    // 👉 PROPERTY FLOW (SEPARATE SCREEN)
    if (index == 4) {
      _isNavigating = true;

      if (!mounted) return;

      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => const PgOwnerNavigationScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        ),
      );

      if (mounted) _isNavigating = false;
      return;
    }

    // 👉 NORMAL TAB SWITCH
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);
  }

  // ✅ FIXED BOTTOM NAV (NO DOUBLE TAP BUG)
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA), width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: _navItems.map((item) {
              final isSelected = item.index != 4 && _currentIndex == item.index;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (_isNavigating) return;
                    _onTap(item.index);
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          item.icon,
                          size: 23,
                          color: isSelected ? _activeColor : _inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected ? _activeColor : _inactiveColor,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ✅ FIXED BUILD (NO BLACK SCREEN)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // 🔥 FIX: REPLACED INDEXEDSTACK (CAUSE OF BLACK SCREEN)
      body: Stack(
        children: [
          Offstage(offstage: _currentIndex != 0, child: _pages[0]),
          Offstage(offstage: _currentIndex != 1, child: _pages[1]),
          Offstage(offstage: _currentIndex != 2, child: _pages[2]),
          Offstage(offstage: _currentIndex != 3, child: _pages[3]),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        heroTag: 'main_fab',
        elevation: 0,
        backgroundColor: Colors.transparent,
        onPressed: () {
          if (_isNavigating) return;

          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Aisearchsheet()),
          );
        },
        child: SizedBox(
          height: 72,
          width: 72,
          child: Center(child: Image.asset('assets/floating_icon/ai_icon.png')),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

// ── NAV ITEM ──
class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
