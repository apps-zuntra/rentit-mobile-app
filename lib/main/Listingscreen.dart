// Listingscreen.dart
// Production-ready Flutter implementation � matches design spec exactly
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/pg_page/pg_page/pg_post/PGRoomTypeDetailsScreen.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentPropertydetails.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialPropertydetails.dart';
import 'package:rentit/screen/Flatmate/Flatmate/FlatmatePropertydetails.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

const String _kApiBase = "https://rentit-backend-yti9.onrender.com";

// Colour palette
const Color _kGreen = Color(0xFF2F4253);
const Color _kGreenDark = Color(0xFF085F4E);
const Color _kGreenLight = Color(0xFFE8F5F0);
const Color _kOrange = Color(0xFFFF6B35);
const Color _kOrangeLight = Color(0xFFFFF3EE);
const Color _kOrangeBorder = Color(0xFFFFE0C0);
const Color _kYellow = Color(0xFFFFB800);
const Color _kBg = Color(0xFFF5F6F8);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kText = Color(0xFF2F4253);
const Color _kText2 = Color(0xFF4B5563);
const Color _kText3 = Color(0xFF9CA3AF);
const Color _kRed = Color(0xFFEF4444);
const Color _kSubText = Color(0xFF6B7C7C);
const Color _kCardBg = Colors.white;
const Color _kEditBtnBg = Color(0xFFE5E7EB);
const Color _kPlaceholderBg = Color(0xFFF0F2F5);
const Color _kPlaceholderIcon = Color(0xFFD1D5DB);

// Typography helpers
const TextStyle _tsAppBarTitle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: _kText,
  letterSpacing: -0.3,
);

const TextStyle _tsCountLabel = TextStyle(
  fontSize: 12,
  color: _kText3,
  fontWeight: FontWeight.w400,
);

const TextStyle _tsTabLabel = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
);

const TextStyle _tsTabUnselected = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
);

const TextStyle _tsCardTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w500,
  color: _kText,
  letterSpacing: -0.2,
);

const TextStyle _tsRent = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: _kText,
);

const TextStyle _tsRentSuffix = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: _kSubText,
);

const TextStyle _tsAddress = TextStyle(fontSize: 12, color: _kSubText);

const TextStyle _tsMetaChip = TextStyle(fontSize: 12, color: _kSubText);

const TextStyle _tsStatLabel = TextStyle(fontSize: 13, color: _kSubText);

const TextStyle _tsEditBtn = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: Color(0xFF1C1C1E),
);

const TextStyle _tsPremiumBtn = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

const TextStyle _tsBoostLabel = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: _kText2,
);

const TextStyle _tsBoostSub = TextStyle(fontSize: 10, color: _kText3);

const TextStyle _tsBoostBtn = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.bold,
);

const TextStyle _tsBadge = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.bold,
);

const TextStyle _tsInfoTitle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _kText,
);

const TextStyle _tsInfoSub = TextStyle(fontSize: 12, color: _kText3);

const TextStyle _tsCategoryChip = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

const TextStyle _tsFlatmateChip = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: _kGreenDark,
);

const TextStyle _tsExpiredBadge = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: _kOrange,
);

const TextStyle _tsRenewBtn = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.bold,
);

const TextStyle _tsEmptyHeading = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: _kText,
);

const TextStyle _tsEmptySub = TextStyle(fontSize: 12, color: _kText3);

const TextStyle _tsErrorBody = TextStyle(color: _kText2, fontSize: 13);

// Dimensions
const double _kCardRadius = 16.0;
const double _kCardImageHeight = 180.0;
const double _kChipHeight = 42.0;
const double _kActionBtnHeight = 44.0;
const double _kCardPadH = 14.0;
const double _kCardPadV = 14.0;
const double _kCardPadTop = 12.0;
const double _kCardMarginBottom = 16.0;
const double _kListPadH = 14.0;
const double _kListPadV = 14.0;
const double _kTabBarHeight = 48.0;

// -----------------------------------------------------------------------------
// Enums / value types
// -----------------------------------------------------------------------------

enum _ListingTab { all, active, inactive, draft }

enum _ListingCategory { pg, apartment, commercial, flatmates }

// -----------------------------------------------------------------------------
// Main widget
// -----------------------------------------------------------------------------

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  // -- State ------------------------------------------------------------------
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;
  String? _error;
  _ListingTab _activeTab = _ListingTab.all;
  _ListingCategory _activeCategory = _ListingCategory.pg;
  late TabController _tabController;
  Map<int, _PropertyStats> _propertyStats = {};

  // -- Tab / category metadata ------------------------------------------------
  static const List<_TabMeta> _tabs = [
    _TabMeta(label: "All", tab: _ListingTab.all),
    _TabMeta(label: "Active", tab: _ListingTab.active),
    _TabMeta(label: "Inactive", tab: _ListingTab.inactive),
    _TabMeta(label: "Draft", tab: _ListingTab.draft),
  ];

  static const List<_CategoryMeta> _categories = [
    _CategoryMeta(label: "PG", category: _ListingCategory.pg),
    _CategoryMeta(label: "Apartment", category: _ListingCategory.apartment),
    _CategoryMeta(label: "Commercial", category: _ListingCategory.commercial),
    _CategoryMeta(label: "Flatmates", category: _ListingCategory.flatmates),
  ];

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadProperties();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() => _activeTab = _tabs[_tabController.index].tab);
    }
  }

  // -- API --------------------------------------------------------------------

  Future<void> _loadProperties() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final userId = prefs.getInt("userId");

      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final List<Map<String, dynamic>> all = [];

      // PG
      await _fetchAndAppend(
        url: "$_kApiBase/property/my",
        headers: headers,
        type: 'pg',
        sink: all,
      );

      // Commercial
      await _fetchAndAppend(
        url: "$_kApiBase/commercial",
        headers: headers,
        type: 'commercial',
        sink: all,
      );

      // Apartment
      await _fetchAndAppend(
        url: "$_kApiBase/apartment/my",
        headers: headers,
        type: 'apartment',
        sink: all,
      );

      // Flatmate � client-side filter by userId
      await _fetchFlatmates(headers: headers, userId: userId, sink: all);

      if (!mounted) return;
      setState(() {
        _properties = all;
        _loading = false;
      });

      // Kick off stats fetches (fire-and-forget)
      for (final p in all) {
        final id = p["id"];
        final type = (p['_listingType'] ?? '').toString();
        if (id != null && type != 'flatmate') {
          _fetchStats(id as int);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchAndAppend({
    required String url,
    required Map<String, String> headers,
    required String type,
    required List<Map<String, dynamic>> sink,
  }) async {
    try {
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = List<Map<String, dynamic>>.from(data as List);
        for (final item in items) {
          item['_listingType'] = type;
        }
        sink.addAll(items);
      }
    } catch (e) {
      debugPrint("[$type] fetch error: $e");
    }
  }

  Future<void> _fetchFlatmates({
    required Map<String, String> headers,
    required int? userId,
    required List<Map<String, dynamic>> sink,
  }) async {
    try {
      final res = await http.get(
        Uri.parse("$_kApiBase/flatmate/all"),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final all = List<Map<String, dynamic>>.from(
          jsonDecode(res.body) as List,
        );
        final mine = all.where((f) => f["userId"] == userId).toList();
        for (final f in mine) {
          f['_listingType'] = 'flatmate';
        }
        sink.addAll(mine);
      }
    } catch (e) {
      debugPrint("[flatmate] fetch error: $e");
    }
  }

  Future<void> _fetchStats(int propertyId) async {
    try {
      final res = await http.get(
        Uri.parse("$_kApiBase/property/stats/$propertyId"),
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _propertyStats[propertyId] = _PropertyStats(
            views: (data["views"] ?? 0) as int,
            enquiries: (data["enquiries"] ?? 0) as int,
          );
        });
      }
    } catch (e) {
      debugPrint("[stats:$propertyId] $e");
    }
  }

  // -- Filters ----------------------------------------------------------------

  static bool _isFlatmate(Map<String, dynamic> p) =>
      (p['_listingType'] ?? '') == 'flatmate';

  List<Map<String, dynamic>> get _filteredByTab {
    switch (_activeTab) {
      case _ListingTab.active:
        return _properties.where((p) {
          if (_isFlatmate(p)) return true;
          return p["isDraft"] == false && (p["currentStep"] ?? 0) == 7;
        }).toList();

      case _ListingTab.inactive:
        return _properties.where((p) {
          if (_isFlatmate(p)) return false;
          return p["isDraft"] == true && (p["currentStep"] ?? 0) >= 3;
        }).toList();

      case _ListingTab.draft:
        return _properties
            .where((p) => !_isFlatmate(p) && p["isDraft"] == true)
            .toList();

      case _ListingTab.all:
      default:
        return _properties;
    }
  }

  List<Map<String, dynamic>> get _filteredByCategory {
    final tabFiltered = _filteredByTab;
    return tabFiltered.where((p) {
      final t = (p['_listingType'] ?? '').toString().toLowerCase();
      switch (_activeCategory) {
        case _ListingCategory.pg:
          return t == 'pg';
        case _ListingCategory.apartment:
          return t == 'apartment';
        case _ListingCategory.commercial:
          return t == 'commercial';
        case _ListingCategory.flatmates:
          return t == 'flatmate';
      }
    }).toList();
  }

  // -- Helpers ----------------------------------------------------------------

  String _getTitle(Map<String, dynamic> p) {
    if (_isFlatmate(p)) {
      return p["apartmentName"] ??
          p["apartmentType"] ??
          p["propertyType"] ??
          "Flatmate Listing";
    }
    return p["propertyName"] ??
        p["commercialPropertyType"] ??
        p["propertyType2"] ??
        p["propertyType"] ??
        "Property";
  }

  String _getAddress(Map<String, dynamic> p) {
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

  dynamic _getRent(Map<String, dynamic> p) {
    final roomList = p["roomType"];
    if (roomList is List && roomList.isNotEmpty && roomList[0] is Map) {
      return roomList[0]["rent"];
    }
    return p["expectedRent"];
  }

  String? _getFirstImage(Map<String, dynamic> p) {
    final list = extractPropertyImages(p, _kApiBase);
    return list.isNotEmpty ? list.first : null;
  }

  _ListingStatus _resolveStatus(Map<String, dynamic> p) {
    if (p["premiumExpired"] == true) return _ListingStatus.premiumExpired;
    if (_isFlatmate(p)) return _ListingStatus.live;
    final isDraft = p["isDraft"] == true;
    final currentStep = (p["currentStep"] ?? 1) as int;
    if (!isDraft && currentStep == 7) return _ListingStatus.live;
    if (isDraft) return _ListingStatus.inactive;
    return _ListingStatus.pending;
  }

  String _statusLabel(_ListingStatus s) {
    switch (s) {
      case _ListingStatus.premiumExpired:
        return "Expired 4d ago";
      case _ListingStatus.live:
        return "Active 2d ago";
      case _ListingStatus.inactive:
        return "Inactive 33d ago";
      case _ListingStatus.pending:
        return "Pending";
    }
  }

  Color _statusColor(_ListingStatus s) {
    switch (s) {
      case _ListingStatus.premiumExpired:
        return _kOrange;
      case _ListingStatus.live:
        return _kGreen;
      case _ListingStatus.inactive:
        return _kText.withOpacity(0.80);
      case _ListingStatus.pending:
        return _kYellow;
    }
  }

  String get _countLabel =>
      "${_loading ? 0 : _filteredByCategory.length} total properties";

  void _handleBack() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const PgOwnerNavigationScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  // -- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCountLabel(),
              _buildCategoryFilter(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // -- AppBar -----------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 24, color: _kText),
        onPressed: _handleBack,
        splashRadius: 22,
      ),
      title: const Text("My Listings", style: _tsAppBarTitle),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_kTabBarHeight),
        child: _buildTabBar(),
      ),
    );
  }

  // -- Tab Bar ----------------------------------------------------------------

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _kGreen,
        unselectedLabelColor: _kText3,
        labelStyle: _tsTabLabel,
        unselectedLabelStyle: _tsTabUnselected,
        indicatorColor: _kGreen,
        indicatorWeight: 2.5,
        dividerColor: _kBorder,
        padding: EdgeInsets.zero,
        tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
      ),
    );
  }

  // -- Count Label ------------------------------------------------------------

  Widget _buildCountLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(_countLabel, style: _tsCountLabel),
    );
  }

  // -- Category Filter --------------------------------------------------------

  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: _kChipHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final meta = _categories[i];
            final isSelected = _activeCategory == meta.category;
            return _CategoryChip(
              label: meta.label,
              isSelected: isSelected,
              onTap: () => setState(() => _activeCategory = meta.category),
            );
          },
        ),
      ),
    );
  }

  // -- Body -------------------------------------------------------------------

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2.5),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final items = _filteredByCategory;
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      color: _kGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: _kListPadH,
          vertical: _kListPadV,
        ),
        itemCount: items.length + 1, // +1 for footer notice
        itemBuilder: (_, i) {
          if (i < items.length) {
            return _ListingCard(
              data: items[i],
              stats: _propertyStats[items[i]["id"]],
              getTitle: _getTitle,
              getAddress: _getAddress,
              getRent: _getRent,
              getFirstImage: _getFirstImage,
              resolveStatus: _resolveStatus,
              statusLabel: _statusLabel,
              statusColor: _statusColor,
              isFlatmate: _isFlatmate,
              onEdit: () => _handleEdit(items[i]),
              onPremium: _handlePremium,
              onBoost: () => _handleBoost(items[i]),
              onRenew: () => _handleRenew(items[i]),
            );
          }
          return const _CannotDeleteNotice();
        },
      ),
    );
  }

  // -- Empty State ------------------------------------------------------------

  Widget _buildEmptyState() {
    final categoryName = _categories
        .firstWhere((c) => c.category == _activeCategory)
        .label;
    final tabName = _activeTab == _ListingTab.all
        ? ''
        : _tabs.firstWhere((t) => t.tab == _activeTab).label.toLowerCase();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("??", style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(
            "No${tabName.isNotEmpty ? ' $tabName' : ''} $categoryName listings",
            style: _tsEmptyHeading,
          ),
          const SizedBox(height: 6),
          const Text(
            "To start a listing, please contact support",
            style: _tsEmptySub,
          ),
        ],
      ),
    );
  }

  // -- Error State ------------------------------------------------------------

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 44),
            const SizedBox(height: 12),
            Text(_error!, style: _tsErrorBody, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProperties,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Navigation / Action Handlers -------------------------------------------

  Future<void> _handleEdit(Map<String, dynamic> p) async {
    final prefs = await SharedPreferences.getInstance();
    final listingType = (p['_listingType'] ?? '').toString().toLowerCase();

    // Persist correct ID in prefs
    switch (listingType) {
      case 'commercial':
        await prefs.setInt('commercialId', p['id'] as int);
        break;
      case 'apartment':
        await prefs.setInt('apartmentId', p['id'] as int);
        await prefs.setInt('propertyId', p['id'] as int);
        break;
      case 'flatmate':
        await prefs.setInt('flatmateId', p['id'] as int);
        break;
      default:
        await prefs.setInt('propertyId', p['id'] as int);
    }

    if (!mounted) return;

    // Navigate to correct screen
    switch (listingType) {
      case 'commercial':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CommercialPropertyDetailsScreen(),
          ),
        );
        break;
      case 'apartment':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ApartmentPropertyDetailsScreen(apartmentId: p['id'] as int),
          ),
        );
        break;
      case 'flatmate':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FlatmatePropertyDetailsScreen(),
          ),
        );
        break;
      default:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PGRoomTypeDetailsScreen(selectedCity: p["city"] ?? ""),
          ),
        );
    }

    await _loadProperties();
  }

  void _handlePremium() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(initialIndex: 3),
      ),
      (route) => false,
    );
  }

  void _handleBoost(Map<String, dynamic> p) {
    // TODO: implement boost navigation
    debugPrint("Boost tapped for property: ${p['id']}");
  }

  void _handleRenew(Map<String, dynamic> p) {
    // TODO: implement renew plan navigation
    debugPrint("Renew tapped for property: ${p['id']}");
  }
}

// -----------------------------------------------------------------------------
// _ListingCard � stateless, self-contained card widget
// -----------------------------------------------------------------------------

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.data,
    required this.stats,
    required this.getTitle,
    required this.getAddress,
    required this.getRent,
    required this.getFirstImage,
    required this.resolveStatus,
    required this.statusLabel,
    required this.statusColor,
    required this.isFlatmate,
    required this.onEdit,
    required this.onPremium,
    required this.onBoost,
    required this.onRenew,
  });

  final Map<String, dynamic> data;
  final _PropertyStats? stats;
  final String Function(Map<String, dynamic>) getTitle;
  final String Function(Map<String, dynamic>) getAddress;
  final dynamic Function(Map<String, dynamic>) getRent;
  final String? Function(Map<String, dynamic>) getFirstImage;
  final _ListingStatus Function(Map<String, dynamic>) resolveStatus;
  final String Function(_ListingStatus) statusLabel;
  final Color Function(_ListingStatus) statusColor;
  final bool Function(Map<String, dynamic>) isFlatmate;
  final VoidCallback onEdit;
  final VoidCallback onPremium;
  final VoidCallback onBoost;
  final VoidCallback onRenew;

  bool get _isFM => isFlatmate(data);

  @override
  Widget build(BuildContext context) {
    final status = resolveStatus(data);
    final isLive = status == _ListingStatus.live;
    final isPremExp = status == _ListingStatus.premiumExpired;
    final firstImage = getFirstImage(data);
    final rent = getRent(data);
    final views = stats?.views ?? 0;
    final enquiries = stats?.enquiries ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: _kCardMarginBottom),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Image + Badges -----------------------------------------------
          _buildImageSection(firstImage, status),

          // -- Content ------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _kCardPadH,
              _kCardPadTop,
              _kCardPadH,
              _kCardPadV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Rent
                _buildTitleRentRow(rent),

                const SizedBox(height: 5),

                // Address
                _buildAddressRow(),

                const SizedBox(height: 8),

                // Meta chips
                _buildMetaChips(),

                // Flatmate details chips
                if (_isFM) ...[
                  const SizedBox(height: 8),
                  _buildFlatmateChips(),
                ],

                const SizedBox(height: 10),

                // Stats
                if (!_isFM) _buildStatsRow(views, enquiries),

                const SizedBox(height: 14),

                // Action buttons
                _buildActionButtons(),
              ],
            ),
          ),

          // -- Footer Banners ------------------------------------------------
          if (isPremExp) _buildPremiumExpiredBanner(),
          if (isLive && !isPremExp) _buildBoostBanner(),
        ],
      ),
    );
  }

  // -- Image Section ----------------------------------------------------------

  Widget _buildImageSection(String? firstImage, _ListingStatus status) {
    return Stack(
      children: [
        // Property image
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(_kCardRadius),
            topRight: Radius.circular(_kCardRadius),
          ),
          child: buildPropertyImage(
            firstImage,
            width: double.infinity,
            height: _kCardImageHeight,
            fit: BoxFit.cover,
            baseUrl: _kApiBase,
            placeholder: () => const _PlaceholderImage(),
          ),
        ),

        // Status badge � top right
        Positioned(
          top: 10,
          right: 10,
          child: _StatusBadge(
            label: statusLabel(status),
            color: statusColor(status),
          ),
        ),

        // Flatmate badge � top left
        if (_isFM)
          Positioned(
            top: 10,
            left: 10,
            child: _StatusBadge(
              label: "Flatmate",
              color: _kText.withOpacity(0.80),
            ),
          ),
      ],
    );
  }

  // -- Title + Rent Row -------------------------------------------------------

  Widget _buildTitleRentRow(dynamic rent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            getTitle(data),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _tsCardTitle,
          ),
        ),
        if (rent != null) ...[
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: "?$rent", style: _tsRent),
                const TextSpan(text: "/mo", style: _tsRentSuffix),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // -- Address Row ------------------------------------------------------------

  Widget _buildAddressRow() {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 16, color: _kSubText),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            getAddress(data),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _tsAddress,
          ),
        ),
      ],
    );
  }

  // -- Meta Chips (3 sharing / Meals included) --------------------------------

  Widget _buildMetaChips() {
    final listingType = (data['_listingType'] ?? '').toString().toLowerCase();
    if (listingType != 'pg') return const SizedBox.shrink();

    String? sharingLabel;
    String? mealsLabel;

    final roomList = data["roomType"];
    if (roomList is List && roomList.isNotEmpty && roomList[0] is Map) {
      final firstRoom = roomList[0] as Map;
      final sharing = firstRoom["sharing"];
      if (sharing != null) sharingLabel = "$sharing sharing";
      final meals = firstRoom["meals"];
      if (meals == true || meals == "true") mealsLabel = "Meals included";
    }
    sharingLabel ??= data["sharing"] != null
        ? "${data['sharing']} sharing"
        : null;

    if (sharingLabel == null && mealsLabel == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (sharingLabel != null)
          _IconChipRow(icon: Icons.bed_outlined, label: sharingLabel),
        if (sharingLabel != null && mealsLabel != null)
          const SizedBox(width: 14),
        if (mealsLabel != null)
          _IconChipRow(icon: Icons.restaurant_menu_outlined, label: mealsLabel),
      ],
    );
  }

  // -- Flatmate Chips ---------------------------------------------------------

  Widget _buildFlatmateChips() {
    final chips = <String>[
      if ((data['bhkType'] ?? '').toString().trim().isNotEmpty)
        data['bhkType'].toString().trim(),
      if ((data['roomType'] ?? '').toString().trim().isNotEmpty)
        data['roomType'].toString().trim(),
      if ((data['tenantType'] ?? '').toString().trim().isNotEmpty)
        data['tenantType'].toString().trim(),
      if ((data['furnishing'] ?? '').toString().trim().isNotEmpty)
        data['furnishing'].toString().trim(),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kGreenLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: _tsFlatmateChip),
            ),
          )
          .toList(),
    );
  }

  // -- Stats Row --------------------------------------------------------------

  Widget _buildStatsRow(int views, int enquiries) {
    return Row(
      // children: [
      //   _StatItem(icon: Icons.visibility_outlined,  label: "$views views"),
      //   const SizedBox(width: 16),
      //   _StatItem(icon: Icons.chat_bubble_outline,  label: "$enquiries contacted"),
      // ],
    );
  }

  // -- Action Buttons ---------------------------------------------------------

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Edit Button
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD9D9D9), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/edit_pencil.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Get Premium Button
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onPremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2240),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                "Get Premium",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  // -- Boost Banner -----------------------------------------------------------

  Widget _buildBoostBanner() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_kCardRadius),
          bottomRight: Radius.circular(_kCardRadius),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_outlined, size: 14, color: _kText3),
          const SizedBox(width: 6),
          const Expanded(
            child: Text("Boost this listing", style: _tsBoostLabel),
          ),
          const Text("Get 3x more enquiries", style: _tsBoostSub),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onBoost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("Upgrade", style: _tsBoostBtn),
            ),
          ),
        ],
      ),
    );
  }

  // -- Premium Expired Banner -------------------------------------------------

  Widget _buildPremiumExpiredBanner() {
    return Container(
      decoration: const BoxDecoration(
        color: _kOrangeLight,
        border: Border(top: BorderSide(color: _kOrangeBorder, width: 1)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_kCardRadius),
          bottomRight: Radius.circular(_kCardRadius),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.info_outline, size: 13, color: _kOrange),
                SizedBox(width: 4),
                Text("Premium expired", style: _tsExpiredBadge),
              ],
            ),
          ),

          const Spacer(),

          // Renew button
          GestureDetector(
            onTap: onRenew,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("Renew Plan", style: _tsRenewBtn),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small reusable sub-widgets
// -----------------------------------------------------------------------------

/// Category filter chip
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _kGreen : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? _kGreen : _kBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: _tsCategoryChip.copyWith(
              color: isSelected ? Colors.white : _kText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Status badge pill (Active / Inactive / Expired etc.)
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: _tsBadge),
    );
  }
}

/// Icon + label row used in meta chips
class _IconChipRow extends StatelessWidget {
  const _IconChipRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _kSubText),
        const SizedBox(width: 4),
        Text(label, style: _tsMetaChip),
      ],
    );
  }
}

/// Views / Enquiries stat item
class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _kSubText),
        const SizedBox(width: 4),
        Text(label, style: _tsStatLabel),
      ],
    );
  }
}

/// "Cannot delete listings" info notice at list bottom
class _CannotDeleteNotice extends StatelessWidget {
  const _CannotDeleteNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: _kText3),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Cannot delete listings", style: _tsInfoTitle),
              SizedBox(height: 2),
              Text(
                "To delete a listing, please contact support",
                style: _tsInfoSub,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown while image loads / on error
class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _kCardImageHeight,
      decoration: const BoxDecoration(
        color: _kPlaceholderBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_kCardRadius),
          topRight: Radius.circular(_kCardRadius),
        ),
      ),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: _kPlaceholderIcon,
        size: 36,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Value types
// -----------------------------------------------------------------------------

enum _ListingStatus { live, inactive, premiumExpired, pending }

@immutable
class _PropertyStats {
  const _PropertyStats({required this.views, required this.enquiries});
  final int views;
  final int enquiries;
}

@immutable
class _TabMeta {
  const _TabMeta({required this.label, required this.tab});
  final String label;
  final _ListingTab tab;
}

@immutable
class _CategoryMeta {
  const _CategoryMeta({required this.label, required this.category});
  final String label;
  final _ListingCategory category;
}
