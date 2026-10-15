// ─────────────────────────────────────────────────────────────────────────────
// FlatmatePropertyDetails.dart  — Full A-to-Z clean rewrite
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/main/chatscreen.dart';
import 'package:rentit/screen/visit_scheduler_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/property_utils.dart';
import 'dart:math' as math;

// ─── Palette ──────────────────────────────────────────────────────────────────

class _C {
  static const primary = Color(0xFF1A2B40);
  static const primaryLight = Color(0xFFEFF6FF);
  static const accent = Color(0xFF2E4A63);
  static const bg = Color(0xFFF5F6F8);
  static const card = Color(0xFFFFFFFF);
  static const text1 = Color(0xFF111827);
  static const text2 = Color(0xFF4B5563);
  static const text3 = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _OvRow {
  final IconData icon;
  final String label;
  final String value;
  const _OvRow(this.icon, this.label, this.value);
}

class _AmenItem {
  final IconData icon;
  final String label;
  const _AmenItem(this.icon, this.label);
}

class _NearbyPlace {
  final String name;
  final String type;
  final String distance;
  final String? photoRef;
  const _NearbyPlace({
    required this.name,
    required this.type,
    required this.distance,
    this.photoRef,
  });
}

// ─── Base URL ─────────────────────────────────────────────────────────────────

const _kBase = "https://rentit-backend-yti9.onrender.com";

// Set your Google Places API key here for real nearby results.
// Leave empty to use the Nominatim (OpenStreetMap) free fallback.
const _kGoogleApiKey = 'AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE';

// ═════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class FlatmateDetailScreen extends ConsumerStatefulWidget {
  final int propertyId;

  const FlatmateDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<FlatmateDetailScreen> createState() =>
      _FlatmateDetailScreenState();
}

class _FlatmateDetailScreenState extends ConsumerState<FlatmateDetailScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _prop;
  bool _loading = true;
  String? _error;

  int _activeImg = 0;
  bool _descExpanded = false;
  bool _amenExpanded = false;
  bool _isLiked = false;
  bool _likeLoading = false;

  List<_NearbyPlace> _nearby = [];
  bool _nearbyLoading = false;
  List<Map<String, dynamic>> _recentlyViewed = [];

  late PageController _imgCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _imgCtrl = PageController();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLike();
    });
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Like helpers ───────────────────────────────────────────────────────────

  void _syncLike() {
    if (!mounted) return;
    final liked = ref
        .read(likeProvider.notifier)
        .isLiked(widget.propertyId, 'flatmate');
    if (mounted && liked != _isLiked) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _likeLoading = true;
      _isLiked = !_isLiked;
    });
    try {
      await ref
          .read(likeProvider.notifier)
          .toggle(widget.propertyId, 'flatmate');
      if (!mounted) return;
      _syncLike();
    } catch (_) {
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = '$_kBase/flatmate/${widget.propertyId}';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final ct = response.headers['content-type'] ?? '';
        if (!ct.contains('application/json')) {
          throw Exception('Unexpected response from server');
        }

        final data = jsonDecode(response.body);

        if (data is! Map<String, dynamic>) {
          throw Exception('Invalid data format received');
        }

        setState(() {
          _prop = data;
          _loading = false;
        });

        _fadeCtrl.forward();

        // Load supporting data after main data is ready
        final headers = <String, String>{
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        };

        _loadNearby(data);
        _loadRecentlyViewed(headers);
        _syncLike();
      } else {
        String msg = 'Server Error ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          }
        } catch (_) {}

        setState(() {
          _error = msg;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadRecentlyViewed(Map<String, String> headers) async {
    try {
      final city = _prop?['city'] ?? '';
      final res = await http.get(
        Uri.parse('$_kBase/flatmate/all'),
        headers: headers,
      );
      if (!mounted || res.statusCode != 200) return;
      final List<dynamic> all = jsonDecode(res.body) as List<dynamic>;
      final filtered = all
          .whereType<Map<String, dynamic>>()
          .where((p) => p['id']?.toString() != widget.propertyId.toString())
          .take(6)
          .toList();
      if (mounted) setState(() => _recentlyViewed = filtered);
    } catch (_) {}
  }

  // ── Nearby ─────────────────────────────────────────────────────────────────

  Future<void> _loadNearby(Map<String, dynamic> prop) async {
    if (!mounted) return;
    setState(() => _nearbyLoading = true);
    try {
      dynamic rawLat = prop['latitude'] ?? prop['lat'];
      dynamic rawLng = prop['longitude'] ?? prop['lng'];

      if (rawLat == null || rawLng == null) {
        final loc = prop['location'];
        if (loc is Map) {
          rawLat ??= loc['lat'] ?? loc['coordinates']?[1];
          rawLng ??= loc['lng'] ?? loc['coordinates']?[0];
        } else if (loc is String) {
          try {
            final parsedLoc = jsonDecode(loc);
            rawLat ??= parsedLoc['lat'] ?? parsedLoc['coordinates']?[1];
            rawLng ??= parsedLoc['lng'] ?? parsedLoc['coordinates']?[0];
          } catch (_) {}
        }
      }

      var dLat = double.tryParse(rawLat?.toString() ?? '') ?? 0.0;
      var dLng = double.tryParse(rawLng?.toString() ?? '') ?? 0.0;

      if (dLat == 0.0 || dLng == 0.0) {
        final addressStr =
            "${prop['street'] ?? ''} ${prop['locality'] ?? ''} ${prop['city'] ?? ''}"
                .trim();
        if (addressStr.isNotEmpty) {
          final geoUrl = Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(addressStr)}',
          );
          try {
            final geoRes = await http.get(
              geoUrl,
              headers: {'User-Agent': 'RentItApp/1.0 (app@rentit.com)'},
            );
            if (geoRes.statusCode == 200) {
              final geoData = jsonDecode(geoRes.body) as List<dynamic>;
              if (geoData.isNotEmpty) {
                dLat = double.tryParse(geoData.first['lat'].toString()) ?? 0.0;
                dLng = double.tryParse(geoData.first['lon'].toString()) ?? 0.0;
              }
            }
          } catch (_) {}
        }
      }
      if (dLat == 0.0 || dLng == 0.0) {
        // Fallback to Chennai center for incomplete test data
        dLat = 13.0827;
        dLng = 80.2707;
      }
      final places = _kGoogleApiKey.isNotEmpty
          ? await _fetchGoogleNearby(dLat, dLng)
          : await _fetchNominatimNearby(dLat, dLng);
      if (mounted) setState(() => _nearby = places);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  Future<List<_NearbyPlace>> _fetchGoogleNearby(double lat, double lng) async {
    const types = [
      'restaurant',
      'bus_stop',
      'hospital',
      'school',
      'shopping_mall',
      'tourist_attraction',
      'park',
      'hindu_temple',
    ];
    final places = <_NearbyPlace>[];
    for (final type in types) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng&radius=50000&type=$type&key=$_kGoogleApiKey',
        );
        final res = await http.get(url);
        if (res.statusCode != 200) continue;
        final results =
            (jsonDecode(res.body)['results'] as List<dynamic>? ?? []);
        if (results.isEmpty) continue;
        final r = results.first as Map<String, dynamic>;
        final loc = r['geometry']?['location'];
        String dist = '—';
        if (loc != null) {
          final dlat = (loc['lat'] as num).toDouble() - lat;
          final dlng = (loc['lng'] as num).toDouble() - lng;
          final rawKm = dlat * dlat + dlng * dlng;
          final distKm = math.sqrt(rawKm) * 111.0;
          dist = '${distKm.toStringAsFixed(1)} km away';
        }
        places.add(
          _NearbyPlace(
            name: r['name']?.toString() ?? '',
            type: _typeLabel(type),
            distance: dist,
          ),
        );
      } catch (_) {}
    }
    return places;
  }

  Future<List<_NearbyPlace>> _fetchNominatimNearby(
    double lat,
    double lng,
  ) async {
    const queries = [
      {'tag': 'amenity', 'val': 'restaurant', 'label': 'Restaurant'},
      {'tag': 'amenity', 'val': 'bus_stop', 'label': 'Bus Stop'},
      {'tag': 'amenity', 'val': 'hospital', 'label': 'Hospital'},
      {'tag': 'amenity', 'val': 'school', 'label': 'School'},
      {'tag': 'amenity', 'val': 'marketplace', 'label': 'Mall'},
      {'tag': 'tourism', 'val': 'attraction', 'label': 'Famous Place'},
      {'tag': 'leisure', 'val': 'park', 'label': 'Park'},
      {'tag': 'amenity', 'val': 'place_of_worship', 'label': 'Temple'},
    ];
    final places = <_NearbyPlace>[];
    for (final q in queries) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?format=json&limit=1&${q['tag']}=${q['val']}'
          '&viewbox=${lng - 0.45},${lat - 0.45},${lng + 0.45},${lat + 0.45}&bounded=1',
        );
        final res = await http.get(
          url,
          headers: {'User-Agent': 'RentItApp/1.0 (app@rentit.com)'},
        );
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isEmpty) continue;
        final r = data.first as Map<String, dynamic>;
        final name = r['display_name']?.toString().split(',').first ?? '';
        final rlat = double.tryParse(r['lat']?.toString() ?? '') ?? lat;
        final rlng = double.tryParse(r['lon']?.toString() ?? '') ?? lng;
        final dlat = rlat - lat;
        final dlng = rlng - lng;
        final rawKm = dlat * dlat + dlng * dlng;
        final distKm = math.sqrt(rawKm) * 111.0;
        final dist = '${distKm.toStringAsFixed(1)} km away';
        places.add(_NearbyPlace(name: name, type: q['label']!, distance: dist));
      } catch (_) {}
    }
    return places;
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'restaurant':
        return 'Restaurant';
      case 'bus_stop':
        return 'Bus Stop';
      case 'hospital':
        return 'Hospital';
      case 'school':
        return 'School';
      case 'shopping_mall':
        return 'Mall';
      case 'tourist_attraction':
        return 'Famous Place';
      case 'park':
        return 'Park';
      case 'hindu_temple':
        return 'Temple';
      default:
        return t;
    }
  }

  // ── Format helpers ─────────────────────────────────────────────────────────

  String _fmt(dynamic n) {
    if (n == null) return '—';
    final num = double.tryParse(n.toString());
    if (num == null) return n.toString();
    final str = num.toStringAsFixed(0);
    if (str.length <= 3) return '₹$str';
    final last3 = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
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
    return '₹${buf.toString().split('').reversed.join()},$last3';
  }

  String _fmtShort(dynamic n) {
    final v = double.tryParse(n?.toString() ?? '') ?? 0;
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  String _ago(dynamic v) {
    try {
      final d = DateTime.parse(v.toString());
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) {
      return 'Recently';
    }
  }

  String _fmtDate(dynamic v) {
    try {
      final d = DateTime.parse(v.toString());
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return v?.toString() ?? '';
    }
  }

  List<dynamic> _list(dynamic v) {
    if (v == null) return [];
    if (v is List) return v;
    if (v is String) {
      try {
        final p = jsonDecode(v);
        return p is List ? p : [];
      } catch (_) {
        return [v];
      }
    }
    if (v is Map) return v.values.toList();
    return [];
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Overview rows (Flatmate schema) ────────────────────────────────────────

  List<_OvRow> _buildOverviewRows(Map<String, dynamic> p) {
    final rows = <_OvRow>[];

    void add(IconData icon, String label, dynamic raw, {String suffix = ''}) {
      if (raw == null) return;
      final v = raw.toString().trim();
      if (v.isEmpty || v.toLowerCase() == 'null' || v == 'false') return;
      rows.add(_OvRow(icon, label, '$v$suffix'));
    }

    void addBool(IconData icon, String label, dynamic raw) {
      if (raw == true) rows.add(_OvRow(icon, label, 'Yes'));
    }

    // Preferred tenant
    final tenant = p['tenantType']?.toString() ?? '';
    if (tenant.isNotEmpty)
      rows.add(_OvRow(Icons.people_alt_outlined, 'Preferred Tenant', tenant));

    // Floor
    final floor = p['floor'] != null
        ? '${p['floor']}${p['totalFloor'] != null ? ' / ${p['totalFloor']}' : ''}'
        : null;
    add(Icons.stairs_outlined, 'No. of Floor', floor);

    // Furnishing
    final furnishingVal = formatFurnishing(p['furnishing']);
    if (furnishingVal.isNotEmpty) {
      rows.add(_OvRow(Icons.chair_rounded, 'Furnishing', furnishingVal));
    }
    // Property Age
    add(Icons.hourglass_empty_rounded, 'Property Age', p['propertyAge']);
    // Built-up area
    if (p['builtUpArea'] != null)
      rows.add(
        _OvRow(
          Icons.square_foot_rounded,
          'Built-up Area',
          '${p['builtUpArea']} sq.ft',
        ),
      );

    // Building type (from apartmentType)
    add(Icons.apartment_rounded, 'Building Type', p['apartmentType']);
    // Bathroom
    addBool(Icons.bathtub_outlined, 'Attached Bathroom', p['attachedBathroom']);
    // Bathroom type
    add(Icons.wc_rounded, 'Bathroom Type', p['bathroomType']);
    // Parking
    add(Icons.local_parking_rounded, 'Parking', p['parking']);
    // Facing
    add(Icons.explore_outlined, 'Facing', p['facing']);
    // Balcony
    addBool(Icons.balcony_rounded, 'Balcony', p['balcony']);
    // Non Veg
    addBool(Icons.restaurant_rounded, 'Non Veg Allowed', p['nonVegAllowed']);
    // AC
    addBool(Icons.ac_unit_rounded, 'AC', p['acRoom']);
    // Smoking
    addBool(
      Icons.smoking_rooms_rounded,
      'Smoking Allowed',
      p['smokingAllowed'],
    );
    // Drinking
    addBool(Icons.local_bar_rounded, 'Drinking Allowed', p['drinkingAllowed']);
    // Water supply
    add(Icons.water_drop_outlined, 'Water Supply', p['waterSupply']);
    // Available from
    if (p['availableFrom'] != null)
      rows.add(
        _OvRow(
          Icons.calendar_today_outlined,
          'Available From',
          _fmtDate(p['availableFrom']),
        ),
      );

    return rows;
  }

  // ── Amenity chips ──────────────────────────────────────────────────────────

  List<_AmenItem> _buildAmenities(Map<String, dynamic> p) {
    final items = <_AmenItem>[];

    void tryBool(bool? v, IconData icon, String label) {
      if (v == true) items.add(_AmenItem(icon, label));
    }

    tryBool(p['gym'], Icons.fitness_center_rounded, 'Gym');
    tryBool(p['liftSelected'], Icons.elevator_rounded, 'Lift');
    tryBool(p['swimmingPoolSelected'], Icons.pool_rounded, 'Swimming Pool');
    tryBool(p['powerBackupSelected'], Icons.bolt_rounded, 'Power Backup');
    tryBool(p['clubHouseSelected'], Icons.meeting_room_rounded, 'Club House');
    tryBool(p['parkSelected'], Icons.park_rounded, 'Park');
    tryBool(p['gatedSecurity'], Icons.security_rounded, 'Security');
    tryBool(p['acRoom'], Icons.ac_unit_rounded, 'AC');
    tryBool(p['balcony'], Icons.balcony_rounded, 'Balcony');

    if (p['waterSupply'] != null && p['waterSupply'].toString().isNotEmpty)
      items.add(const _AmenItem(Icons.water_drop_rounded, 'Water Supply'));
    if (p['parking'] != null && p['parking'].toString().isNotEmpty)
      items.add(const _AmenItem(Icons.local_parking_rounded, 'Parking'));
    if (p['whoShowsProperty'] != null)
      items.add(
        const _AmenItem(Icons.cleaning_services_rounded, 'House-Keeper'),
      );

    // Gas, Shopping Center guesses from apartmentType / description
    final desc = (p['description'] ?? '').toString().toLowerCase();
    if (desc.contains('gas'))
      items.add(const _AmenItem(Icons.local_fire_department_rounded, 'Gas'));
    if (desc.contains('shop'))
      items.add(
        const _AmenItem(Icons.shopping_cart_rounded, 'Shopping Center'),
      );

    return items;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    ref.listen(likeProvider, (_, __) {
      if (mounted && !_likeLoading) {
        _syncLike();
      }
    });
    if (_loading) {
      return _buildSkeleton();
    }

    if (_error != null) {
      return _buildError();
    }

    final p = _prop!;
    final images = extractPropertyImages(p, _kBase);
    final ovRows = _buildOverviewRows(p);
    final amenItems = _buildAmenities(p);

    // Title: "Room type for tenantType"
    final roomType =
        p['roomType']?.toString() ?? p['bhkType']?.toString() ?? '';
    final tenantType = p['tenantType']?.toString() ?? '';
    final title = roomType.isNotEmpty
        ? (tenantType.isNotEmpty ? '$roomType for $tenantType' : roomType)
        : (p['apartmentName']?.toString() ?? 'Flatmate Listing');

    String _shortLocation(Map<String, dynamic> p) {
      final raw = (p['locality'] ?? '').toString().trim();
      final city = (p['city'] ?? '').toString().trim();

      if (raw.isEmpty) return city;

      final parts = raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String area = '';

      if (parts.length >= 3) {
        area = parts[2]; // Periamet
      } else if (parts.length >= 2) {
        area = parts[1];
      } else {
        area = parts.first;
      }

      if (city.isNotEmpty) {
        return '$area, $city';
      }

      return area;
    }

    final address = _shortLocation(p);

    final int views = int.tryParse(p['viewscount']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sliver AppBar ──────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: _C.primary,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: _circleBtn(
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: _circleBtn(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    _likeLoading ? () {} : _toggleLike,
                    iconColor: _isLiked ? _C.red : Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: _circleBtn(Icons.share_outlined, () async {
                    final rentVal = p['expectedRent'] ?? p['rent'];
                    final rentStr = rentVal != null
                        ? '₹$rentVal/mo'
                        : 'Rent on Call';
                    await ShareUtils.shareProperty(
                      title: title,
                      loc: address,
                      area: '',
                      rent: rentStr,
                      imageUrl: images.isNotEmpty
                          ? images.first.toString()
                          : '',
                      propertyId: widget.propertyId.toString(),
                    );
                  }),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildGallery(images, p),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title + Posted + Price ─────────────────────────────
                  _buildTitleSection(p, title, address, views),
                  _divider(),

                  // ── About Property ─────────────────────────────────────
                  if ((p['description'] ?? '').toString().isNotEmpty) ...[
                    _buildAboutSection(p),
                    _divider(),
                  ],

                  // ── Overview table ─────────────────────────────────────
                  if (ovRows.isNotEmpty) ...[
                    _buildOverviewSection(p, ovRows),
                    _divider(),
                  ],

                  // ── Amenities ──────────────────────────────────────────
                  if (amenItems.isNotEmpty) ...[
                    _buildAmenitiesSection(amenItems),
                    _divider(),
                  ],

                  // ── Owner ──────────────────────────────────────────────
                  _buildOwnerSection(p),
                  _divider(),

                  // ── Nearby ─────────────────────────────────────────────
                  _buildNearbySection(),
                  _divider(),

                  // ── Recently Viewed ────────────────────────────────────
                  if (_recentlyViewed.isNotEmpty) ...[
                    _buildRecentlyViewed(),
                    _divider(),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(p),
    );
  }

  // ══════════════════════════════ SECTIONS ═══════════════════════════════════

  // ── Gallery ────────────────────────────────────────────────────────────────

  Widget _buildGallery(List images, Map<String, dynamic> p) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imgCtrl,
          itemCount: images.isEmpty ? 1 : images.length,
          onPageChanged: (i) => setState(() => _activeImg = i),
          itemBuilder: (_, i) {
            if (images.isEmpty) return _noImgPlaceholder(double.infinity);
            return buildPropertyImage(
              images[i],
              fit: BoxFit.cover,
              baseUrl: _kBase,
              placeholder: () => _noImgPlaceholder(double.infinity),
            );
          },
        ),
        // Bottom gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
        // Dots
        if (images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length.clamp(0, 8),
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _activeImg == i ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: _activeImg == i ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        // Counter
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_activeImg + 1} / ${images.isEmpty ? 1 : images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // Tap zones
        if (images.length > 1) ...[
          Positioned(
            left: 0,
            top: 56,
            bottom: 56,
            width: 60,
            child: GestureDetector(
              onTap: () => _imgCtrl.animateToPage(
                (_activeImg - 1 + images.length) % images.length,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            right: 0,
            top: 56,
            bottom: 56,
            width: 60,
            child: GestureDetector(
              onTap: () => _imgCtrl.animateToPage(
                (_activeImg + 1) % images.length,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ],
    );
  }

  // ── Title Section ──────────────────────────────────────────────────────────

  Widget _buildTitleSection(
    Map<String, dynamic> p,
    String title,
    String address,
    int views,
  ) {
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _C.text1,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: _C.text3),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 13, color: _C.text2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  String query = '';
                  if (p['latitude'] != null && p['longitude'] != null) {
                    query = '${p['latitude']},${p['longitude']}';
                  } else {
                    query =
                        [p['locality'], p['street'], p['landmark'], p['city']]
                            .where(
                              (e) =>
                                  e != null && e.toString().trim().isNotEmpty,
                            )
                            .join(', ');
                  }
                  if (query.isEmpty) {
                    query = address;
                  }
                  if (query.isNotEmpty) {
                    _launch(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 12, color: _C.blue),
                      SizedBox(width: 3),
                      Text(
                        'Map',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _C.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Posted + views
          Row(
            children: [
              Text(
                'Posted ${_ago(p['createdAt'])}',
                style: const TextStyle(fontSize: 12, color: _C.text3),
              ),
              if (views > 0) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 13,
                  color: _C.text3,
                ),
                const SizedBox(width: 3),
                Text(
                  '$views views',
                  style: const TextStyle(fontSize: 12, color: _C.text3),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 14),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: p['expectedRent'] != null
                              ? _fmt(p['expectedRent'])
                              : 'Price on request',
                          style: TextStyle(
                            fontSize: p['expectedRent'] != null ? 28 : 18,
                            fontWeight: FontWeight.w900,
                            color: _C.text1,
                          ),
                        ),
                        if (p['expectedRent'] != null)
                          const TextSpan(
                            text: ' /mo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: _C.text3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (p['expectedDeposit'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Deposit',
                      style: TextStyle(fontSize: 11, color: _C.text3),
                    ),
                    Text(
                      _fmt(p['expectedDeposit']),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _C.text2,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── About Property ─────────────────────────────────────────────────────────

  Widget _buildAboutSection(Map<String, dynamic> p) {
    final desc = (p['description'] ?? '').toString().trim();
    final long = desc.length > 180;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: _C.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'About Property...',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.text1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              desc.isEmpty ? 'No description available.' : desc,
              style: const TextStyle(
                fontSize: 14,
                color: _C.text2,
                height: 1.7,
              ),
              maxLines: _descExpanded ? null : 5,
              overflow: _descExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),

          if (long) ...[
            const SizedBox(height: 12),

            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _descExpanded = !_descExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _descExpanded ? 'Show Less' : 'Read More',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _C.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _descExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: _C.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ── Overview TABLE ─────────────────────────────────────────────────────────
  // Two-column bordered table, each cell has icon + label + value

  Widget _buildOverviewSection(Map<String, dynamic> p, List<_OvRow> rows) {
    // Notice period badge
    final notice = p['noticePeriod']?.toString();

    // Pair up rows into 2-col rows
    final rowCount = (rows.length / 2).ceil();

    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.text1,
                ),
              ),
              const Spacer(),
              if (notice != null && notice.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _C.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Notice Period : $notice Days',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: List.generate(rowCount, (rowIdx) {
                final left = rows[rowIdx * 2];
                final right = rowIdx * 2 + 1 < rows.length
                    ? rows[rowIdx * 2 + 1]
                    : null;
                final isLast = rowIdx == rowCount - 1;
                return Container(
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(bottom: BorderSide(color: _C.border)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _tableCell(left)),
                        Container(width: 1, color: _C.border),
                        Expanded(
                          child: right != null
                              ? _tableCell(right)
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _tableCell(_OvRow row) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, size: 17, color: _C.text3),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _C.text3,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                row.value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.text1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Amenities ──────────────────────────────────────────────────────────────

  Widget _buildAmenitiesSection(List<_AmenItem> items) {
    final show = _amenExpanded ? items : items.take(6).toList();
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amenities',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _C.text1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              ...show.map(_amenChip),
              if (!_amenExpanded && items.length > 6)
                GestureDetector(
                  onTap: () => setState(() => _amenExpanded = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.border),
                    ),
                    child: Text(
                      '+${items.length - 6}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.text2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amenChip(_AmenItem a) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(a.icon, size: 14, color: _C.text2),
        const SizedBox(width: 6),
        Text(
          a.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _C.text1,
          ),
        ),
      ],
    ),
  );

  // ── Owner / Chat ───────────────────────────────────────────────────────────

  Widget _buildOwnerSection(Map<String, dynamic> p) {
    final userObj = p['user'] as Map<String, dynamic>?;
    final name =
        (userObj?['name'] ??
                userObj?['username'] ??
                p['contactName'] ??
                'Owner')
            .toString();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'O';

    final ownerId = p['userId'] is int
        ? p['userId'] as int
        : int.tryParse(p['userId']?.toString() ?? '');
    final propertyId = p['id'] is int
        ? p['id'] as int
        : int.tryParse(p['id']?.toString() ?? '');

    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF2E5D4B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.text1,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (propertyId == null || ownerId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat unavailable for this property'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    propertyId: propertyId,
                    ownerName: name,
                    ownerId: ownerId,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Chat now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Nearby ─────────────────────────────────────────────────────────────────

  Widget _buildNearbySection() {
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _C.text1,
            ),
          ),
          const SizedBox(height: 14),

          if (_nearbyLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _C.primary,
                ),
              ),
            )
          else if (_nearby.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No nearby places found.',
                style: TextStyle(color: _C.text3, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _nearby.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _nearbyCard(_nearby[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _nearbyCard(_NearbyPlace place) {
    final icon = place.type == 'Restaurant'
        ? Icons.restaurant_rounded
        : place.type == 'Bus Stop'
        ? Icons.directions_bus_rounded
        : place.type == 'Hospital'
        ? Icons.local_hospital_rounded
        : place.type == 'School'
        ? Icons.school_rounded
        : Icons.place_rounded;

    return Container(
      width: 198,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(icon, size: 24, color: _C.text3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  place.type,
                  style: const TextStyle(fontSize: 11, color: _C.text3),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: _C.green,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place.distance,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _C.green,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recently Viewed ────────────────────────────────────────────────────────

  Widget _buildRecentlyViewed() {
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text(
                  'Recently viewed property',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _C.text1,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentlyViewed.length,
              itemBuilder: (_, i) => _recentCard(_recentlyViewed[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentCard(Map<String, dynamic> p) {
    final images = extractPropertyImages(p, _kBase);
    final rent = p['expectedRent'];
    final title =
        p['apartmentName']?.toString() ??
        p['roomType']?.toString() ??
        'Listing';
    final loc = [
      p['locality'],
      p['city'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FlatmateDetailScreen(
            propertyId: (p['id'] is int)
                ? p['id'] as int
                : int.tryParse(p['id']?.toString() ?? '') ?? 0,
          ),
        ),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 95,
              child: images.isNotEmpty
                  ? buildPropertyImage(
                      images[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 95,
                      baseUrl: _kBase,
                      placeholder: () => _noImgPlaceholder(95),
                    )
                  : _noImgPlaceholder(95),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rent != null)
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '₹${_fmtShort(rent)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _C.text1,
                            ),
                          ),
                          const TextSpan(
                            text: ' /mo',
                            style: TextStyle(fontSize: 10, color: _C.text3),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.text2,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    loc,
                    style: const TextStyle(fontSize: 10, color: _C.text3),
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
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(Map<String, dynamic> p) {
    final phone =
        p['secondaryNumber']?.toString() ??
        (p['user'] as Map<String, dynamic>?)?['phone']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Chat icon button
              GestureDetector(
                onTap: () {
                  final userObj = p['user'] as Map<String, dynamic>?;
                  final name = (userObj?['name'] ?? 'Owner').toString();
                  final ownerId = p['userId'] is int
                      ? p['userId'] as int
                      : int.tryParse(p['userId']?.toString() ?? '');
                  final propertyId = p['id'] is int
                      ? p['id'] as int
                      : int.tryParse(p['id']?.toString() ?? '');
                  if (ownerId == null || propertyId == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        propertyId: propertyId,
                        ownerName: name,
                        ownerId: ownerId,
                      ),
                    ),
                  );
                },
                // Find this in _buildBottomBar — the chat GestureDetector's child:
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12), // ← line 1770
                    border: Border.all(color: _C.border, width: 1.5),
                  ),
                  alignment: Alignment.center, // ← ADD THIS LINE
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: _C.primary,
                  ),
                ),
              ),

              // Contact
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _C.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: phone != null ? () => _launch('tel:$phone') : null,
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: _C.primary,
                  ),
                  label: const Text(
                    'Contact',
                    style: TextStyle(
                      color: _C.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Schedule Visit
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final fmId = int.tryParse(p['id']?.toString() ?? '');
                    if (fmId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid Flatmate ID')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitSchedulerScreen(
                          propertyId: fmId,
                          propertyType: 'Flatmate',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Schedule Visit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════ MICRO WIDGETS ═══════════════════════════════

  Widget _divider() => Container(height: 8, color: _C.bg);

  // In FlatmatePropertyDetails.dart — _circleBtn is CORRECT, keep it:
  Widget _circleBtn(
    IconData icon,
    VoidCallback onTap, {
    Color iconColor = Colors.white,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    ),
  );

  Widget _noImgPlaceholder(double h) => Container(
    height: h,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A2B40), Color(0xFF2E4A63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.home_work_rounded, size: 48, color: Colors.white24),
    ),
  );

  // ── Skeleton ───────────────────────────────────────────────────────────────

  Widget _buildSkeleton() => Scaffold(
    backgroundColor: _C.bg,
    body: SingleChildScrollView(
      child: Column(
        children: [
          _shimmer(double.infinity, 280, radius: BorderRadius.zero),
          const SizedBox(height: 8),
          Container(
            color: _C.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(200, 22),
                const SizedBox(height: 8),
                _shimmer(140, 14),
                const SizedBox(height: 16),
                _shimmer(160, 32),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: _C.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _shimmer(double.infinity, 16),
                const SizedBox(height: 6),
                _shimmer(double.infinity, 14),
                const SizedBox(height: 6),
                _shimmer(220, 14),
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

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() => Scaffold(
    backgroundColor: _C.bg,
    appBar: AppBar(
      backgroundColor: _C.primary,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _C.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _C.text1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _C.text2),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: _C.primary),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
