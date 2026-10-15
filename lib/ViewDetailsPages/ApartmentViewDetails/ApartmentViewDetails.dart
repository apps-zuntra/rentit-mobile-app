// ApartmentViewDetails.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/Apartment_filter_model.dart';
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/Apartment_filter_screen.dart';
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/Apartment_premium_filter_screen.dart';
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/ApartmentPropertyDetails.dart';
import 'package:rentit/core/auth_guard.dart';
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/property_utils.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const String _kBaseUrl = "https://rentit-backend-yti9.onrender.com";
const int _kItemsPerPage = 8;

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────────────────────
const Color kDark = Color(0xFF1A2B40);
const Color kGreen = Color(0xFF0A7C66);
const Color kGreenLight = Color(0xFFF0FAF4);
const Color kGreenMid = Color(0xFFD1FAE5);
const Color kText = Color(0xFF111827);
const Color kText2 = Color(0xFF4B5563);
const Color kText3 = Color(0xFF9CA3AF);
const Color kBorder = Color(0xFFE5E7EB);
const Color kBg = Color(0xFFF5F6F8);
const Color kRed = Color(0xFFEF4444);
const Color kBlue = Color(0xFF3B82F6);
const Color kOrange = Color(0xFFF59E0B);

// ─────────────────────────────────────────────────────────────────────────────
//  JSON / FORMAT HELPERS
// ─────────────────────────────────────────────────────────────────────────────
List<dynamic> _parseList(dynamic val) {
  if (val == null) return [];
  if (val is bool) return [];
  if (val is List) return val;
  if (val is Map) return val.values.toList();
  try {
    final p = jsonDecode(val.toString());
    return p is List ? p : [];
  } catch (_) {
    return [];
  }
}

String _fmtShort(int n) {
  if (n <= 0) return '0';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}k';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

String _fmtFull(int n) {
  if (n <= 0) return '0';
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  int count = 0;
  for (int i = rest.length - 1; i >= 0; i--) {
    buf.write(rest[i]);
    count++;
    if (count == 2 && i != 0) {
      buf.write(',');
      count = 0;
    }
  }
  return '${buf.toString().split('').reversed.join()},$last3';
}

String _timeAgo(String? d) {
  if (d == null) return '';
  try {
    final diff = DateTime.now().difference(DateTime.parse(d));
    final days = diff.inDays;
    if (days == 0) return 'Today';
    if (days == 1) return '1 day ago';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final w = (days / 7).floor();
      return '$w week${w > 1 ? 's' : ''} ago';
    }
    final m = (days / 30).floor();
    return '$m month${m > 1 ? 's' : ''} ago';
  } catch (_) {
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD HELPERS
// ─────────────────────────────────────────────────────────────────────────────
bool _hasAmenity(Map p, String kw) {
  final list = _parseList(
    p['amenities'],
  ).map((e) => e.toString().toLowerCase().replaceAll(' ', '')).toList();
  return list.any((a) => a.contains(kw.toLowerCase().replaceAll(' ', '')));
}

String? _getPrice(Map p) {
  final rent = p['expectedRent'];
  if (rent == null) return null;
  final val = double.tryParse(rent.toString()) ?? 0;
  return val > 0 ? '₹${_fmtShort(val.toInt())}' : null;
}

String _getTitle(Map p) {
  final parts = <String>[
    if (p['bhkType'] != null) p['bhkType'].toString(),
    if (p['apartmentType'] != null) p['apartmentType'].toString(),
    if (p['buildingType'] != null) p['buildingType'].toString(),
  ];
  return parts.isNotEmpty ? parts.join(' ') : 'Apartment';
}

String _getAddress(Map p) {
  final parts = [p['locality'], p['city']]
      .where((e) => e != null && e.toString().trim().isNotEmpty)
      .map((e) => e.toString().trim())
      .toList();
  return parts.isNotEmpty ? parts.join(', ') : (p['street']?.toString() ?? '');
}

String _genderLabel(Map p) {
  final tenants = _parseList(
    p['preferredTenant'],
  ).map((e) => e.toString().toLowerCase().trim()).toList();
  if (tenants.isEmpty) return 'Anyone';
  if (tenants.contains('bachelor male') || tenants.contains('male'))
    return 'Male';
  if (tenants.contains('bachelor female') || tenants.contains('female'))
    return 'Female';
  if (tenants.contains('family')) return 'Family';
  if (tenants.contains('company')) return 'Company';
  return 'Anyone';
}

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'AP';
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
  if (name == null || name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}

// ─────────────────────────────────────────────────────────────────────────────
//  MASTER FILTER FUNCTION  (single source of truth)
// ─────────────────────────────────────────────────────────────────────────────
List<dynamic> applyAllFilters(
  List<dynamic> properties,
  ApartmentFilterModel f,
) {
  List<dynamic> list = List.from(properties);

  // City
  if (f.city.isNotEmpty) {
    list = list
        .where(
          (p) =>
              (p as Map)['city']?.toString().toLowerCase().trim() ==
              f.city.toLowerCase().trim(),
        )
        .toList();
  }

  // Locality / search
  if (f.locality.isNotEmpty) {
    final q = f.locality.toLowerCase();
    list = list.where((p) {
      final m = p as Map;
      return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['landmark']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['street']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  } else if (f.search.isNotEmpty) {
    final q = f.search.toLowerCase();
    list = list.where((p) {
      final m = p as Map;
      return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['landmark']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['bhkType']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['city']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['apartmentType']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // BHK types
  if (f.bhkTypes.isNotEmpty) {
    list = list.where((p) {
      final bhk = (p as Map)['bhkType']?.toString().toLowerCase().trim() ?? '';
      return f.bhkTypes.any(
        (s) =>
            bhk.contains(s.toLowerCase().trim()) ||
            s.toLowerCase().trim().contains(bhk),
      );
    }).toList();
  }

  // Preferred tenant
  if (f.preferredTenant.isNotEmpty) {
    final want = f.preferredTenant.toLowerCase().trim();
    list = list.where((p) {
      final raw = (p as Map)['preferredTenant'];
      final tenants = (raw is List ? raw : (raw != null ? [raw] : []))
          .whereType<String>()
          .map((e) => e.toLowerCase().trim())
          .toList();
      if (tenants.isEmpty) return false;
      return tenants.contains(want) ||
          tenants.contains('anyone') ||
          tenants.contains('any');
    }).toList();
  }

  // Furnishing
  if (f.furnishing.isNotEmpty) {
    final want = f.furnishing.toLowerCase().trim();
    list = list.where((p) {
      final furn =
          (p as Map)['furnishing']?.toString().toLowerCase().trim() ?? '';
      return furn.contains(want);
    }).toList();
  }

  // Availability
  if (f.availability.isNotEmpty) {
    final now = DateTime.now();
    list = list.where((p) {
      final avFrom = (p as Map)['availableFrom']?.toString();
      if (avFrom == null || avFrom.isEmpty) return true;
      final dt = DateTime.tryParse(avFrom);
      if (dt == null) return true;
      if (f.availability == 'Immediately') return !dt.isAfter(now);
      if (f.availability == 'Within 15 days')
        return !dt.isAfter(now.add(const Duration(days: 15)));
      if (f.availability == 'Within 30 days')
        return !dt.isAfter(now.add(const Duration(days: 30)));
      return true;
    }).toList();
  }

  // Parking
  if (f.parking.isNotEmpty) {
    list = list.where((p) {
      final pk = (p as Map)['parking']?.toString().toLowerCase().trim() ?? '';
      final hasParking = pk.isNotEmpty && pk != 'none';
      final noParking = pk.isEmpty || pk == 'none';
      if (f.parking.toLowerCase() == 'yes') return hasParking;
      if (f.parking.toLowerCase() == 'no') return noParking;
      return true;
    }).toList();
  }

  // Rent range
  if (f.rentMin > 0 || (f.rentMax > 0 && f.rentMax < 1000000)) {
    list = list.where((p) {
      final rentRaw = (p as Map)['expectedRent'];
      if (rentRaw == null) return true;

      final rent = double.tryParse(rentRaw.toString()) ?? 0;
      if (rent <= 0) return true;
      final minOk = f.rentMin <= 0 || rent >= f.rentMin;
      final maxOk = f.rentMax <= 0 || f.rentMax >= 1000000 || rent <= f.rentMax;
      return minOk && maxOk;
    }).toList();
  }

  // Built-up area
  if (f.areaMin > 0 || f.areaMax < 10000) {
    list = list.where((p) {
      final areaRaw = (p as Map)['builtUpArea'];
      if (areaRaw == null) return true;
      final area = double.tryParse(areaRaw.toString()) ?? 0;
      if (area <= 0) return true;
      return area >= f.areaMin && area <= f.areaMax;
    }).toList();
  }

  // Property age
  if (f.propertyAges.isNotEmpty) {
    list = list.where((p) {
      final age = (p as Map)['propertyAge']?.toString() ?? '';
      if (age.isEmpty) return true;
      return f.propertyAges.contains(age);
    }).toList();
  }

  // Bathroom
  if (f.bathroom.isNotEmpty) {
    list = list.where((p) {
      final bRaw = (p as Map)['bathroom'];
      if (bRaw == null) return true;
      final count = int.tryParse(bRaw.toString()) ?? 0;
      if (f.bathroom == '1 or more') return count >= 1;
      if (f.bathroom == '2 or more') return count >= 2;
      if (f.bathroom == '3 or more') return count >= 3;
      return true;
    }).toList();
  }

  // Floors
  if (f.floors.isNotEmpty) {
    list = list.where((p) {
      final floorRaw = (p as Map)['floor'];
      if (floorRaw == null) return true;
      final floor = int.tryParse(floorRaw.toString()) ?? -1;
      return f.floors.any((range) {
        if (range == 'Ground') return floor == 0;
        if (range == '1 to 3') return floor >= 1 && floor <= 3;
        if (range == '4 to 6') return floor >= 4 && floor <= 6;
        if (range == '7 to 9') return floor >= 7 && floor <= 9;
        if (range == '10 & above') return floor >= 10;
        return false;
      });
    }).toList();
  }

  // Helper for robust boolean checking
  bool isTrue(dynamic val) => val == true || val == 'true' || val == 1;
  bool isFalseOrNull(dynamic val) =>
      val == false || val == 'false' || val == 0 || val == null;

  // Show only
  if (f.showOnly.isNotEmpty) {
    list = list.where((p) {
      final m = p as Map;
      return f.showOnly.every((opt) {
        if (opt == 'Non Veg Allowed') return isTrue(m['nonVegAllowed']);
        if (opt == 'With Photos') {
          final imgs = m['images'] as List<dynamic>? ?? [];
          return imgs.isNotEmpty;
        }
        if (opt == 'Gym') return isTrue(m['gymAllowed']);
        if (opt == 'Pet Friendly') return isTrue(m['petAllowed']);
        return true;
      });
    }).toList();
  }

  // Amenities
  if (f.amenities.isNotEmpty) {
    list = list.where((p) {
      final ams = _parseList(
        (p as Map)['amenities'],
      ).map((e) => e.toString().toLowerCase().replaceAll(' ', '')).toList();
      return f.amenities.every((key) {
        final k = key.toLowerCase().replaceAll(' ', '');
        return ams.any((a) => a.contains(k));
      });
    }).toList();
  }

  // Restrictions
  if (f.restrictions.isNotEmpty) {
    list = list.where((p) {
      final m = p as Map;
      return f.restrictions.every((key) => isFalseOrNull(m[key]));
    }).toList();
  }

  // Lease only
  if (f.leaseOnly) {
    list = list.where((p) {
      final rt = (p as Map)['rentType']?.toString().toLowerCase() ?? '';
      return rt.contains('lease');
    }).toList();
  }

  return list;
}

// ═════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class ApartmentPropertiesScreen extends ConsumerStatefulWidget {
  final Map<String, String> queryParams;
  const ApartmentPropertiesScreen({super.key, this.queryParams = const {}});

  @override
  ConsumerState<ApartmentPropertiesScreen> createState() =>
      _ApartmentPropertiesScreenState();
}

class _ApartmentPropertiesScreenState
    extends ConsumerState<ApartmentPropertiesScreen> {
  // ── Data ───────────────────────────────────────────────────────────────────
  List<dynamic> _properties = [];
  bool _loading = true;
  String? _error;

  // ── Filter model ───────────────────────────────────────────────────────────
  late ApartmentFilterModel _f;

  // ── Quick filters (pill bar, not persisted in model) ───────────────────────
  String _quickTenant = '';
  String _quickBhk = '';
  double _quickPriceMax = 0;

  // ── Pagination ─────────────────────────────────────────────────────────────
  int _page = 1;

  // ── Sort ───────────────────────────────────────────────────────────────────
  String _sortBy = 'newest';

  // ── Scroll ─────────────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();

  // ─────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _f = widget.queryParams.isNotEmpty
        ? ApartmentFilterModel.fromQueryParams(widget.queryParams)
        : const ApartmentFilterModel();
    if (widget.queryParams.containsKey('sort')) {
      _sortBy = widget.queryParams['sort']!;
    }
    _fetchProperties();
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
        _f = ApartmentFilterModel.fromQueryParams(args);
        _page = 1;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Network
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchProperties() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      final prefs = await SharedPreferences.getInstance();

      // Logged-in user ID
      final currentUserId = prefs.getInt('userId')?.toString();
      print('Current User ID: $currentUserId');

      final res = await http.get(
        Uri.parse('$_kBaseUrl/apartment'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      final ct = res.headers['content-type'] ?? '';
      if (!ct.contains('application/json')) {
        throw Exception('Server returned non-JSON (${res.statusCode})');
      }

      if (res.statusCode != 200) {
        throw Exception(
          (jsonDecode(res.body) as Map)['message'] ?? 'Error ${res.statusCode}',
        );
      }

      final List<dynamic> allProperties = jsonDecode(res.body) as List<dynamic>;

      // Debug all userIds
      for (final item in allProperties) {
        final p = item as Map<String, dynamic>;
        print('Property ID: ${p['id']} | userId: ${p['userId']}');
      }

      // Hide my own posts
      final filtered = allProperties.where((item) {
        final p = item as Map<String, dynamic>;
        final propertyUserId = p['userId']?.toString();
        return propertyUserId != currentUserId;
      }).toList();

      if (!mounted) return;

      setState(() {
        _properties = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Computed lists
  // ─────────────────────────────────────────────────────────────────────────
  List<dynamic> get _filtered {
    List<dynamic> list = applyAllFilters(_properties, _f);

    // Quick filters
    if (_quickTenant.isNotEmpty) {
      list = list
          .where(
            (p) =>
                _genderLabel(p as Map).toLowerCase() ==
                _quickTenant.toLowerCase(),
          )
          .toList();
    }
    if (_quickBhk.isNotEmpty) {
      list = list.where((p) {
        final bhk = (p as Map)['bhkType']?.toString().toLowerCase() ?? '';
        return bhk.contains(_quickBhk.toLowerCase());
      }).toList();
    }
    if (_quickPriceMax > 0) {
      list = list.where((p) {
        final rent =
            double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ?? 0;
        return rent == 0 || rent <= _quickPriceMax;
      }).toList();
    }

    // Sort
    final sort = _f.premiumSort.isNotEmpty ? _f.premiumSort : _sortBy;
    list = List.from(list)
      ..sort((a, b) {
        if (sort == 'price-low' || sort == 'price-high') {
          double price(dynamic p) =>
              double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ??
              0;
          return sort == 'price-low'
              ? price(a).compareTo(price(b))
              : price(b).compareTo(price(a));
        }
        final da =
            DateTime.tryParse((a as Map)['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        final db =
            DateTime.tryParse((b as Map)['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        return (sort == 'newest' || sort == 'new' || sort == 'recent')
            ? db.compareTo(da)
            : da.compareTo(db);
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

  // ─────────────────────────────────────────────────────────────────────────
  //  Open filter screens
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _openFilters() async {
    final result = await Navigator.push<ApartmentFilterModel>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ApartmentFilterScreen(
          initial: _f,
          allProperties: _properties,
          onApply: (updated) => Navigator.pop(context, updated),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _f = result;
        _page = 1;
      });
    }
  }

  Future<void> _openPremiumFilters() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ApartmentPremiumFilterScreen(
          initial: _f,
          allProperties: _properties,
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
    const Color kNavy = Color(0xFF1A2B47);

    const options = {
      'relevance': 'Relevance',
      'price-low': 'Price: Low to High',
      'price-high': 'Price: High to Low',
      'newest': 'Newest First',
      'area': 'Area: Largest First',
    };

    String selectedSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8D6D2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Header
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sort Properties',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose how listings should appear',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF8A93A5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F2F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 24,
                                color: kNavy,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      ...options.entries.map((e) {
                        final selected = selectedSort == e.key;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setSheetState(() {
                                selectedSort = e.key;
                              });
                            },
                            child: Container(
                              height: 57, // Required Height
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFF5F4F2),
                                borderRadius: BorderRadius.circular(18),
                                border: selected
                                    ? Border.all(color: kNavy, width: 1.8)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: kNavy,
                                      ),
                                    ),
                                  ),

                                  selected
                                      ? Container(
                                          width: 34,
                                          height: 34,
                                          decoration: const BoxDecoration(
                                            color: kNavy,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        )
                                      : Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Color(0xFFC9CED7),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _sortBy = selectedSort;
                              _page = 1;
                            });

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNavy,
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
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Quick-filter dropdown sheets
  // ─────────────────────────────────────────────────────────────────────────
  void _openTenantSheet() => _showPickerSheet(
    title: 'Preferred Tenant',
    opts: ['Any', 'Family', 'Company', 'Male', 'Female'],
    selectedValue: _quickTenant.isEmpty ? 'Any' : _quickTenant,
    onPick: (v) => setState(() {
      _quickTenant = v == 'Any' ? '' : v;
      _page = 1;
    }),
  );

  void _openBhkSheet() => _showPickerSheet(
    title: 'BHK Type',
    opts: ['Any', '1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK', '4+ BHK'],
    selectedValue: _quickBhk.isEmpty ? 'Any' : _quickBhk,
    onPick: (v) => setState(() {
      _quickBhk = v == 'Any' ? '' : v;
      _page = 1;
    }),
  );

  void _openPriceSheet() {
    String selected = _quickPriceMax == 0
        ? 'Any price'
        : _quickPriceMax == 10000
        ? 'Under ₹10,000'
        : _quickPriceMax == 20000
        ? '₹10k – ₹20k'
        : _quickPriceMax == 40000
        ? '₹20k – ₹40k'
        : 'Above ₹40k';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Price Range',
                            style: TextStyle(
                              fontSize: 16,
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
                            child: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ...[
                      'Any price',
                      'Under ₹10,000',
                      '₹10k – ₹20k',
                      '₹20k – ₹40k',
                      'Above ₹40k',
                    ].map(
                      (option) => _priceOption(
                        title: option,
                        selected: selected == option,
                        onTap: () {
                          setSheetState(() {
                            selected = option;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 57,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            switch (selected) {
                              case 'Under ₹10,000':
                                _quickPriceMax = 10000;
                                break;

                              case '₹10k – ₹20k':
                                _quickPriceMax = 20000;
                                break;

                              case '₹20k – ₹40k':
                                _quickPriceMax = 40000;
                                break;

                              case 'Above ₹40k':
                                _quickPriceMax = 50000;
                                break;

                              default:
                                _quickPriceMax = 0;
                            }

                            _page = 1;
                          });

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

  void _showPickerSheet({
    required String title,
    required List<String> opts,
    String selectedValue = '',
    required void Function(String) onPick,
  }) {
    const Color kNavy = Color(0xFF1A2B47);

    String current = selectedValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8D6D2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Choose your preferred option',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF8A93A5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F2F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 24,
                                color: kNavy,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Options
                      ...opts.map((option) {
                        final selected = current == option;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setSheetState(() {
                                current = option;
                              });
                            },
                            child: Container(
                              height: 57,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFF5F4F2),
                                borderRadius: BorderRadius.circular(18),
                                border: selected
                                    ? Border.all(color: kNavy, width: 1.6)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: kNavy,
                                      ),
                                    ),
                                  ),

                                  selected
                                      ? Container(
                                          width: 34,
                                          height: 34,
                                          decoration: const BoxDecoration(
                                            color: kNavy,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFC8CDD6),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 18),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            onPick(current);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNavy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Apply',
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
              ),
            );
          },
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_f.hasPremiumFilters) _buildPremiumBadge(),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _error != null
                ? _buildError()
                : _buildList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  APP BAR
  // ─────────────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, size: 22, color: kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'APARTMENTS',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: kText,
            letterSpacing: 2,
          ),
        ),
        if (!_loading && _error == null)
          Text(
            '${_filtered.length} propert${_filtered.length == 1 ? 'y' : 'ies'} found',
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

  // ─────────────────────────────────────────────────────────────────────────
  //  FILTER PILL BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _filterIconPill(),
          const SizedBox(width: 8),
          _locationPill(),
          const SizedBox(width: 8),
          _pill(
            label: _quickTenant.isEmpty ? 'Tenant' : _quickTenant,
            active: _quickTenant.isNotEmpty,
            onTap: _openTenantSheet,
          ),
          const SizedBox(width: 8),
          _pill(
            label: _quickBhk.isEmpty ? 'BHK' : _quickBhk,
            active: _quickBhk.isNotEmpty,
            onTap: _openBhkSheet,
          ),
          const SizedBox(width: 8),
          _pill(
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

  Widget _priceOption({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 57,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1A2B40) : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF1A2B40),
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // Right Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF1A2B40) : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1A2B40)
                      : const Color(0xFFD6D6D6),
                  width: 1.4,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterIconPill() => GestureDetector(
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
            right: -6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${_f.activeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
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
        : 'All Areas';
    final isActive = _f.locality.isNotEmpty || _f.city.isNotEmpty;
    return GestureDetector(
      onTap: isActive
          ? () => setState(() {
              _f = _f.copyWith(city: '', locality: '');
              _page = 1;
            })
          : null,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? kDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? kDark : const Color(0xFF3D3D3D),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14,
              color: isActive ? Colors.white : kText2,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : kText2,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.close_rounded,
                size: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill({
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? kDark : const Color(0xFF3D3D3D),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : kText2,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: active ? Colors.white : kText3,
          ),
        ],
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  PREMIUM FILTER BADGE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPremiumBadge() => GestureDetector(
    onTap: _openPremiumFilters,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: kOrange.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(CupertinoIcons.sparkles, color: kOrange, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_f.premiumCount} premium filter${_f.premiumCount == 1 ? '' : 's'} active — tap to edit',
              style: const TextStyle(
                color: kOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _f = _f.resetPremiumFilters();
              _page = 1;
            }),
            child: const Icon(Icons.close_rounded, color: kOrange, size: 16),
          ),
        ],
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  LIST
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildList() {
    final paginated = _paginated;
    if (_filtered.isEmpty) return _buildEmpty();
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

  // ─────────────────────────────────────────────────────────────────────────
  //  PROPERTY CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final propertyId = int.tryParse(id) ?? 0;

    // ── ❤️ Read liked state from likeProvider ─────────────────────────────────
    final isSaved =
        propertyId > 0 &&
        ref
            .watch(likeProvider)
            .maybeWhen(
              data: (_) => ref
                  .read(likeProvider.notifier)
                  .isLiked(propertyId, 'apartment'),
              orElse: () => false,
            );
    // ─────────────────────────────────────────────────────────────────────────

    final images = extractPropertyImages(p, _kBaseUrl);
    final price = _getPrice(p);
    final userObj = p['user'] as Map<String, dynamic>?;
    final ownerName =
        userObj?['name']?.toString() ?? userObj?['username']?.toString() ?? '';
    final updatedAt = _timeAgo(
      p['updatedAt']?.toString() ?? p['createdAt']?.toString(),
    );

    final int views = int.tryParse('${p['viewscount'] ?? 0}') ?? 0;

    final amenityTags = <String>[
      if (_hasAmenity(p, 'wifi')) 'WiFi',
      if (_hasAmenity(p, 'lift')) 'Lift',
      if (_hasAmenity(p, 'ac')) 'AC',
      if (_hasAmenity(p, 'gym')) 'Gym',
      if (_hasAmenity(p, 'power')) 'Power Backup',
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final rawId = p['id'];
        if (rawId == null) return;
        final numId = int.tryParse(rawId.toString());
        if (numId == null || numId <= 0) return;
        AuthGuard.protect(
          context,
          onAuthenticated: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ApartmentPropertyDetailScreen(propertyId: numId),
              ),
            ).then((_) {
              _fetchProperties();
            });
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
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
            // ── Image ────────────────────────────────────────────────────────
            _buildCardImage(p, images, isSaved, propertyId, ref),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _getTitle(p),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kText,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Address
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
                          _getAddress(p),
                          style: const TextStyle(fontSize: 12, color: kText3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tenant / furnishing / age badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _badge(
                        _genderLabel(p),
                        bg: const Color(0xFFF3F4F6),
                        color: kText2,
                      ),
                      if (formatFurnishing(p['furnishing']).isNotEmpty)
                        _badge(
                          formatFurnishing(p['furnishing']),
                          bg: const Color(0xFFEFF6FF),
                          color: kBlue,
                        ),
                      if (p['propertyAge'] != null)
                        _badge(
                          p['propertyAge'].toString(),
                          bg: const Color(0xFFFFF7ED),
                          color: kOrange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Amenity tags
                  if (amenityTags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: [
                        for (
                          int i = 0;
                          i < amenityTags.take(4).length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Text(
                              '·',
                              style: TextStyle(fontSize: 12, color: kText3),
                            ),
                          Text(
                            amenityTags[i],
                            style: const TextStyle(
                              fontSize: 12,
                              color: kText2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Price
                  if (price != null) ...[
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: kText,
                            ),
                          ),
                          const TextSpan(
                            text: ' / month',
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

                  // Deposit
                  if (p['deposit'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Deposit: ₹${_fmtFull(int.tryParse(p['deposit'].toString()) ?? 0)}',
                      style: const TextStyle(fontSize: 12, color: kText3),
                    ),
                  ],

                  const SizedBox(height: 10),
                  _buildDetailPills(p),
                  const SizedBox(height: 14),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _fmtShort(views),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildOwnerRow(p, ownerName, updatedAt),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, {required Color bg, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  //  DETAIL PILL ROW  (bhk / floor / area / bath)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDetailPills(Map<String, dynamic> p) {
    final parts = <String>[
      if (p['bhkType'] != null) p['bhkType'].toString(),
      if (p['floor'] != null) 'Floor ${p['floor']}',
      if (p['builtUpArea'] != null) '${p['builtUpArea']} sq.ft',
      if (p['bathroom'] != null) '${p['bathroom']} Bath',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: parts
            .map(
              (part) => Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder, width: 1.5),
                ),
                child: Text(
                  part,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kText2,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CARD IMAGE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardImage(
    Map<String, dynamic> p,
    List<dynamic> images,
    bool isSaved,
    int propertyId,
    WidgetRef ref, // ✅ add this
  ) => Stack(
    children: [
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: images.isNotEmpty
            ? buildPropertyImage(
                images[0],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                baseUrl: _kBaseUrl,
                placeholder: () => _noImgPlaceholder(),
              )
            : _noImgPlaceholder(),
      ),

      // Photo count badge
      Positioned(
        bottom: 10,
        left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '${images.isNotEmpty ? 1 : 0}/${images.isNotEmpty ? images.length : 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),

      // Save + share
      Positioned(
        top: 10,
        right: 10,
        child: Column(
          children: [
            // ── ❤️ Like button using likeProvider ──────────────────────
            _circleBtn(
              icon: isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved ? kRed : Colors.black,
              onTap: () async {
                await ref
                    .read(likeProvider.notifier)
                    .toggle(propertyId, 'apartment');
              },
            ),
            // ────────────────────────────────────────────────────────────
            const SizedBox(height: 8),
            _circleBtn(
              icon: Icons.share_outlined,
              color: kText,
              onTap: () async {
                final typeParts = [
                  p['bhkType'],
                  p['apartmentType'],
                ].where((e) => e != null && e.toString().trim().isNotEmpty);
                final title = typeParts.isNotEmpty
                    ? typeParts.join(' ')
                    : (p['propertyType'] ?? 'Property');

                final area = p['builtUpArea'] ?? p['plotArea'] ?? '';
                final loc = [p['locality'], p['city']]
                    .where(
                      (e) =>
                          e != null &&
                          e.toString().trim().isNotEmpty &&
                          e.toString().toLowerCase() != 'unknown',
                    )
                    .join(', ');
                final price = p['expectedRent'] ?? p['rent'] ?? '';
                final imageUrl = images.isNotEmpty
                    ? images.first.toString()
                    : '';

                await ShareUtils.shareProperty(
                  title: title.toString(),
                  loc: loc.isEmpty ? 'RentIt' : loc,
                  area: area.toString(),
                  rent: price.toString(),
                  imageUrl: imageUrl,
                  propertyId: propertyId.toString(),
                );
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
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

  // ─────────────────────────────────────────────────────────────────────────
  //  OWNER ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOwnerRow(
    Map<String, dynamic> p,
    String ownerName,
    String updatedAt,
  ) {
    final initials = _initials(ownerName.isNotEmpty ? ownerName : null);

    final avatarColor = _avatarColor(ownerName.isNotEmpty ? ownerName : null);

    final displayName = ownerName.isNotEmpty ? ownerName : 'Property Owner';

    final phone =
        p['secondaryNumber']?.toString() ??
        (p['user'] as Map<String, dynamic>?)?['phone']?.toString();

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
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
                displayName,
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

        // ───── CHAT BUTTON ─────
        _iconSquareBtn(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () async {
            print("PROPERTY DATA => $p");
            print("PHONE => $phone");

            if (phone == null || phone.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Phone number not available")),
              );
              return;
            }

            final uri = Uri(scheme: 'tel', path: phone.trim());

            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),

        const SizedBox(width: 8),

        GestureDetector(
          onTap: () async {
            print("CONTACT CLICKED");
            print("PROPERTY => $p");

            final phone =
                p['mobile']?.toString() ??
                p['mobileNo']?.toString() ??
                p['phone']?.toString() ??
                p['secondaryNumber']?.toString() ??
                (p['user'] as Map<String, dynamic>?)?['mobile']?.toString() ??
                (p['user'] as Map<String, dynamic>?)?['phone']?.toString();

            print("USER => ${p['user']}");
            print("PHONE => $phone");

            if (phone == null || phone.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Phone number not available")),
              );
              return;
            }

            final uri = Uri(scheme: 'tel', path: phone.trim());

            await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Widget _iconSquareBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
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
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  BOTTOM NAV  (Sort | Premium | Filters)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
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
            // Sort
            Expanded(
              child: GestureDetector(
                onTap: _openSortSheet,
                behavior: HitTestBehavior.opaque,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 20, color: kText2),
                    SizedBox(height: 2),
                    Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kText2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 36, color: kBorder),

            // Premium
            Expanded(
              child: GestureDetector(
                onTap: _openPremiumFilters,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          CupertinoIcons.sparkles,
                          size: 20,
                          color: kOrange,
                        ),
                        if (_f.hasPremiumFilters)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: kOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 36, color: kBorder),

            // Filters
            Expanded(
              child: GestureDetector(
                onTap: _openFilters,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.tune_rounded, size: 20, color: kText2),
                        if (_f.activeCount > 0)
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
                                  '${_f.activeCount}',
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
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kText2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  PAGINATION
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  //  STATE WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _noImgPlaceholder() => Container(
    height: 220,
    width: double.infinity,
    decoration: const BoxDecoration(
      color: kGreenLight,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: const Center(
      child: Icon(Icons.apartment_outlined, size: 48, color: kGreenMid),
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
          _shimmer(
            double.infinity,
            220,
            radius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _shimmer(double.infinity, 16),
                const SizedBox(height: 8),
                _shimmer(200, 12),
                const SizedBox(height: 12),
                _shimmer(double.infinity, 40),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shimmer(double w, double h, {BorderRadius? radius}) => Container(
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
            onPressed: _fetchProperties,
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
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
              child: Icon(Icons.apartment_outlined, size: 40, color: kGreen),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No apartments found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting or clearing your filters',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kText3),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {
              _f = _f.resetFilters();
              _quickTenant = '';
              _quickBhk = '';
              _quickPriceMax = 0;
              _page = 1;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
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
