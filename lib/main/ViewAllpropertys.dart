// lib/main/ViewAllProperties.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/Locations/LocationScreen.dart';
import 'package:rentit/main/g_details_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/core/auth_guard.dart';
import 'package:rentit/main/PropertyDetails.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'filter_screen.dart';
import 'filter_model.dart';
import 'premium_filter_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const String baseUrl = "https://rentit-backend-omega.vercel.app";
const int kItemsPerPage = 8;

// ── Palette ────────────────────────────────────────────────────────────────────
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

// ── JSON / formatting helpers ──────────────────────────────────────────────────

List<dynamic> parseJson(dynamic val) {
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

String? jsonText(dynamic val) {
  if (val == null) return null;
  if (val is String) return val;
  final arr = parseJson(val);
  return arr.isNotEmpty ? arr.join(', ') : null;
}

String formatIndian(int n) {
  if (n <= 0) return '0';
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

// ── Amenity helpers ────────────────────────────────────────────────────────────

bool _hasAmenityByKey(Map p, String backendKey) {
  final pgAm = p['pgAmenities'];
  if (pgAm is Map && pgAm[backendKey] == true) return true;
  final keyLower = backendKey.toLowerCase().replaceAll(' ', '');
  final rooms = parseJson(p['roomType']);
  for (final r in rooms) {
    final ams = parseJson(
      (r as Map)['amenities'],
    ).join(' ').toLowerCase().replaceAll(' ', '');
    if (ams.contains(keyLower)) return true;
  }
  final joined = [
    ...parseJson(p['societyAmenities']),
    ...parseJson(p['amenities']),
  ].join(' ').toLowerCase().replaceAll(' ', '');
  return joined.contains(keyLower);
}

// ── Price / title / address helpers ───────────────────────────────────────────

String _genderLabel(Map p) {
  final tenants = parseJson(
    p['preferredTenant'],
  ).map((e) => e.toString().toLowerCase().trim()).toList();
  if (tenants.contains('boys') || tenants.contains('male')) return 'Boys';
  if (tenants.contains('girls') || tenants.contains('female')) return 'Girls';
  return 'Anyone';
}

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return 'PG';
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
}

Color _avatarColor(String? name) {
  final colors = [
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF3F51B5),
    const Color(0xFF2196F3),
    const Color(0xFF009688),
    const Color(0xFF4CAF50),
    const Color(0xFFFF5722),
    const Color(0xFF795548),
  ];
  if (name == null) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}

// ── Master filter function ─────────────────────────────────────────────────────

List<dynamic> applyFilters(List<dynamic> properties, PgFilterModel f) {
  List<dynamic> list = List.from(properties);

  if (f.city.isNotEmpty) {
    list = list.where((p) {
      final city = (p as Map)['city']?.toString().toLowerCase().trim() ?? '';
      return city == f.city.toLowerCase().trim();
    }).toList();
  }

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
          (m['propertyName']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['city']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  if (f.pgFor.isNotEmpty) {
    final want = f.pgFor.toLowerCase().trim();

    list = list.where((p) {
      final tenants = parseJson(
        (p as Map)['preferredTenant'],
      ).map((e) => e.toString().toLowerCase().trim()).toList();

      if (tenants.isEmpty) return true;

      if (want == 'boys') {
        return tenants.any(
          (t) =>
              t.contains('boy') ||
              t.contains('male') ||
              t.contains('bachelor male'),
        );
      }

      if (want == 'girls') {
        return tenants.any(
          (t) =>
              t.contains('girl') ||
              t.contains('female') ||
              t.contains('bachelor female'),
        );
      }

      if (want == 'anyone') {
        return tenants.any((t) => t.contains('anyone') || t.contains('any'));
      }

      return true;
    }).toList();
  }
  if (f.sharingTypes.isNotEmpty) {
    list = list.where((p) {
      final rooms = parseJson((p as Map)['roomType']);
      if (rooms.isEmpty) return false;
      return rooms.any((r) {
        final sharing =
            (r as Map)['sharing']?.toString().toLowerCase().trim() ?? '';
        return f.sharingTypes.any(
          (s) =>
              sharing.contains(s.toLowerCase().trim()) ||
              s.toLowerCase().trim().contains(sharing),
        );
      });
    }).toList();
  }

  if (f.preferredTenant.isNotEmpty && f.preferredTenant != 'Anyone') {
    final want = f.preferredTenant.toLowerCase().trim();
    list = list.where((p) {
      final guests = parseJson(
        (p as Map)['preferredGuests'],
      ).map((e) => e.toString().toLowerCase().trim()).toList();
      if (guests.isEmpty) return true;
      return guests.any(
            (g) => g == want || g.contains(want) || want.contains(g),
          ) ||
          guests.contains('anyone') ||
          guests.contains('any');
    }).toList();
  }

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

  if (f.parking.isNotEmpty) {
    list = list.where((p) {
      final pkRaw = (p as Map)['parking'];
      final pk = pkRaw == null ? '' : pkRaw.toString().toLowerCase().trim();
      final hasParking = pk == 'bike' || pk == 'car' || pk == 'both';
      final noParking = pk.isEmpty || pk == 'none';
      if (f.parking.toLowerCase() == 'yes') return hasParking;
      if (f.parking.toLowerCase() == 'no') return noParking;
      return true;
    }).toList();
  }

  if (f.foodIncluded != null) {
    list = list.where((p) {
      final fi = (p as Map)['foodIncluded'];
      final included = fi == true || fi?.toString() == 'true';
      return f.foodIncluded! ? included : !included;
    }).toList();
  }

  if (f.rentMin > 0 || (f.rentMax > 0 && f.rentMax < 1000000)) {
    list = list.where((p) {
      final rooms = parseJson((p as Map)['roomType']);
      if (rooms.isEmpty) return true;
      return rooms.any((r) {
        final rentRaw = (r as Map)['rent'];
        double rent = 0;
        if (rentRaw is num) {
          rent = rentRaw.toDouble();
        } else if (rentRaw != null) {
          rent = double.tryParse(rentRaw.toString()) ?? 0;
        }
        if (rent <= 0) return true;
        final minOk = f.rentMin <= 0 || rent >= f.rentMin;
        final maxOk =
            f.rentMax <= 0 || f.rentMax >= 1000000 || rent <= f.rentMax;
        return minOk && maxOk;
      });
    }).toList();
  }

  if (f.amenities.isNotEmpty) {
    list = list.where((p) {
      return f.amenities.every((key) => _hasAmenityByKey(p as Map, key));
    }).toList();
  }

  if (f.restrictions.isNotEmpty) {
    list = list.where((p) {
      final houseRules = (p as Map)['houseRules'];
      if (houseRules == null || houseRules is! Map) return false;
      return f.restrictions.every((key) => houseRules[key] == true);
    }).toList();
  }

  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// AllPropertiesScreen  ← ConsumerStatefulWidget so we can use ref
// ─────────────────────────────────────────────────────────────────────────────

class AllPropertiesScreen extends ConsumerStatefulWidget {
  final Map<String, String> queryParams;
  const AllPropertiesScreen({super.key, this.queryParams = const {}});

  @override
  ConsumerState<AllPropertiesScreen> createState() =>
      _AllPropertiesScreenState();
}

class _AllPropertiesScreenState extends ConsumerState<AllPropertiesScreen> {
  // ── Data ───────────────────────────────────────────────────────────────────
  List<PGDetailsModel> _properties = [];
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  late PgFilterModel _f;

  // ── Quick-filter bar ──────────────────────────────────────────────────────
  String _genderFilter = '';
  String _roomTypeFilter = '';
  double _priceMax = 0;

  // ── Pagination ────────────────────────────────────────────────────────────
  int _page = 1;

  // ── Sort ──────────────────────────────────────────────────────────────────
  String _sortBy = 'newest';

  final ScrollController _scrollCtrl = ScrollController();

  // ── Like helpers (real provider) ──────────────────────────────────────────

  /// Returns true if the property is currently liked by the user.
  bool _isLiked(int propertyId) {
    ref.watch(likeProvider);
    return ref.read(likeProvider.notifier).isLiked(propertyId, 'pg');
  }

  /// Toggles the like state via the provider (handles API call internally).
  Future<void> _toggleLike(int propertyId) async {
    AuthGuard.protect(
      context,
      onAuthenticated: () {
        ref.read(likeProvider.notifier).toggle(propertyId, 'pg');
      },
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _f = PgFilterModel.fromQueryParams(widget.queryParams);
    if (widget.queryParams.containsKey('sort')) {
      _sortBy = widget.queryParams['sort']!;
    }
    if (widget.queryParams.isEmpty) {
      _f = PgFilterModel();
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
    if (args != null && args is Map<String, String>) {
      setState(() {
        _f = PgFilterModel.fromQueryParams(args);
        _page = 1;
      });
    }
  }

  // ── Network ───────────────────────────────────────────────────────────────

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
      final res = await http.get(
        Uri.parse('$baseUrl/property/all'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      final ct = res.headers['content-type'] ?? '';
      if (!ct.contains('application/json')) {
        throw Exception('Server error (${res.statusCode})');
      }
      if (res.statusCode != 200) {
        throw Exception(
          (jsonDecode(res.body) as Map)['message'] ?? 'Error ${res.statusCode}',
        );
      }

      final raw = jsonDecode(res.body) as List<dynamic>;
      final typed = raw
          .whereType<Map<String, dynamic>>()
          .where((m) => m['id'] != null)
          .map((m) => PGDetailsModel.fromJson(m))
          .where((p) => p.isPG)
          .toList();

      if (!mounted) return;
      setState(() => _properties = typed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Computed / filtered list ───────────────────────────────────────────────

  List<PGDetailsModel> get _filtered {
    final rawList = _properties.map((p) => p.toJson()).toList();
    List<dynamic> list = applyFilters(rawList, _f);

    if (_genderFilter.isNotEmpty) {
      list = list
          .where((p) => _genderLabel(p as Map) == _genderFilter)
          .toList();
    }

    if (_roomTypeFilter.isNotEmpty) {
      list = list.where((p) {
        final rooms = parseJson((p as Map)['roomType']);
        return rooms.any((r) {
          final sharing =
              (r as Map)['sharing']?.toString().toLowerCase().trim() ?? '';
          final q = _roomTypeFilter.toLowerCase().trim();
          return sharing.contains(q) || q.contains(sharing);
        });
      }).toList();
    }

    if (_priceMax > 0) {
      list = list.where((p) {
        final rooms = parseJson((p as Map)['roomType']);
        if (rooms.isEmpty) return true;
        return rooms.any((r) {
          final rent =
              double.tryParse((r as Map)['rent']?.toString() ?? '') ?? 0;
          return rent <= _priceMax;
        });
      }).toList();
    }

    // Sort
    list = List.from(list);
    list.sort((a, b) {
      if (_sortBy == 'price-low' || _sortBy == 'price-high') {
        double price(dynamic p) {
          final rooms = parseJson((p as Map)['roomType']);
          if (rooms.isNotEmpty) {
            return double.tryParse(
                  (rooms[0] as Map)['rent']?.toString() ?? '',
                ) ??
                0;
          }
          return 0;
        }

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

    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => PGDetailsModel.fromJson(m))
        .toList();
  }

  int get _totalPages =>
      (_filtered.length / kItemsPerPage).ceil().clamp(1, 99999);

  List<PGDetailsModel> get _paginated {
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

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _openFilters() {
    if (_f.city.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const LocationScreen(),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FilterScreen(
          initial: _f,
          allProperties: _properties.map((p) => p.toJson()).toList(),
          onApply: (updated) => setState(() {
            _f = updated;
            _page = 1;
          }),
        ),
      ),
    );
  }

  void _openPremiumFilters() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PremiumFilterScreen(
          initial: _f,
          allProperties: _properties.map((p) => p.toJson()).toList(),
          onApply: (updated) => setState(() {
            _f = updated;
            _page = 1;
          }),
        ),
      ),
    );
  }

  // ── Sort Sheet ────────────────────────────────────────────────────────────
  void _openSortSheet() {
    const opts = {
      'relevance': 'Relevance',
      'price-low': 'Price: Low to High',
      'price-high': 'Price: High to Low',
      'newest': 'Newest First',
      'area': 'Area: Largest First',
    };

    String tempSort = _sortBy;

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
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                          width: 86,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8D5D0),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color: Color(0xFF152B4E),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose how listings should appear',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8A93A5),
                                    fontWeight: FontWeight.w500,
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
                                color: Color(0xFFF2F1EF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 26,
                                color: Color(0xFF152B4E),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Options
                      ...opts.entries.map((e) {
                        final selected = tempSort == e.key;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setSheetState(() {
                                tempSort = e.key;
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
                                    ? Border.all(
                                        color: const Color(0xFF152B4E),
                                        width: 1.8,
                                      )
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
                                        color: Color(0xFF152B4E),
                                      ),
                                    ),
                                  ),

                                  // Right Indicator
                                  selected
                                      ? Container(
                                          width: 34,
                                          height: 34,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF152B4E),
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
                            setState(() {
                              _sortBy = tempSort;
                              _page = 1;
                            });

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF152B4E),
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
  // ── Gender Dropdown ─────────────────────────────────────────────

  void _openGenderDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _dropdownSheet(
        'Gender (Preferred Tenant)',
        ['Any', 'Boys', 'Girls', 'Anyone'],
        _genderFilter.isEmpty ? 'Anyone' : _genderFilter,
        (v) {
          setState(() {
            _genderFilter = v == 'Anyone' ? '' : v;
            _page = 1;
          });
        },
      ),
    );
  }

  // ── Room Type Dropdown ─────────────────────────────────────────

  void _openRoomTypeDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _dropdownSheet(
        'Room Type',
        ['Any', 'Single room', 'Double sharing', 'Three Sharing', '4 Sharing'],
        _roomTypeFilter.isEmpty ? 'Any' : _roomTypeFilter,
        (v) {
          setState(() {
            _roomTypeFilter = v == 'Any' ? '' : v;
            _page = 1;
          });
        },
      ),
    );
  }

  void _openPriceDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _dropdownSheet(
        'Max Rent',
        ['Any', '₹5,000', '₹8,000', '₹12,000', '₹20,000', '₹30,000+'],

        // Selected Value
        _priceMax == 0
            ? 'Any'
            : _priceMax == 5000
            ? '₹5,000'
            : _priceMax == 8000
            ? '₹8,000'
            : _priceMax == 12000
            ? '₹12,000'
            : _priceMax == 20000
            ? '₹20,000'
            : '₹30,000+',

        (v) {
          double max = 0;

          switch (v) {
            case '₹5,000':
              max = 5000;
              break;
            case '₹8,000':
              max = 8000;
              break;
            case '₹12,000':
              max = 12000;
              break;
            case '₹20,000':
              max = 20000;
              break;
            case '₹30,000+':
              max = 30000;
              break;
            default:
              max = 0;
          }

          setState(() {
            _priceMax = max;
            _page = 1;
          });
        },
      ),
    );
  }

  static const Color kPrimary = Color(0xFF1A2B47);

  Widget _dropdownSheet(
    String title,
    List<String> opts,
    String selectedValue,
    void Function(String) onPick,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Handle
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// Title + Close
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: kPrimary, size: 22),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          /// Options
          ...opts.map((o) {
            final isSelected = selectedValue == o;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  onPick(o);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 57, // Screenshot height
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? kPrimary : const Color(0xFFD9D9D9),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: kPrimary,
                          ),
                        ),
                      ),

                      /// Radio / Check
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? kPrimary : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? kPrimary
                                : const Color(0xFFCFCFCF),
                            width: 1.4,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          /// Apply Button
          SizedBox(
            width: double.infinity,
            height: 57,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
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
    );
  }
  // ══════════════════════════════════ BUILD ══════════════════════════════════

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
          'RENT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kText,
            letterSpacing: 1.5,
          ),
        ),
        if (_filtered.isNotEmpty)
          Text(
            '${_filtered.length} PG${_filtered.length == 1 ? '' : 's'} found',
            style: const TextStyle(
              fontSize: 11,
              color: kText3,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: kBorder),
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
            label: _genderFilter.isEmpty ? 'Gender' : _genderFilter,
            active: _genderFilter.isNotEmpty,
            onTap: _openGenderDropdown,
          ),
          const SizedBox(width: 8),
          _dropdownPill(
            label: _roomTypeFilter.isEmpty ? 'Room Type' : _roomTypeFilter,
            active: _roomTypeFilter.isNotEmpty,
            onTap: _openRoomTypeDropdown,
          ),
          const SizedBox(width: 8),
          _dropdownPill(
            label: _priceMax > 0
                ? '≤ ₹${formatIndianFull(_priceMax.toInt())}'
                : 'Price',
            active: _priceMax > 0,
            onTap: _openPriceDropdown,
          ),
        ],
      ),
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
        : 'All PGs';
    final isActive = _f.locality.isNotEmpty || _f.city.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() {
        _f = _f.copyWith(city: '', locality: '');
        _page = 1;
      }),
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

  // ── Premium badge ──────────────────────────────────────────────────────────

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
    final paginated = _paginated;
    if (_filtered.isEmpty) return _buildEmpty();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: paginated.length + (_totalPages > 1 ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == paginated.length) return _buildPagination();
        return _buildCard(paginated[i]);
      },
    );
  }

  // ── Property Card ──────────────────────────────────────────────────────────

  Widget _buildCard(PGDetailsModel p) {
    final rooms = p.roomType;
    final ownerName = p.contactName ?? '';
    final updatedAt = timeAgo(
      p.updatedAt?.toIso8601String() ?? p.createdAt?.toIso8601String(),
    );

    final hasWifi = p.pgAmenities['wifi'] == true;
    final hasLift = p.pgAmenities['lift'] == true;
    final hasAC =
        rooms.isNotEmpty &&
        rooms[0].amenities.any((a) => a.toLowerCase().contains('ac'));

    final amenityList = <String>[
      if (hasWifi) 'WiFi',
      if (hasLift) 'Lift',
      if (hasAC) 'AC',
    ];

    String? pricePerBed;
    if (rooms.isNotEmpty && rooms[0].rent != null && rooms[0].rent! > 0) {
      pricePerBed = '₹${formatIndianFull(rooms[0].rent!.toInt())}';
    }

    // Read like state from provider (reactive — updates automatically)
    final liked = _isLiked(p.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (p.id <= 0) return;
        AuthGuard.protectNavigation(
          context,
          screen: PropertyDetailScreen(propertyId: p.id),
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
            _cardImage(p, liked),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + view count
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kText,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _viewCountBadge(p.viewCount),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location
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
                          [p.street, p.landmark, p.city]
                              .where(
                                (e) =>
                                    e != null &&
                                    e.toString().trim().isNotEmpty &&
                                    e.toString().toLowerCase() != "null",
                              )
                              .toSet()
                              .join(", "),
                          style: const TextStyle(fontSize: 12, color: kText3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Gender badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_genderLabel(p.toJson())} PG',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kText2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Amenities
                  if (amenityList.isNotEmpty)
                    Row(
                      children:
                          amenityList
                              .take(3)
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

                  // Price
                  if (pricePerBed != null) ...[
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: pricePerBed,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: kText,
                            ),
                          ),
                          const TextSpan(
                            text: ' / bed',
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

                  const SizedBox(height: 10),
                  if (rooms.isNotEmpty) _roomTypePills(rooms),
                  const SizedBox(height: 14),
                  Container(height: 1, color: kBorder),
                  const SizedBox(height: 12),
                  _ownerRow(p, ownerName, updatedAt),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── View count badge ───────────────────────────────────────────────────────

  Widget _viewCountBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kDark.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kDark.withOpacity(0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_outlined, size: 12, color: kText2),
          const SizedBox(width: 4),
          Text(
            count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kText2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card image ─────────────────────────────────────────────────────────────

  /// [liked] comes from likeProvider — passed in from _buildCard so the heart
  /// icon is always in sync with the real provider state.
  Widget _cardImage(PGDetailsModel p, bool liked) {
    final images = p.images;
    final photoCount = images.length;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: images.isNotEmpty
              ? buildPropertyImage(
                  images[0],
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  baseUrl: baseUrl,
                  placeholder: () => _noImg(),
                )
              : _noImg(),
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
                  '1/${photoCount > 0 ? photoCount : 1}',
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

        // Action buttons (like + share)
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              // ── LIKE BUTTON wired to likeProvider ──
              _circleIconBtn(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: liked ? kRed : kText,
                onTap: () => _toggleLike(p.id),
              ),
              const SizedBox(height: 8),
              _circleIconBtn(
                Icons.share_outlined,
                color: kText,
                onTap: () async {
                  final loc = [p.locality, p.city]
                      .where(
                        (e) =>
                            e != null &&
                            e.toString().trim().isNotEmpty &&
                            e.toString().toLowerCase() != 'unknown',
                      )
                      .join(', ');
                  final title = p.propertyName ?? p.propertyType ?? 'PG';
                  final imageUrl = p.images.isNotEmpty
                      ? p.images.first.toString()
                      : '';

                  await ShareUtils.shareProperty(
                    title: title.toString(),
                    loc: loc.isEmpty ? 'RentIt' : loc,
                    area: '',
                    rent: p.rent?.toString() ?? '',
                    imageUrl: imageUrl,
                    propertyId: p.id.toString(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  // ── Room type pills ────────────────────────────────────────────────────────

  Widget _roomTypePills(List<RoomType> rooms) {
    final pills = rooms.take(3).map<Widget>((room) {
      final sharing = room.sharing ?? 'Room';
      final rent = room.rent ?? 0;
      final priceLabel = rent > 0 ? '₹${formatIndian(rent.toInt())}' : 'N/A';

      String shortLabel = sharing;
      if (sharing.toLowerCase().contains('single')) shortLabel = 'Private';
      if (sharing.toLowerCase().contains('double')) shortLabel = 'Double';
      if (sharing.toLowerCase().contains('three') ||
          sharing.toLowerCase().contains('3'))
        shortLabel = 'Triple';
      if (sharing.toLowerCase().contains('4')) shortLabel = '4 sharing';

      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shortLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kText2,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 1,
              height: 14,
              color: kBorder,
            ),
            Text(
              priceLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
          ],
        ),
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: pills),
    );
  }

  // ── Owner row ──────────────────────────────────────────────────────────────

  Widget _ownerRow(PGDetailsModel p, String ownerName, String updatedAt) {
    final initials = _initials(ownerName.isNotEmpty ? ownerName : null);
    final avatarColor = _avatarColor(ownerName.isNotEmpty ? ownerName : null);
    final displayName = ownerName.isNotEmpty ? ownerName : 'Property Owner';

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
        // Chat button (placeholder — wire to ChatScreen when ready)
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder, width: 1.5),
            ),
            child: const Center(
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: kText2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Call button
        GestureDetector(
          onTap: () async {
            final mobile = p.mobileNo;
            if (mobile != null && mobile.isNotEmpty) {
              final uri = Uri.parse('tel:$mobile');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
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

  // ── State widgets ──────────────────────────────────────────────────────────

  Widget _noImg() => Container(
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
          _shim(
            double.infinity,
            220,
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
              child: Icon(Icons.apartment_outlined, size: 40, color: kGreen),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No PGs found',
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
              _genderFilter = '';
              _roomTypeFilter = '';
              _priceMax = 0;
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
