// ─────────────────────────────────────────────────────────────────────────────
// FlatmateViewDetails.dart
// Listing screen for Flatmate module — matches Prisma Flatmate schema
// Full clean rewrite — A to Z  (with viewscount on cards)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/property_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/FlatmatePropertyDetails.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Flatmate_filter_model.dart';
import 'Flatmate_filter_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const String _kBaseUrl = "https://rentit-backend-omega.vercel.app";
const int _kItemsPerPage = 8;

// ─── Palette ──────────────────────────────────────────────────────────────────

const Color kDark = Color(0xFF1A2B40);
const Color kGreen = Color(0xFF0A7C66);
const Color kGreenLight = Color(0xFFF0FAF4);
const Color kGreenMid = Color(0xFFD1FAE5);
const Color kText = Color(0xFF111827);
const Color kText2 = Color(0xFF4B5563);
const Color kText3 = Color(0xFF9CA3AF);
const Color kBorder = Color(0xFFE5E7EB);
const Color kBg = Color(0xFFF5F6F8);
const Color kCard = Colors.white;
const Color kRed = Color(0xFFEF4444);
const Color kOrange = Color(0xFFF59E0B);

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtShort(int n) {
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
  return n.toString();
}

String _fmtFull(int n) {
  if (n <= 0) return '0';
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  String rest = s.substring(0, s.length - 3);
  String result = '';
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

String _timeAgo(String? d) {
  if (d == null) return '';
  try {
    final diff = DateTime.now().difference(DateTime.parse(d));
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return '$w week${w > 1 ? 's' : ''} ago';
    }
    final m = (diff.inDays / 30).floor();
    return '$m month${m > 1 ? 's' : ''} ago';
  } catch (_) {
    return '';
  }
}

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'FM';
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
}

Color _avatarColor(String? name) {
  const colors = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF5722),
    Color(0xFF795548),
  ];
  if (name == null) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}

// ─── Filter function ──────────────────────────────────────────────────────────

List<dynamic> _applyFilters(List<dynamic> all, FlatmateFilterModel f) {
  List<dynamic> list = List.from(all);

  // City
  if (f.city.isNotEmpty) {
    list = list.where((p) {
      return (p as Map)['city']?.toString().toLowerCase().trim() ==
          f.city.toLowerCase().trim();
    }).toList();
  }

  // Locality / search
  if (f.locality.isNotEmpty) {
    final q = f.locality.toLowerCase();
    list = list.where((p) {
      final m = p as Map;
      return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['street']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['landmark']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  if (f.search.isNotEmpty) {
    final q = f.search.toLowerCase();
    list = list.where((p) {
      final m = p as Map;
      return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['street']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['landmark']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['apartmentName']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['city']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // Tenant type
  if (f.tenantType.isNotEmpty) {
    final want = f.tenantType.toLowerCase();
    list = list.where((p) {
      final t = (p as Map)['tenantType']?.toString().toLowerCase().trim() ?? '';
      if (t.isEmpty || t == 'anyone') return true;
      return t == want;
    }).toList();
  }

  // BHK type
  if (f.bhkType.isNotEmpty) {
    list = list.where((p) {
      return (p as Map)['bhkType']?.toString().trim() == f.bhkType;
    }).toList();
  }

  // Room type
  if (f.roomType.isNotEmpty) {
    final want = f.roomType.toLowerCase().trim();
    list = list.where((p) {
      return (p as Map)['roomType']?.toString().toLowerCase().trim() == want;
    }).toList();
  }

  // Furnishing
  if (f.furnishing.isNotEmpty) {
    list = list.where((p) {
      return (p as Map)['furnishing']?.toString().toLowerCase().trim() ==
          f.furnishing.toLowerCase().trim();
    }).toList();
  }

  // Property type
  if (f.propertyType.isNotEmpty) {
    final Map<String, List<String>> propertyTypeMap = {
      'Apartment': ['Apartment'],
      'Independent House/Villa': [
        'Independent House',
        'Independent House/Villa',
        'Villa',
      ],
      'Gated Community Villa': ['Gated Community Villa'],
    };
    final allowedTypes = propertyTypeMap[f.propertyType] ?? [f.propertyType];
    list = list.where((p) {
      final apartmentType =
          (p as Map<String, dynamic>)['apartmentType']?.toString().trim() ?? '';
      return allowedTypes.any(
        (type) => apartmentType.toLowerCase() == type.toLowerCase(),
      );
    }).toList();
  }

  // Parking
  if (f.parking.isNotEmpty) {
    final want = f.parking.toLowerCase();
    list = list.where((p) {
      final pk = (p as Map)['parking']?.toString().toLowerCase().trim() ?? '';
      if (want == '2 wheeler') return pk == '2 wheeler' || pk == 'both';
      if (want == '4 wheeler') return pk == '4 wheeler' || pk == 'both';
      if (want == 'both') return pk == 'both';
      return true;
    }).toList();
  }

  // Floor
  if (f.floor.isNotEmpty) {
    list = list.where((p) {
      return (p as Map)['floor']?.toString().trim() == f.floor;
    }).toList();
  }

  // Availability
  if (f.availability.isNotEmpty) {
    final now = DateTime.now();
    list = list.where((p) {
      final raw = (p as Map)['availableFrom']?.toString();
      if (raw == null || raw.isEmpty) return true;
      final dt = DateTime.tryParse(raw);
      if (dt == null) return true;
      if (f.availability == 'Immediately') return !dt.isAfter(now);
      if (f.availability == 'Within 15 days')
        return !dt.isAfter(now.add(const Duration(days: 15)));
      if (f.availability == 'Within 30 days')
        return !dt.isAfter(now.add(const Duration(days: 30)));
      return true;
    }).toList();
  }

  // Show only filters
  if (f.showOnly.contains('Non Veg Allowed')) {
    list = list.where((p) => (p as Map)['nonVegAllowed'] == true).toList();
  }
  if (f.showOnly.contains('Gym')) {
    list = list.where((p) => (p as Map)['gym'] == true).toList();
  }
  if (f.showOnly.contains('With Photos')) {
    list = list.where((p) {
      final imgs = (p as Map)['images'];
      return imgs is List && imgs.isNotEmpty;
    }).toList();
  }

  // Rent range
  if (f.rentMin > 0 || (f.rentMax > 0 && f.rentMax < 1000000)) {
    list = list.where((p) {
      final rent =
          double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ?? 0;
      if (rent <= 0) return true;
      final minOk = f.rentMin <= 0 || rent >= f.rentMin;
      final maxOk = f.rentMax <= 0 || f.rentMax >= 1000000 || rent <= f.rentMax;
      return minOk && maxOk;
    }).toList();
  }

  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// FlatmateViewDetailsScreen
// ─────────────────────────────────────────────────────────────────────────────

class FlatmateViewDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, String> queryParams;

  const FlatmateViewDetailsScreen({super.key, this.queryParams = const {}});

  @override
  ConsumerState<FlatmateViewDetailsScreen> createState() =>
      _FlatmateViewDetailsScreenState();
}

class _FlatmateViewDetailsScreenState
    extends ConsumerState<FlatmateViewDetailsScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<dynamic> _flatmates = [];
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  late FlatmateFilterModel _f;

  // ── Quick-filter bar state ────────────────────────────────────────────────
  String _quickPropertyType = '';
  String _quickBhk = '';
  double _quickPriceMax = 0;

  // ── Pagination ────────────────────────────────────────────────────────────
  int _page = 1;

  // ── Saved ─────────────────────────────────────────────────────────────────
  final Map<int, bool> _saved = {};

  // ── Sort ──────────────────────────────────────────────────────────────────
  String _sortBy = 'newest';

  final _scrollCtrl = ScrollController();

  // ═════════════════════════════ LIFECYCLE ═════════════════════════════════

  @override
  void initState() {
    super.initState();
    _f = widget.queryParams.isNotEmpty
        ? FlatmateFilterModel.fromQueryParams(widget.queryParams)
        : const FlatmateFilterModel();
    if (widget.queryParams.containsKey('sort')) {
      _sortBy = widget.queryParams['sort']!;
    }
    _fetchFlatmates();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) {
      setState(() {
        _f = FlatmateFilterModel.fromQueryParams(args);
        _page = 1;
      });
    }
  }

  // ═════════════════════════════ NETWORK ═══════════════════════════════════

  Future<void> _fetchFlatmates() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final currentUserId = prefs.getInt('userId')?.toString();

      final res = await http.get(
        Uri.parse('$_kBaseUrl/flatmate/all'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      final ct = res.headers['content-type'] ?? '';
      if (!ct.contains('application/json')) {
        throw Exception('Server error (${res.statusCode})');
      }

      if (res.statusCode != 200) {
        final msg =
            (jsonDecode(res.body) as Map)['message'] ??
            'Error ${res.statusCode}';
        throw Exception(msg);
      }

      final List<dynamic> all = jsonDecode(res.body) as List<dynamic>;

      // Hide my own posts
      final filtered = all.where((item) {
        final p = item as Map<String, dynamic>;
        String? postUserId = p['userId']?.toString();

        if ((postUserId == null || postUserId.isEmpty) &&
            p['user'] is Map<String, dynamic>) {
          postUserId = (p['user'] as Map<String, dynamic>)['id']?.toString();
        }

        return postUserId != currentUserId;
      }).toList();

      if (!mounted) return;

      setState(() {
        _flatmates = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ═════════════════════════════ COMPUTED ══════════════════════════════════

  List<dynamic> get _filtered {
    List<dynamic> list = _applyFilters(_flatmates, _f);

    // Quick property type filter
    if (_quickPropertyType.isNotEmpty) {
      final selected = _quickPropertyType.trim().toLowerCase();
      list = list.where((p) {
        final apartmentType =
            (p as Map)['apartmentType']?.toString().trim().toLowerCase() ?? '';
        return apartmentType == selected;
      }).toList();
    }

    // Quick BHK filter
    if (_quickBhk.isNotEmpty) {
      final selected = _quickBhk.trim().toUpperCase();
      list = list.where((p) {
        final bhkType =
            (p as Map<String, dynamic>)['bhkType']
                ?.toString()
                .trim()
                .toUpperCase() ??
            '';
        return bhkType == selected;
      }).toList();
    }

    // Quick price max filter
    if (_quickPriceMax > 0) {
      list = list.where((p) {
        final dynamic rawRent = (p as Map<String, dynamic>)['expectedRent'];
        double rent = 0;
        if (rawRent is num) {
          rent = rawRent.toDouble();
        } else if (rawRent != null) {
          final cleaned = rawRent
              .toString()
              .replaceAll(',', '')
              .replaceAll('₹', '')
              .trim();
          rent = double.tryParse(cleaned) ?? 0;
        }
        if (rent <= 0) return false;
        return rent <= _quickPriceMax;
      }).toList();
    }

    // Sort
    list = List.from(list);
    list.sort((a, b) {
      if (_sortBy == 'price-low' || _sortBy == 'price-high') {
        double price(dynamic p) =>
            double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ?? 0;
        return _sortBy == 'price-low'
            ? price(a).compareTo(price(b))
            : price(b).compareTo(price(a));
      }
      final da =
          DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ??
          DateTime(2000);
      final db =
          DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ??
          DateTime(2000);
      return _sortBy == 'newest' ? db.compareTo(da) : da.compareTo(db);
    });

    return list;
  }

  int get _totalPages =>
      (_filtered.length / _kItemsPerPage).ceil().clamp(1, 99999);

  List<dynamic> get _paginated {
    final f = _filtered;
    final start = (_page - 1) * _kItemsPerPage;
    final end = (start + _kItemsPerPage).clamp(0, f.length);
    return start < f.length ? f.sublist(start, end) : [];
  }

  void _scrollTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ═════════════════════════════ ACTIONS ═══════════════════════════════════

  void _openFilters() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FlatmateFilterScreen(
          initial: _f,
          allProperties: _flatmates,
          onApply: (updated) {
            if (!mounted) return;
            setState(() {
              _f = updated;
              _page = 1;
            });
          },
        ),
      ),
    );
  }

  void _openSortSheet() {
    String selected = _sortBy;

    const opts = {
      'relevance': 'Relevance',
      'price-low': 'Price: Low to High',
      'price-high': 'Price: High to Low',
      'newest': 'Newest First',
      'area-large': 'Area: Largest First',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sort Properties',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: kDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Choose how listings should appear',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8A94A6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ...opts.entries.map(
                      (e) => InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setSheetState(() {
                            selected = e.key;
                          });
                        },
                        child: Container(
                          height: 57,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected == e.key
                                  ? kDark
                                  : const Color(0xFFE5E7EB),
                              width: selected == e.key ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected == e.key
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: kDark,
                                  ),
                                ),
                              ),

                              selected == e.key
                                  ? Container(
                                      width: 30,
                                      height: 30,
                                      decoration: const BoxDecoration(
                                        color: kDark,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFD1D5DB),
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sortBy = selected;
                            _page = 1;
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Apply Sort',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
  // ── Quick-filter sheet helpers ────────────────────────────────────────────

  void _openPropertyTypeSheet() => _showSheet(
    'Property Type',
    const [
      'Any',
      'Apartment',
      'Independent House/Villa',
      'Gated Community Villa',
    ],
    (v) => setState(() {
      _quickPropertyType = v;
      _page = 1;
    }),
    currentValue: _quickPropertyType,
  );

  void _openBhkSheet() => _showSheet(
    'BHK Type',
    const ["Any BHK", '1 BHK', '2 BHK', '3 BHK', '4 BHK', '4+ BHK'],
    (v) => setState(() {
      _quickBhk = v;
      _page = 1;
    }),
    currentValue: _quickBhk,
  );

  void _openPriceSheet() {
    const priceOpts = [
      'Any Price',
      '₹5,000',
      '₹8,000',
      '₹12,000',
      '₹20,000',
      '₹30,000',
      '₹50,000',
      '₹1,00,000',
    ];
    const priceMap = {
      '₹5,000': 5000.0,
      '₹8,000': 8000.0,
      '₹12,000': 12000.0,
      '₹20,000': 20000.0,
      '₹30,000': 30000.0,
      '₹50,000': 50000.0,
      '₹1,00,000': 100000.0,
    };
    _showSheet('Max Rent', priceOpts, (v) {
      setState(() {
        _quickPriceMax = priceMap[v] ?? 0;
        _page = 1;
      });
    });
  }

  void _showSheet(
    String title,
    List<String> opts,
    void Function(String) onPick, {
    String currentValue = '',
  }) {
    String selected = currentValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title + Close
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kDark,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: kDark),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Options
                    ...opts.map(
                      (option) => InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setSheetState(() {
                            selected = option;
                          });
                        },
                        child: Container(
                          height: 57,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected == option
                                  ? kDark
                                  : const Color(0xFFE3E3E3),
                              width: selected == option ? 1.8 : 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected == option
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: kDark,
                                  ),
                                ),
                              ),

                              selected == option
                                  ? Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: kDark,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFD4D4D8),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 57,
                      child: ElevatedButton(
                        onPressed: () {
                          onPick(
                            selected == 'Any' ||
                                    selected == 'Any BHK' ||
                                    selected == 'Any price'
                                ? ''
                                : selected,
                          );

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
  // ═════════════════════════════ BUILD ════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _error != null
                ? _buildError()
                : _buildList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, size: 22, color: kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(
      children: [
        const Text(
          'Flatmates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kText,
            letterSpacing: 0.5,
          ),
        ),
        if (!_loading && _error == null)
          Text(
            '${_filtered.length} listing${_filtered.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 11,
              color: kText3,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: kBorder),
    ),
  );

  // ─── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _filterIconBtn(),
          const SizedBox(width: 8),
          _locationPill(),
          const SizedBox(width: 8),
          _quickPill(
            label: _quickPropertyType.isEmpty
                ? 'Property Type'
                : _quickPropertyType,
            active: _quickPropertyType.isNotEmpty,
            onTap: _openPropertyTypeSheet,
          ),
          const SizedBox(width: 8),
          _quickPill(
            label: _quickBhk.isEmpty ? 'BHK' : _quickBhk,
            active: _quickBhk.isNotEmpty,
            onTap: _openBhkSheet,
          ),
          const SizedBox(width: 8),
          _quickPill(
            label: _quickPriceMax > 0
                ? '≤ ₹${_fmtFull(_quickPriceMax.toInt())}'
                : 'Price',
            active: _quickPriceMax > 0,
            onTap: _openPriceSheet,
          ),
        ],
      ),
    ),
  );

  Widget _filterIconBtn() => GestureDetector(
    onTap: _openFilters,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 40,
          decoration: BoxDecoration(
            color: kDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.tune_rounded, size: 18, color: Colors.white),
          ),
        ),
        if (_f.activeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${_f.activeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _locationPill() {
    final label = _f.locality.isNotEmpty
        ? _f.locality
        : _f.city.isNotEmpty
        ? _f.city
        : 'All';
    final isActive = _f.locality.isNotEmpty || _f.city.isNotEmpty;
    return GestureDetector(
      onTap: isActive
          ? () => setState(() {
              _f = _f.copyWith(city: '', locality: '');
              _page = 1;
            })
          : _openFilters,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? kDark : Colors.white,
          border: Border.all(
            color: isActive ? kDark : const Color(0xFF3D3D3D),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 15,
              color: isActive ? Colors.white : kText2,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : kText2,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickPill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? kDark : Colors.white,
        border: Border.all(
          color: active ? kDark : const Color(0xFF3D3D3D),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : kText2,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: active ? Colors.white : kText3,
          ),
        ],
      ),
    ),
  );

  // ─── List ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    final filtered = _filtered;
    final paginated = _paginated;

    if (filtered.isEmpty) return _buildEmpty();

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: paginated.length + (_totalPages > 1 ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == paginated.length) return _buildPagination();
        return _buildCard(paginated[i] as Map<String, dynamic>);
      },
    );
  }

  // ─── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> p) {
    final propertyIdNum = int.tryParse(p['id']?.toString() ?? '') ?? 0;
    // ── ❤️ Read liked state from likeProvider ─────────────────────────────────
    final isSaved =
        propertyIdNum > 0 &&
        ref
            .watch(likeProvider)
            .maybeWhen(
              data: (_) => ref
                  .read(likeProvider.notifier)
                  .isLiked(propertyIdNum, 'flatmate'),
              orElse: () => false,
            );
    // ─────────────────────────────────────────────────────────────────────────
    final images = extractPropertyImages(p, _kBaseUrl);
    final updatedAt = _timeAgo(
      p['updatedAt']?.toString() ?? p['createdAt']?.toString(),
    );
    final rent = double.tryParse(p['expectedRent']?.toString() ?? '') ?? 0;
    final deposit =
        double.tryParse(p['expectedDeposit']?.toString() ?? '') ?? 0;
    final bhk = p['bhkType']?.toString() ?? '';
    final furnishing = formatFurnishing(p['furnishing']);
    final tenantType = p['tenantType']?.toString() ?? '';

    // ── Views count ──────────────────────────────────────────────────────────
    final int views = int.tryParse(p['viewscount']?.toString() ?? '0') ?? 0;

    final locality = [p['locality'], p['city']]
        .where((e) => e != null && e.toString().isNotEmpty)
        .map((e) => e.toString().trim())
        .join(', ');
    final apartmentName = p['apartmentName']?.toString() ?? '';
    final title = apartmentName.isNotEmpty ? apartmentName : 'Flatmate Listing';

    final chips = <String>[
      if (bhk.isNotEmpty) bhk,
      if (furnishing.isNotEmpty) furnishing,
      if (tenantType.isNotEmpty) tenantType,
    ];

    final hasAc = p['acRoom'] == true;
    final hasBalcony = p['balcony'] == true;
    final hasGym = p['gym'] == true;
    final hasLift = p['liftSelected'] == true;
    final hasParking =
        p['parking'] != null &&
        (p['parking']?.toString() ?? '').toLowerCase() != 'none' &&
        (p['parking']?.toString() ?? '').isNotEmpty;

    final amenities = <String>[
      if (hasAc) 'AC',
      if (hasBalcony) 'Balcony',
      if (hasGym) 'Gym',
      if (hasLift) 'Lift',
      if (hasParking) 'Parking',
    ];

    final userObj = p['user'] as Map<String, dynamic>?;
    final ownerName =
        userObj?['name']?.toString() ?? userObj?['fullName']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final propertyId = p['id'];

        if (propertyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Property ID not found'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        print("OPENING PROPERTY => $propertyId");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlatmateDetailScreen(
              propertyId: int.parse(propertyId.toString()),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ─────────────────────────────────────────────────────
            _buildCardImage(p, images, isSaved, propertyIdNum),

            // ── Body ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + locality
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kText,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: kText3,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          locality,
                          style: const TextStyle(fontSize: 12, color: kText3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Chips
                  if (chips.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chips
                          .map(
                            (c) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kText2,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 8),

                  // Amenities
                  if (amenities.isNotEmpty)
                    Row(
                      children:
                          amenities
                              .take(4)
                              .expand(
                                (a) => [
                                  Text(
                                    a,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kText2,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: kText3,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              .toList()
                            ..removeLast(),
                    ),

                  // Rent + deposit
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (rent > 0) ...[
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '₹${_fmtFull(rent.toInt())}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: kText,
                                ),
                              ),
                              const TextSpan(
                                text: ' / mo',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: kText3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      // ── Views count badge ────────────────────────────────
                      if (views > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 13,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$views views',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  if (deposit > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Deposit ₹${_fmtShort(deposit.toInt())}',
                      style: const TextStyle(fontSize: 12, color: kText3),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 12),

                  // Owner row
                  _buildOwnerRow(p, ownerName, updatedAt),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Card image ────────────────────────────────────────────────────────────

  Widget _buildCardImage(
    Map<String, dynamic> p,
    List<dynamic> images,
    bool isSaved,
    int propertyIdNum,
  ) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: images.isNotEmpty
              ? buildPropertyImage(
                  images[0],
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  baseUrl: _kBaseUrl,
                  placeholder: () => _noImage(),
                )
              : _noImage(),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              _circleBtn(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? kRed : kText,
                onTap: () async {
                  if (propertyIdNum > 0) {
                    await ref
                        .read(likeProvider.notifier)
                        .toggle(propertyIdNum, 'flatmate');
                  }
                },
              ),
              const SizedBox(height: 8),
              _circleBtn(
                Icons.share_outlined,
                color: kText,
                onTap: () async {
                  final rent =
                      double.tryParse(p['expectedRent']?.toString() ?? '') ?? 0;
                  final loc = [p['locality'], p['city']]
                      .where(
                        (e) =>
                            e != null &&
                            e.toString().trim().isNotEmpty &&
                            e.toString().toLowerCase() != 'unknown',
                      )
                      .join(', ');
                  final title = p['roomType'] ?? 'Flatmate';
                  final imageUrl = images.isNotEmpty
                      ? images.first.toString()
                      : '';

                  await ShareUtils.shareProperty(
                    title: title.toString(),
                    loc: loc.isEmpty ? 'RentIt' : loc,
                    area: '', // no area for flatmate usually shown
                    rent: rent.toString(),
                    imageUrl: imageUrl,
                    propertyId: propertyIdNum.toString(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleBtn(
    IconData icon, {
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Icon(icon, size: 18, color: color)),
      ),
    ),
  );

  // ─── Owner row ─────────────────────────────────────────────────────────────

  Widget _buildOwnerRow(
    Map<String, dynamic> p,
    String ownerName,
    String updatedAt,
  ) {
    final name = ownerName.isNotEmpty ? ownerName : 'Property Owner';
    final initials = _initials(name);
    final color = _avatarColor(name);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
              ),
              if (updatedAt.isNotEmpty)
                Text(
                  'Updated $updatedAt',
                  style: const TextStyle(fontSize: 11, color: kText3),
                ),
            ],
          ),
        ),
        _iconBtn(Icons.chat_bubble_outline_rounded, onTap: () {}),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final mobile = p['secondaryNumber']?.toString();
            if (mobile != null && mobile.isNotEmpty) {
              final uri = Uri.parse('tel:$mobile');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            }
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: kDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_outlined, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder, width: 1.5),
          ),
          child: Center(child: Icon(icon, size: 18, color: kText2)),
        ),
      );

  // ─── Bottom nav bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: kBorder)),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            _bottomBarBtn(
              icon: Icons.swap_vert_rounded,
              label: 'Sort',
              color: kText2,
              onTap: _openSortSheet,
            ),
            Container(width: 1, height: 36, color: kBorder),
            _bottomBarBtn(
              icon: Icons.tune_rounded,
              label: 'Filters',
              color: kText2,
              badge: _f.activeCount > 0 ? '${_f.activeCount}' : null,
              onTap: _openFilters,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bottomBarBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: color),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: kDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  // ─── Pagination ────────────────────────────────────────────────────────────

  Widget _buildPagination() {
    final total = _totalPages;
    List<int> pages;
    if (total <= 5) {
      pages = List.generate(total, (i) => i + 1);
    } else if (_page <= 3) {
      pages = [1, 2, 3, 4, 5];
    } else if (_page >= total - 2) {
      pages = List.generate(5, (i) => total - 4 + i);
    } else {
      pages = [_page - 2, _page - 1, _page, _page + 1, _page + 2];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageBtn('<', _page > 1, () {
            setState(() => _page--);
            _scrollTop();
          }),
          ...pages.map(
            (n) => _pageBtn(n.toString(), true, () {
              setState(() => _page = n);
              _scrollTop();
            }, active: _page == n),
          ),
          _pageBtn('>', _page < total, () {
            setState(() => _page++);
            _scrollTop();
          }),
        ],
      ),
    );
  }

  Widget _pageBtn(
    String label,
    bool enabled,
    VoidCallback onTap, {
    bool active = false,
  }) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active ? kDark : Colors.white,
        border: Border.all(color: active ? kDark : kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white
                : enabled
                ? kText2
                : kText3,
          ),
        ),
      ),
    ),
  );

  // ─── State screens ─────────────────────────────────────────────────────────

  Widget _noImage() => Container(
    height: 210,
    width: double.infinity,
    decoration: const BoxDecoration(
      color: kGreenLight,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: const Center(
      child: Icon(Icons.home_work_outlined, size: 48, color: kGreenMid),
    ),
  );

  Widget _buildSkeleton() => ListView.builder(
    padding: const EdgeInsets.all(14),
    itemCount: 3,
    itemBuilder: (_, __) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _shim(
            double.infinity,
            210,
            radius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _shim(double.infinity, 16),
                const SizedBox(height: 8),
                _shim(200, 12),
                const SizedBox(height: 12),
                _shim(double.infinity, 40),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shim(double w, double h, {BorderRadius? radius}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFEEEFF1),
      borderRadius: radius ?? BorderRadius.circular(6),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: kText3),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kText2, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchFlatmates,
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: kGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.home_work_outlined, size: 40, color: kGreen),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No listings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 13, color: kText3),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _f = _f.resetFilters();
                _quickPropertyType = '';
                _quickBhk = '';
                _quickPriceMax = 0;
                _page = 1;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Clear All Filters',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
