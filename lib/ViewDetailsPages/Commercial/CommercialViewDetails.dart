// CommercialViewDetails.dart
// A-to-Z Full Clean Code
// Backend: NestJS + Prisma | Flutter UI

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/property_utils.dart';
import 'package:rentit/ViewDetailsPages/Commercial/Commercial_filter_model.dart';
import 'package:rentit/ViewDetailsPages/Commercial/Commercial_filter_screen.dart';
import 'package:rentit/ViewDetailsPages/Commercial/Commercial_premium_filter_screen.dart';
import 'package:rentit/ViewDetailsPages/Commercial/CommercialPropertyDetails.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const String kBaseUrl = "https://rentit-backend-omega.vercel.app";
const int kItemsPerPage = 8;

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
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
const Color kCard = Colors.white;
const Color kRed = Color(0xFFEF4444);
const Color kBlue = Color(0xFF3B82F6);
const Color kOrange = Color(0xFFF59E0B);

// ─────────────────────────────────────────────────────────────────────────────
// JSON HELPERS
// ─────────────────────────────────────────────────────────────────────────────
List<dynamic> parseJsonList(dynamic val) {
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

String formatIndian(int n) {
  if (n <= 0) return '0';
  if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
  return n.toString();
}

String formatIndianFull(int n) {
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

String timeAgo(String? d) {
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
// FLOOR RANGE HELPER
// ─────────────────────────────────────────────────────────────────────────────
bool _floorInRange(dynamic floorVal, String range) {
  final floor = int.tryParse(floorVal?.toString() ?? '');
  if (floor == null) return false;
  switch (range) {
    case 'Ground':
      return floor == 0;
    case '1 - 5':
      return floor >= 1 && floor <= 5;
    case '6 - 10':
      return floor >= 6 && floor <= 10;
    case '11 - 20':
      return floor >= 11 && floor <= 20;
    case '21 - 50':
      return floor >= 21 && floor <= 50;
    case '51 & above':
      return floor >= 51;
    default:
      return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FURNISHING HELPER
// ─────────────────────────────────────────────────────────────────────────────
String _furnishingValue(dynamic val) {
  if (val == null) return '';
  if (val is String) return val.toLowerCase();
  final list = parseJsonList(val);
  return list.isNotEmpty ? list.first.toString().toLowerCase() : '';
}

// ─────────────────────────────────────────────────────────────────────────────
// AMENITY HELPER
// ─────────────────────────────────────────────────────────────────────────────
bool _hasAmenity(Map p, String backendKey) {
  final of = p['otherFeatures'];
  Map<String, dynamic> features = {};

  if (of is Map<String, dynamic>) {
    features = of;
  } else if (of is Map) {
    features = Map<String, dynamic>.from(of);
  } else if (of is String) {
    try {
      final decoded = jsonDecode(of);
      if (decoded is Map<String, dynamic>) features = decoded;
    } catch (_) {}
  }

  if (features.isEmpty) return false;
  final val = features[backendKey];
  if (val == null) return false;
  final str = val.toString().toLowerCase().trim();
  return str.isNotEmpty && str != 'none' && str != 'no' && str != 'false';
}

// ─────────────────────────────────────────────────────────────────────────────
// MASTER FILTER FUNCTION
// ─────────────────────────────────────────────────────────────────────────────
List<dynamic> applyCommercialFilters(
  List<dynamic> properties,
  CommercialFilterModel f,
) {
  List<dynamic> list = List.from(properties);

  // City
  if (f.city.isNotEmpty) {
    list = list.where((p) {
      final city = (p as Map)['city']?.toString().toLowerCase().trim() ?? '';
      return city == f.city.toLowerCase().trim();
    }).toList();
  }

  // Locality / free-text search
  if (f.locality.isNotEmpty) {
    final q = f.locality.toLowerCase().trim();
    list = list.where((p) {
      final m = p as Map<String, dynamic>;
      final locality = (m['locality'] ?? '').toString().toLowerCase();
      final street = (m['street'] ?? '').toString().toLowerCase();
      final landmark = (m['landmark'] ?? '').toString().toLowerCase();
      final city = (m['city'] ?? '').toString().toLowerCase();
      return locality.contains(q) ||
          street.contains(q) ||
          landmark.contains(q) ||
          city.contains(q);
    }).toList();
  } else if (f.search.isNotEmpty) {
    final q = f.search.toLowerCase().trim();
    list = list.where((p) {
      final m = p as Map<String, dynamic>;
      final locality = (m['locality'] ?? '').toString().toLowerCase();
      final street = (m['street'] ?? '').toString().toLowerCase();
      final landmark = (m['landmark'] ?? '').toString().toLowerCase();
      final city = (m['city'] ?? '').toString().toLowerCase();
      final propertyType = (m['commercialPropertyType'] ?? '')
          .toString()
          .toLowerCase();
      final buildingType = (m['buildingType'] ?? '').toString().toLowerCase();
      return locality.contains(q) ||
          street.contains(q) ||
          landmark.contains(q) ||
          city.contains(q) ||
          propertyType.contains(q) ||
          buildingType.contains(q);
    }).toList();
  }

  // Parking
  if (f.parking.isNotEmpty) {
    list = list.where((p) {
      final otherFeatures = (p as Map)['otherFeatures'];
      if (otherFeatures == null) return false;
      Map<String, dynamic> features = {};
      try {
        features = otherFeatures is Map<String, dynamic>
            ? otherFeatures
            : Map<String, dynamic>.from(jsonDecode(otherFeatures.toString()));
      } catch (_) {
        return false;
      }
      final parking =
          features['parking']?.toString().trim().toLowerCase() ?? '';
      final selected = f.parking.trim().toLowerCase();
      return parking == selected;
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

  // Commercial property type
  if (f.commercialPropertyType.isNotEmpty) {
    final q = f.commercialPropertyType.toLowerCase();
    list = list.where((p) {
      final t =
          (p as Map)['commercialPropertyType']?.toString().toLowerCase() ?? '';
      return t == q;
    }).toList();
  }

  // Building type
  if (f.buildingType.isNotEmpty) {
    final q = f.buildingType.toLowerCase();
    list = list.where((p) {
      final t = (p as Map)['buildingType']?.toString().toLowerCase() ?? '';
      return t == q;
    }).toList();
  }

  // Property age
  if (f.propertyAge.isNotEmpty) {
    final q = f.propertyAge.toLowerCase();
    list = list.where((p) {
      final a = (p as Map)['propertyAge']?.toString().toLowerCase() ?? '';
      return a == q;
    }).toList();
  }

  // Floor range
  if (f.floorRange.isNotEmpty) {
    list = list.where((p) {
      return _floorInRange((p as Map)['floor'], f.floorRange);
    }).toList();
  }

  // Furnishing
  if (f.furnishing.isNotEmpty) {
    final q = f.furnishing.toLowerCase();
    list = list.where((p) {
      final fv = _furnishingValue((p as Map)['furnishing']);
      return fv.contains(q);
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

  // Premium: Amenities
  if (f.amenities.isNotEmpty) {
    list = list.where((p) {
      return f.amenities.every((key) => _hasAmenity(p as Map, key));
    }).toList();
  }

  // Premium: Floor (nearby multi-select)
  if (f.nearby.isNotEmpty) {
    list = list.where((p) {
      return f.nearby.any((range) => _floorInRange((p as Map)['floor'], range));
    }).toList();
  }

  // Premium: Property age (restrictions)
  if (f.restrictions.isNotEmpty) {
    list = list.where((p) {
      final a = (p as Map)['propertyAge']?.toString() ?? '';
      return f.restrictions.any((r) => a.toLowerCase() == r.toLowerCase());
    }).toList();
  }

  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// CommercialPropertiesScreen
// ─────────────────────────────────────────────────────────────────────────────
class CommercialPropertiesScreen extends ConsumerStatefulWidget {
  final Map<String, String> queryParams;
  const CommercialPropertiesScreen({super.key, this.queryParams = const {}});

  @override
  ConsumerState<CommercialPropertiesScreen> createState() =>
      _CommercialPropertiesScreenState();
}

class _CommercialPropertiesScreenState
    extends ConsumerState<CommercialPropertiesScreen> {
  // ── Data ───────────────────────────────────────────────────────────────────
  List<dynamic> _properties = [];
  bool _loading = true;
  String? _error;

  // ── Filters ────────────────────────────────────────────────────────────────
  late CommercialFilterModel _f;

  // ── Pagination ─────────────────────────────────────────────────────────────
  int _page = 1;

  // ── Sort ───────────────────────────────────────────────────────────────────
  String _sortBy = 'newest';

  // ── Saved (local bookmarks) ────────────────────────────────────────────────
  final Map<String, bool> _saved = {};

  final ScrollController _scrollCtrl = ScrollController();

  // ── Quick filter pills ─────────────────────────────────────────────────────
  String _quickPropertyType = '';
  double _quickPriceMax = 0;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _f = widget.queryParams.isNotEmpty
        ? CommercialFilterModel.fromQueryParams(widget.queryParams)
        : CommercialFilterModel();
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
        _f = CommercialFilterModel.fromQueryParams(args);
        _page = 1;
      });
    }
  }

  // ── Token ──────────────────────────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ── Fetch Properties ───────────────────────────────────────────────────────
  Future<void> _fetchProperties() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      final prefs = await SharedPreferences.getInstance();
      final myId = prefs.getInt('userId');

      final res = await http.get(
        Uri.parse('$kBaseUrl/commercial'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        throw Exception('Failed to load properties (${res.statusCode})');
      }

      final data = jsonDecode(res.body);

      setState(() {
        final all = data is List ? data : <dynamic>[];
        // Temporarily showing all listings (including user's own) as requested
        _properties = all.where((p) {
          final uid = int.tryParse(
            (p as Map<String, dynamic>)['userId']?.toString() ?? '',
          );
          return true; // uid != myId;
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  // ── Computed list ──────────────────────────────────────────────────────────
  List<dynamic> get _filtered {
    List<dynamic> list = applyCommercialFilters(_properties, _f);

    // Quick filter: property type pill
    if (_quickPropertyType.isNotEmpty) {
      final q = _quickPropertyType.toLowerCase();
      list = list.where((p) {
        final t =
            (p as Map)['commercialPropertyType']?.toString().toLowerCase() ??
            '';
        return t.contains(q);
      }).toList();
    }

    // Quick filter: max rent pill
    if (_quickPriceMax > 0) {
      list = list.where((p) {
        final rent =
            double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ?? 0;
        return rent <= _quickPriceMax;
      }).toList();
    }

    // Sort
    list = List.from(list);
    list.sort((a, b) {
      if (_sortBy == 'price-low' || _sortBy == 'price-high') {
        final pa =
            double.tryParse((a as Map)['expectedRent']?.toString() ?? '') ?? 0;
        final pb =
            double.tryParse((b as Map)['expectedRent']?.toString() ?? '') ?? 0;
        return _sortBy == 'price-low' ? pa.compareTo(pb) : pb.compareTo(pa);
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
      (_filtered.length / kItemsPerPage).ceil().clamp(1, 99999);

  List<dynamic> get _paginated {
    final f = _filtered;
    final start = (_page - 1) * kItemsPerPage;
    final end = (start + kItemsPerPage).clamp(0, f.length);
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

  // ── Open Filters ───────────────────────────────────────────────────────────
  Future<void> _openFilters() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CommercialFilterScreen(
          initial: _f,
          allProperties: _properties,
          onApply: (CommercialFilterModel updated) {
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

  Future<void> _openPremiumFilters() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CommercialPremiumFilterScreen(
          initial: _f,
          allProperties: _properties,
          onApply: (CommercialFilterModel updated) {
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

  // ── Sort Sheet ─────────────────────────────────────────────────────────────
  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        const opts = {
          'relevance': 'Relevance',
          'price-low': 'Price: Low to High',
          'price-high': 'Price: High to Low',
          'newest': 'Newest First',
          'area': 'Area: Largest First',
        };

        String tempSort = _sortBy;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 54,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8D4CF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF13294B),
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
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F3F3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 24,
                              color: Color(0xFF13294B),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Sort Options
                    ...opts.entries.map((e) {
                      final selected = tempSort == e.key;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setModalState(() {
                              tempSort = e.key;
                            });
                          },
                          child: Container(
                            height: 57, // <-- Requested Height
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFF5F4F2),
                              borderRadius: BorderRadius.circular(18),
                              border: selected
                                  ? Border.all(
                                      color: const Color(0xFF13294B),
                                      width: 1.8,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: const Color(0xFF13294B),
                                    ),
                                  ),
                                ),

                                selected
                                    ? Container(
                                        width: 34,
                                        height: 34,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF13294B),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    : Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Color(0xFFC8CDD6),
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

                    const SizedBox(height: 10),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sortBy = tempSort;
                            _page = 1;
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF13294B),
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

  // ── Quick Filter Dropdowns ────────────────────────────────────────────────
  void _openPropertyTypeDropdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _dropdownSheet(
        'Property Type',
        [
          'Any',
          'Office Space',
          'Co-Working',
          'Shop',
          'Showroom',
          'Godown/Warehouse',
          'Industrial Shed',
          'Industrial Building',
          'Other Business',
        ],
        (v) => setState(() {
          _quickPropertyType = v == 'Any' ? '' : v;
          _page = 1;
        }),
      ),
    );
  }

  void _openPriceDropdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _dropdownSheet(
        'Max Rent',
        ['Any', '₹10,000', '₹25,000', '₹50,000', '₹1,00,000', '₹2,00,000+'],
        (v) {
          double max = 0;
          if (v == '₹10,000') max = 10000;
          if (v == '₹25,000') max = 25000;
          if (v == '₹50,000') max = 50000;
          if (v == '₹1,00,000') max = 100000;
          if (v == '₹2,00,000+') max = 200000;
          setState(() {
            _quickPriceMax = max;
            _page = 1;
          });
        },
      ),
    );
  }

  Widget _dropdownSheet(
    String title,
    List<String> opts,
    void Function(String) onPick,
  ) {
    String selected = opts.isNotEmpty ? opts.first : '';

    return StatefulBuilder(
      builder: (context, setModalState) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.45,
            maxChildSize: 0.90,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 54,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8D4CF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF13294B),
                              ),
                            ),
                          ),

                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F3F3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF13294B),
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: opts.length,
                          itemBuilder: (_, i) {
                            final isSelected = selected == opts[i];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  setModalState(() {
                                    selected = opts[i];
                                  });
                                },
                                child: Container(
                                  height: 57, // Requested height
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF13294B)
                                          : const Color(0xFFD9D9D9),
                                      width: isSelected ? 1.6 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          opts[i],
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A2B47),
                                          ),
                                        ),
                                      ),

                                      isSelected
                                          ? Container(
                                              width: 34,
                                              height: 34,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF1A2B47),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            )
                                          : Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFCFCFCF,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            onPick(selected);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF13294B),
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
              );
            },
          ),
        );
      },
    );
  }
  // ═══════════════════════════════════ BUILD ════════════════════════════════

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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, size: 24, color: kText),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(
      children: [
        const Text(
          'Commercial Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kText,
            letterSpacing: 0.5,
          ),
        ),
        if (!_loading && _filtered.isNotEmpty)
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

  // ── Filter Bar ─────────────────────────────────────────────────────────────
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
          _localityPill(),
          const SizedBox(width: 8),
          _dropdownPill(
            label: _quickPropertyType.isEmpty
                ? 'Property Type'
                : _quickPropertyType,
            active: _quickPropertyType.isNotEmpty,
            onTap: _openPropertyTypeDropdown,
          ),
          const SizedBox(width: 8),
          _dropdownPill(
            label: _quickPriceMax > 0
                ? '≤ ₹${formatIndianFull(_quickPriceMax.toInt())}'
                : 'Max Rent',
            active: _quickPriceMax > 0,
            onTap: _openPriceDropdown,
          ),
          // Active filter chips from full filter screen
          if (_f.buildingType.isNotEmpty) ...[
            const SizedBox(width: 8),
            _activePill(
              _f.buildingType,
              () => setState(() {
                _f = _f.copyWith(buildingType: '');
                _page = 1;
              }),
            ),
          ],
          if (_f.furnishing.isNotEmpty) ...[
            const SizedBox(width: 8),
            _activePill(
              '${_f.furnishing} Furnished',
              () => setState(() {
                _f = _f.copyWith(furnishing: '');
                _page = 1;
              }),
            ),
          ],
          if (_f.floorRange.isNotEmpty) ...[
            const SizedBox(width: 8),
            _activePill(
              'Floor: ${_f.floorRange}',
              () => setState(() {
                _f = _f.copyWith(floorRange: '');
                _page = 1;
              }),
            ),
          ],
          if (_f.propertyAge.isNotEmpty) ...[
            const SizedBox(width: 8),
            _activePill(
              _f.propertyAge,
              () => setState(() {
                _f = _f.copyWith(propertyAge: '');
                _page = 1;
              }),
            ),
          ],
          if (_f.availability.isNotEmpty) ...[
            const SizedBox(width: 8),
            _activePill(
              _f.availability,
              () => setState(() {
                _f = _f.copyWith(availability: '');
                _page = 1;
              }),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _activePill(String label, VoidCallback onRemove) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: kDark,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: Icon(
            Icons.close_rounded,
            size: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    ),
  );

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

  Widget _localityPill() {
    final locality = _f.locality.isNotEmpty
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
              size: 15,
              color: isActive ? Colors.white : kText2,
            ),
            const SizedBox(width: 5),
            Text(
              locality,
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

  Widget _dropdownPill({
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

  // ── Premium Badge ──────────────────────────────────────────────────────────
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
          Text(
            '${_f.amenities.length + _f.nearby.length + _f.restrictions.length}'
            ' premium filters active — tap to edit',
            style: const TextStyle(
              color: kOrange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _f = _f.copyWith(
                amenities: [],
                nearby: [],
                restrictions: [],
                premiumSort: '',
              );
              _page = 1;
            }),
            child: const Icon(Icons.close_rounded, color: kOrange, size: 16),
          ),
        ],
      ),
    ),
  );

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList() {
    if (_filtered.isEmpty) return _buildEmpty();
    final paginated = _paginated;
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

  // ── Property Card ──────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> p) {
    final id = p['id'];
    final propertyIdNum = int.tryParse(id?.toString() ?? '') ?? 0;
    final images = extractPropertyImages(p, kBaseUrl);
    final rent = double.tryParse(p['expectedRent']?.toString() ?? '') ?? 0;
    final sqft = p['builtUpArea']?.toString() ?? '';
    final propType =
        p['commercialPropertyType'] ?? p['propertyType'] ?? 'Commercial';
    final location = [
      p['locality'],
      p['city'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');

    // ── ❤️ Read liked state from likeProvider ─────────────────────────────────
    final isSaved =
        propertyIdNum > 0 &&
        ref
            .watch(likeProvider)
            .maybeWhen(
              data: (_) => ref
                  .read(likeProvider.notifier)
                  .isLiked(propertyIdNum, 'commercial'),
              orElse: () => false,
            );
    // ─────────────────────────────────────────────────────────────────────────
    final createdAt = timeAgo(p['createdAt']?.toString());
    final viewsCount = p['viewscount'] ?? 0;

    return GestureDetector(
      onTap: () async {
        final propertyId = int.tryParse(id?.toString() ?? '');
        if (propertyId == null) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CommercialPropertyDetailScreen(propertyId: propertyId),
          ),
        );
        // Refresh list to reflect updated view count
        _fetchProperties();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
          children: [
            // ── Image ────────────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  child: images.isNotEmpty
                      ? buildPropertyImage(
                          images[0],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          baseUrl: kBaseUrl,
                          placeholder: () => _noImgPlaceholder(),
                        )
                      : _noImgPlaceholder(),
                ),

                // Posted time badge
                if (createdAt.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _imgBadge(createdAt, Icons.access_time),
                  ),

                // Photo count badge
                if (images.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _imgBadge(
                      '${images.length} photos',
                      Icons.photo_camera_outlined,
                    ),
                  ),

                // Views count badge
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.remove_red_eye_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$viewsCount views',
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

                // Save / Share buttons
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      _circleIconBtn(
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border,
                        color: isSaved ? kRed : Colors.black,
                        onTap: () async {
                          if (propertyIdNum > 0) {
                            await ref
                                .read(likeProvider.notifier)
                                .toggle(propertyIdNum, 'commercial');
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _circleIconBtn(
                        Icons.share_outlined,
                        color: Colors.black,
                        onTap: () async {
                          final rent =
                              double.tryParse(
                                p['expectedRent']?.toString() ?? '',
                              ) ??
                              0;
                          final sqft = p['builtUpArea']?.toString() ?? '';
                          final propType =
                              p['commercialPropertyType'] ??
                              p['propertyType'] ??
                              'Commercial Space';
                          final loc = [p['locality'], p['city']]
                              .where(
                                (e) =>
                                    e != null &&
                                    e.toString().trim().isNotEmpty &&
                                    e.toString().toLowerCase() != 'unknown',
                              )
                              .join(', ');
                          final imageUrl = images.isNotEmpty
                              ? images.first.toString()
                              : '';

                          await ShareUtils.shareProperty(
                            title: propType.toString(),
                            loc: loc.isEmpty ? 'RentIt' : loc,
                            area: sqft.toString(),
                            rent: rent.toString(),
                            imageUrl: imageUrl,
                            propertyId: id.toString(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Card Content ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business, color: kBlue, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          propType.toString().toUpperCase(),
                          style: const TextStyle(
                            color: kBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Title + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              propType.toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: kText,
                              ),
                            ),
                            if (p['buildingType'] != null &&
                                p['buildingType'].toString().isNotEmpty)
                              Text(
                                p['buildingType'].toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: kText2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rent > 0
                                ? '₹${formatIndianFull(rent.toInt())}'
                                : 'On Request',
                            style: TextStyle(
                              fontSize: rent > 0 ? 22 : 16,
                              fontWeight: FontWeight.bold,
                              color: kText,
                            ),
                          ),
                          if (rent > 0)
                            const Text(
                              '/month',
                              style: TextStyle(fontSize: 11, color: kText3),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Location
                  if (location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 15,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Feature chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (sqft.isNotEmpty && sqft != '0')
                        _featureChip(Icons.square_foot, '$sqft sq.ft'),
                      if (p['furnishing'] != null)
                        _featureChip(
                          Icons.chair_alt_outlined,
                          _furnishingLabel(p['furnishing']),
                        ),
                      if (p['floor'] != null)
                        _featureChip(
                          Icons.layers_outlined,
                          'Floor ${p['floor']}',
                        ),
                      if (p['propertyAge'] != null)
                        _featureChip(
                          Icons.home_outlined,
                          '${p['propertyAge']}',
                        ),
                      if (p['leaseDuration'] != null &&
                          p['leaseDuration'].toString().isNotEmpty)
                        _featureChip(
                          Icons.calendar_today_outlined,
                          p['leaseDuration'].toString(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Deposit chip
                  if (p['deposit'] != null && p['deposit'] != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: kOrange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Deposit: ₹${formatIndianFull((double.tryParse(p['deposit'].toString()) ?? 0).toInt())}',
                            style: const TextStyle(
                              color: kOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: kDark, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final propertyId = int.tryParse(
                              id?.toString() ?? '',
                            );
                            if (propertyId == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommercialPropertyDetailScreen(
                                  propertyId: propertyId,
                                ),
                              ),
                            );
                            _fetchProperties();
                          },
                          icon: const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: kDark,
                          ),
                          label: const Text(
                            'View Details',
                            style: TextStyle(
                              color: kDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDark,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final phone = p['mobileNo']?.toString();
                            if (phone != null && phone.isNotEmpty) {
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Contact',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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
  }

  // ── Small Widgets ──────────────────────────────────────────────────────────
  String _furnishingLabel(dynamic val) {
    final label = formatFurnishing(val);
    return label.isNotEmpty ? label : 'Furnished';
  }

  Widget _imgBadge(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );

  Widget _featureChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: kText3),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: kText2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _circleIconBtn(
    IconData icon, {
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

  Widget _noImgPlaceholder() => Container(
    height: 200,
    width: double.infinity,
    color: kGreenLight,
    child: const Center(
      child: Icon(Icons.business_outlined, size: 56, color: kGreenMid),
    ),
  );

  // ── Bottom Nav Bar ─────────────────────────────────────────────────────────
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
                          color: Color(0xFFFFC107),
                        ),
                        if (_f.hasPremiumFilters)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFC107),
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
                        color: Color(0xFFFFC107),
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

  // ── Pagination ─────────────────────────────────────────────────────────────
  Widget _buildPagination() {
    final total = _totalPages;
    List<int> pages;
    if (total <= 5)
      pages = List.generate(total, (i) => i + 1);
    else if (_page <= 3)
      pages = [1, 2, 3, 4, 5];
    else if (_page >= total - 2)
      pages = List.generate(5, (i) => total - 4 + i);
    else
      pages = [_page - 2, _page - 1, _page, _page + 1, _page + 2];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pBtn('<', _page > 1, () {
            setState(() => _page--);
            _scrollTop();
          }),
          ...pages.map(
            (n) => _pBtn(n.toString(), true, () {
              setState(() => _page = n);
              _scrollTop();
            }, active: _page == n),
          ),
          _pBtn('>', _page < total, () {
            setState(() => _page++);
            _scrollTop();
          }),
        ],
      ),
    );
  }

  Widget _pBtn(
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

  // ── State Widgets ──────────────────────────────────────────────────────────
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
            200,
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
              child: Icon(Icons.business_outlined, size: 40, color: kGreen),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No properties found',
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
            onPressed: () => setState(() {
              _f = _f.resetFilters();
              _quickPropertyType = '';
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
