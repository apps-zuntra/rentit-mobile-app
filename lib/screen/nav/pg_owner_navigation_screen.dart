import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rentit/main/enquires.dart';
import 'package:rentit/main/Listingscreen.dart';
import 'package:rentit/main/DashboardScreen.dart';
import 'package:rentit/pg_page/pg_page/pg_post/PostpertyNavscreen.dart';
import 'package:rentit/screen/account_screen.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';

class PgOwnerNavigationScreen extends StatefulWidget {
  final int initialIndex; // ✅ ADD THIS

  const PgOwnerNavigationScreen({
    super.key,
    this.initialIndex = 1, // default Dashboard
  });

  @override
  State<PgOwnerNavigationScreen> createState() =>
      _PgOwnerNavigationScreenState();
}

class _PgOwnerNavigationScreenState extends State<PgOwnerNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; // ✅ IMPORTANT
  }

  final List<Widget> _pages = const [
     MainNavigationScreen(initialIndex: 0,),
    DashboardPage(),
    MyListingsScreen(),
    EnquiriesScreen(),
    AccountScreen(),
  ];

  // ✅ SAME COLOR SYSTEM AS MAIN SCREEN
  static const Color _activeColor = Color(0xFF2F4253);
  static const Color _inactiveColor = Color(0xFF9CA3AF);

static const _navItems = [
  _NavItem(
    icon: CupertinoIcons.arrow_left_circle,
    label: 'rentit',
    index: 0,
  ),

  _NavItem(
    icon: CupertinoIcons.home,
    label: 'Dashboard',
    index: 1,
  ),

  _NavItem(
    icon: CupertinoIcons.square_grid_2x2,
    label: 'Listings',
    index: 2,
  ),

  _NavItem(
    icon: CupertinoIcons.chat_bubble,
    label: 'Enquiries',
    index: 3,
  ),

  _NavItem(
    icon: CupertinoIcons.person,
    label: 'Profile',
    index: 4,
  ),
];
  void _onTap(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(-1, 0),
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
        (route) => false,
      );
      return;
    }

    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildNavItem(_NavItem item) {
    final isSelected = item.index != 0 && _currentIndex == item.index;

    return Expanded(
      child: InkWell(
        onTap: () => _onTap(item.index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ SAME ANIMATION AS MAIN SCREEN
            AnimatedScale(
  scale: isSelected ? 1.08 : 1.0,
  duration: const Duration(milliseconds: 200),
  child: Icon(
    item.icon,
    size: 26,
    color: isSelected ? _activeColor : _inactiveColor,
  ),
),

            const SizedBox(height: 4),

            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? _activeColor : _inactiveColor,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onTap(0);
      },
      child: Scaffold(
        backgroundColor: Colors.white,

        body: IndexedStack(index: _currentIndex, children: _pages),

        // ✅ CLEAN FAB (OPTIONAL STYLE IMPROVE)
        floatingActionButton: FloatingActionButton(
          heroTag: 'pg_fab',
          backgroundColor: _activeColor,
          elevation: 2,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostPropertyScreen()),
          ),
          child: const Icon(CupertinoIcons.add, color: Colors.white),
        ),

        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFEAEAEA), width: 0.8),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(children: _navItems.map(_buildNavItem).toList()),
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ SAME STRUCTURE AS MAIN NAV
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
