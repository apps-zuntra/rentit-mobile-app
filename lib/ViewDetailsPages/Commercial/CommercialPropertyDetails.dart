// CommercialPropertyDetails.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/main/PropertyVideoPlayer.dart';
import 'package:rentit/main/chatscreen.dart';
import 'package:rentit/screen/visit_scheduler_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/property_utils.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

class _C {
  static const primary = Color(0xFF0D1F2D);
  static const primaryLight = Color(0xFFEFF6FF);
  static const accent = Color(0xFF2E4A63);
  static const bg = Color(0xFFF2F3F5);
  static const card = Color(0xFFFFFFFF);
  static const text1 = Color(0xFF0D1F2D);
  static const text2 = Color(0xFF4B5563);
  static const text3 = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const gold = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
  static const ownerGreen = Color(0xFF2E5D4B);
  static const chipBg = Color(0xFFF3F4F6);
  static const noticeBadge = Color(0xFF0D1F2D);
}

// ─── Models ───────────────────────────────────────────────────────────────────

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

class _AmenItem {
  final IconData icon;
  final String label;
  const _AmenItem(this.icon, this.label);
}

class _OvRow {
  final IconData icon;
  final String label;
  final String value;
  const _OvRow(this.icon, this.label, this.value);
}

// ═════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class CommercialPropertyDetailScreen extends ConsumerStatefulWidget {
  final int propertyId;
  const CommercialPropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<CommercialPropertyDetailScreen> createState() =>
      _CommercialPropertyDetailScreenState();
}

class _CommercialPropertyDetailScreenState
    extends ConsumerState<CommercialPropertyDetailScreen>
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

  late PageController _imgCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _googleApiKey = 'AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE';
  static const _base = "https://rentit-backend-yti9.onrender.com";

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

  // ── Like ───────────────────────────────────────────────────────────────────

  void _syncLike() {
    if (!mounted) return;
    final liked = ref
        .read(likeProvider.notifier)
        .isLiked(widget.propertyId, 'commercial');
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
          .toggle(widget.propertyId, 'commercial');
      if (!mounted) return;
      _syncLike();
    } catch (_) {
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (widget.propertyId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {'Authorization': 'Bearer $token'};

      await http.post(
        Uri.parse('$_base/commercial/${widget.propertyId}/view'),
        headers: headers,
      );

      final res = await http.get(
        Uri.parse('$_base/commercial/${widget.propertyId}'),
        headers: headers,
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        final prop = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _prop = prop;
          _loading = false;
        });
        _fadeCtrl.forward();
        _syncLike();
        _loadNearby(prop);
      } else {
        setState(() {
          _error = 'Server error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

      List<_NearbyPlace> places = [];
      if (_googleApiKey.isNotEmpty) {
        places = await _fetchGoogleNearby(dLat, dLng);
      } else {
        places = await _fetchNominatimNearby(dLat, dLng);
      }
      if (mounted) setState(() => _nearby = places);
    } catch (_) {
      // non-critical
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  Future<List<_NearbyPlace>> _fetchGoogleNearby(double lat, double lng) async {
    final types = [
      'restaurant',
      'bus_stop',
      'hospital',
      'school',
      'supermarket',
      'shopping_mall',
      'tourist_attraction',
      'park',
      'hindu_temple',
    ];
    final places = <_NearbyPlace>[];
    for (final type in types) {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng&radius=50000&type=$type&key=$_googleApiKey',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) continue;
      final data = jsonDecode(res.body);
      final results = (data['results'] as List<dynamic>? ?? []);
      if (results.isEmpty) continue;
      final r = results.first as Map<String, dynamic>;
      final name = r['name']?.toString() ?? '';
      final photoRef = (r['photos'] as List<dynamic>?)
          ?.firstOrNull?['photo_reference']
          ?.toString();
      final loc = r['geometry']?['location'];
      String dist = '—';
      if (loc != null) {
        final dlat = (loc['lat'] as num).toDouble() - lat;
        final dlng = (loc['lng'] as num).toDouble() - lng;
        final rawKm = dlat * dlat + dlng * dlng;
        final distKm = math.sqrt(rawKm) * 111.0;
        dist = '${distKm.toStringAsFixed(1)} km away';
      }
      final label = type == 'bus_stop'
          ? 'Bus Stop'
          : type == 'restaurant'
          ? 'Restaurant'
          : type == 'hospital'
          ? 'Hospital'
          : type == 'school'
          ? 'School'
          : type == 'shopping_mall'
          ? 'Mall'
          : type == 'tourist_attraction'
          ? 'Famous Place'
          : type == 'park'
          ? 'Park'
          : type == 'hindu_temple'
          ? 'Temple'
          : 'Supermarket';
      places.add(
        _NearbyPlace(
          name: name,
          type: label,
          distance: dist,
          photoRef: photoRef,
        ),
      );
    }
    return places;
  }

  Future<List<_NearbyPlace>> _fetchNominatimNearby(
    double lat,
    double lng,
  ) async {
    final queries = [
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
      } catch (_) {
        continue;
      }
    }
    return places;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(dynamic n) {
    if (n == null) return '—';
    final num = double.tryParse(n.toString());
    if (num == null) return n.toString();
    final str = num.toStringAsFixed(0);
    if (str.length <= 3) return '₹$str';
    final last3 = str.substring(str.length - 3);
    String rest = str.substring(0, str.length - 3);
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

  String _text(dynamic v) {
    if (v == null) return '';
    if (v is String) {
      try {
        final p = jsonDecode(v);
        if (p is List) return p.join(', ');
        return p.toString();
      } catch (_) {
        return v;
      }
    }
    if (v is List) return v.join(', ');
    return v.toString();
  }

  String _fmtDate(dynamic v) {
    try {
      final d = DateTime.parse(v.toString());
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return v?.toString() ?? '';
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Amenity builder ────────────────────────────────────────────────────────

  List<_AmenItem> _buildAmenities(List<String> raw) {
    final items = <_AmenItem>[];
    final added = <String>{};

    void tryAdd(String kw, IconData icon, String label) {
      if (added.contains(label)) return;
      if (!raw.any((a) => a.toLowerCase().contains(kw.toLowerCase()))) return;
      added.add(label);
      items.add(_AmenItem(icon, label));
    }

    tryAdd('wifi', Icons.wifi_rounded, 'WiFi');
    tryAdd('power', Icons.bolt_rounded, 'Power Backup');
    tryAdd('lift', Icons.elevator_rounded, 'Lift');
    tryAdd('elevator', Icons.elevator_rounded, 'Lift');
    tryAdd('gym', Icons.fitness_center_rounded, 'Gym');
    tryAdd('pool', Icons.pool_rounded, 'Swimming Pool');
    tryAdd('parking', Icons.local_parking_rounded, 'Parking');
    tryAdd('security', Icons.security_rounded, 'Security');
    tryAdd('cctv', Icons.videocam_rounded, 'CCTV');
    tryAdd('ac', Icons.ac_unit_rounded, 'AC');
    tryAdd('air condi', Icons.ac_unit_rounded, 'AC');
    tryAdd('garden', Icons.park_rounded, 'Garden');
    tryAdd('park', Icons.park_rounded, 'Park');
    tryAdd('gas', Icons.local_fire_department_rounded, 'Gas');
    tryAdd('pet', Icons.pets_rounded, 'Pets OK');
    tryAdd('non-veg', Icons.restaurant_rounded, 'Non-Veg OK');
    tryAdd('nonveg', Icons.restaurant_rounded, 'Non-Veg OK');
    tryAdd('water', Icons.water_drop_rounded, 'Water Supply');
    tryAdd('laundry', Icons.local_laundry_service_rounded, 'Laundry');
    tryAdd('clean', Icons.cleaning_services_rounded, 'House-Keeper');
    tryAdd('housekeeper', Icons.cleaning_services_rounded, 'House-Keeper');
    tryAdd('tv', Icons.tv_rounded, 'TV');
    tryAdd('fridge', Icons.kitchen_rounded, 'Refrigerator');
    tryAdd('mess', Icons.restaurant_rounded, 'Mess');
    tryAdd('shop', Icons.shopping_cart_rounded, 'Shopping Center');

    for (final a in raw) {
      if (!added.contains(a)) {
        items.add(_AmenItem(Icons.check_circle_outline_rounded, a));
      }
    }
    return items;
  }

  // ── Overview rows ──────────────────────────────────────────────────────────

  List<_OvRow> _buildOverviewRows(Map<String, dynamic> p) {
    debugPrint("🔥 COMMERCIAL API RESPONSE: $p");
    final rows = <_OvRow>[];

    void tryAdd(
      IconData icon,
      String label,
      dynamic raw, {
      String suffix = '',
    }) {
      if (raw == null) return;
      final v = raw.toString().trim();
      if (v.isEmpty || v.toLowerCase() == 'null') return;
      rows.add(_OvRow(icon, label, '$v$suffix'));
    }

    final tenants = _list(
      p['preferredTenant'],
    ).map((e) => e.toString()).join(', ');
    if (tenants.isNotEmpty)
      rows.add(_OvRow(Icons.people_alt_outlined, 'Preferred Tenant', tenants));

    final floor = p['floor'] != null
        ? '${p['floor']}${p['totalFloor'] != null ? ' / ${p['totalFloor']}' : ''}'
        : null;
    tryAdd(Icons.stairs_outlined, 'No. of Floor', floor);

    if (p['builtUpArea'] != null)
      rows.add(
        _OvRow(
          Icons.square_foot_rounded,
          'Built-up Area',
          '${p['builtUpArea']} sq.ft',
        ),
      );
    tryAdd(Icons.hourglass_empty_rounded, 'Property Age', p['propertyAge']);
    tryAdd(Icons.explore_outlined, 'Facing', p['facing']);
    tryAdd(Icons.king_bed_outlined, 'BHK Type', p['bhkType']);
    final furnishingVal = formatFurnishing(p['furnishing']);
    if (furnishingVal.isNotEmpty) {
      rows.add(_OvRow(Icons.chair_rounded, 'Furnishing', furnishingVal));
    }
    tryAdd(Icons.local_parking_rounded, 'Parking', p['parking']);
    if (p['bathroom'] != null)
      rows.add(
        _OvRow(
          Icons.bathtub_outlined,
          'No. of Bathroom',
          p['bathroom'].toString(),
        ),
      );
    if (p['noOfBalcony'] != null)
      rows.add(
        _OvRow(Icons.balcony_rounded, 'Balcony', '${p['noOfBalcony']} balcony'),
      );
    if (p['waterSupply'] != null)
      rows.add(
        _OvRow(
          Icons.water_drop_outlined,
          'Water Supply',
          _text(p['waterSupply']),
        ),
      );
    if (p['petAllowed'] == true)
      rows.add(const _OvRow(Icons.pets_rounded, 'Pet Allowed', 'Yes'));
    if (p['createdAt'] != null)
      rows.add(
        _OvRow(Icons.flag_outlined, 'Posted on', _fmtDate(p['createdAt'])),
      );
    if (p['availableFrom'] != null)
      rows.add(
        _OvRow(
          Icons.calendar_today_outlined,
          'Available From',
          _fmtDate(p['availableFrom']),
        ),
      );

    Map<String, dynamic> feat = {};
    String rawDesc = (p['description'] ?? '').toString();
    final match = RegExp(
      r' \(Info: (.*?)/([YN])/([YN])/(.*?)\)',
    ).firstMatch(rawDesc);
    if (match != null) {
      if (match.group(1) != 'null') feat['previousOccupancy'] = match.group(1);
      if (match.group(2) == 'Y') feat['propertyCleaning'] = true;
      if (match.group(2) == 'N') feat['propertyCleaning'] = false;
      if (match.group(3) == 'Y') feat['propertyPainting'] = true;
      if (match.group(3) == 'N') feat['propertyPainting'] = false;
      if (match.group(4) != 'null') feat['whoShowsProperty'] = match.group(4);
    }

    tryAdd(
      Icons.history_rounded,
      'Previous Occupancy',
      feat['previousOccupancy'],
    );
    tryAdd(
      Icons.person_pin_circle_rounded,
      'Who Shows',
      feat['whoShowsProperty'],
    );

    if (feat['propertyCleaning'] != null) {
      rows.add(
        _OvRow(
          Icons.cleaning_services_rounded,
          'Cleaned',
          feat['propertyCleaning'] == true ? 'Yes' : 'No',
        ),
      );
    }

    if (feat['propertyPainting'] != null) {
      rows.add(
        _OvRow(
          Icons.format_paint_rounded,
          'Painted',
          feat['propertyPainting'] == true ? 'Yes' : 'No',
        ),
      );
    }

    return rows;
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

    if (_loading) return _buildSkeleton();
    if (_error != null) return _buildError();

    final p = _prop!;
    final images = extractPropertyImages(p, _base);
    final amenList = (p['amenities'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final amenItems = _buildAmenities(amenList);
    final ovRows = _buildOverviewRows(p);

    // LOCATION (Privacy Safe)
    final street = p['street']?.toString().trim() ?? '';

    final landmark = p['landmark']?.toString().trim() ?? '';

    final city = p['city']?.toString().trim() ?? '';

    final floor = p['floor'] != null ? '${p['floor']}th Floor' : null;

    // VIDEO
    final video = p['video']?.toString();

    final hasVideo =
        video != null && video.isNotEmpty && video.toLowerCase() != 'null';

    final totalItems = images.length + (hasVideo ? 1 : 0);

    // ADDRESS
    final addressParts = [
      if (street.isNotEmpty) street,
      if (landmark.isNotEmpty) landmark,
      if (city.isNotEmpty) city,
    ];

    final address = addressParts.join(', ');

    final fullAddress = [
      address,
      if (floor != null) floor,
    ].where((e) => e.isNotEmpty).join(' · ');

    // TITLE
    final titleParts = <String>[
      if (p['bhkType'] != null) p['bhkType'].toString(),
      if (p['apartmentType'] != null) p['apartmentType'].toString(),
    ];

    final name = titleParts.isNotEmpty
        ? titleParts.join(' ')
        : (p['buildingType']?.toString() ?? 'Apartment');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        extendBodyBehindAppBar: true,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar + Image Gallery ────────────────────────────────────
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                stretch: true,
                backgroundColor: _C.primary,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                automaticallyImplyLeading: false,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _circleBtn(
                    Icons.arrow_back_ios_new_rounded,
                    () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _circleBtn(
                      _isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      _likeLoading ? () {} : _toggleLike,
                      iconColor: _isLiked ? _C.red : Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 14,
                      top: 10,
                      bottom: 10,
                    ),
                    child: _circleBtn(Icons.share_outlined, () async {
                      final rentVal = p['expectedRent'] ?? p['rent'];
                      final rentStr = rentVal != null
                          ? '₹$rentVal/mo'
                          : 'Rent on Call';
                      await ShareUtils.shareProperty(
                        title: name,
                        loc: fullAddress,
                        area: p['builtUpArea']?.toString() ?? '',
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
                  background: _buildImageGallery(images, p),
                ),
              ),

              // ── Body ────────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Price
                    _buildTitleSection(p, name, fullAddress),
                    _gap(),

                    // About Property
                    if (p['description'] != null &&
                        p['description'].toString().trim().isNotEmpty) ...[
                      _buildAboutSection(p),
                      _gap(),
                    ],

                    // Overview
                    if (ovRows.isNotEmpty) ...[
                      _buildOverviewSection(p, ovRows),
                      _gap(),
                    ],

                    // Amenities
                    if (amenItems.isNotEmpty) ...[
                      _buildAmenitiesSection(amenItems),
                      _gap(),
                    ],

                    // Owner / Chat
                    _buildOwnerSection(p),
                    _gap(),

                    // Nearby
                    _buildNearbySection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(p),
      ),
    );
  }

  // ══════════════════════════════ SECTIONS ═══════════════════════════════════

  Widget _buildImageGallery(List images, Map<String, dynamic> p) {
    final video = p['video']?.toString();

    final hasVideo =
        video != null && video.isNotEmpty && video.toLowerCase() != 'null';

    final totalItems = images.length + (hasVideo ? 1 : 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imgCtrl,
          itemCount: totalItems == 0 ? 1 : totalItems,
          onPageChanged: (i) {
            setState(() => _activeImg = i);
          },
          itemBuilder: (_, i) {
            if (totalItems == 0) {
              return _noImgPlaceholder();
            }

            // First item = Video
            if (hasVideo && i == 0) {
              return PropertyVideoPlayer(videoUrl: video);
            }

            // Remaining items = Images
            final imageIndex = hasVideo ? i - 1 : i;

            return buildPropertyImage(
              images[imageIndex],
              fit: BoxFit.cover,
              baseUrl: _base,
              placeholder: () => _noImgPlaceholder(),
            );
          },
        ),

        // Bottom gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
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
        if (totalItems > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalItems.clamp(0, 8),
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: _activeImg == i ? 22 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: _activeImg == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),

        // Counter
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_activeImg + 1} / $totalItems',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
  // ── Title + Price ──────────────────────────────────────────────────────────

  Widget _buildTitleSection(
    Map<String, dynamic> p,
    String name,
    String address,
  ) {
    final furnishingStr = formatFurnishing(p['furnishing']);
    final chips = <String>[
      if (p['bhkType'] != null && p['bhkType'].toString().trim().isNotEmpty)
        p['bhkType'].toString().trim(),
      if (p['builtUpArea'] != null &&
          p['builtUpArea'].toString().trim().isNotEmpty)
        '${p['builtUpArea']} sq.ft',
      if (p['petAllowed'] == true) 'Pet Friendly',
      if (furnishingStr.isNotEmpty) furnishingStr,
    ];

    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property name
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _C.text1,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // Address row
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: _C.text3),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _C.text2,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (p['landmark'] != null && p['longitude'] != null)
                const SizedBox(width: 8),

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
                    horizontal: 9,
                    vertical: 4,
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

          const SizedBox(height: 16),

          // Price row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Rent
              Expanded(
                child: Column(
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
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (p['expectedRent'] != null)
                            const TextSpan(
                              text: '  /month',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: _C.text3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Deposit
              if (p['deposit'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Deposit',
                      style: TextStyle(
                        fontSize: 11,
                        color: _C.text3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmt(p['deposit']),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.text2,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Chips
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map(_featureChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── About Property ─────────────────────────────────────────────────────────

  Widget _buildAboutSection(Map<String, dynamic> p) {
    String rawDesc = (p['description'] ?? '').toString();
    // Remove the hidden (Info: ...) part from the displayed description
    rawDesc = rawDesc.replaceAll(RegExp(r' \(Info: .*/[YN]/[YN]/.*\)'), '');
    final desc = rawDesc.trim();
    final long = desc.length > 160;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('About Property'),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(fontSize: 13, color: _C.text2, height: 1.5),
            maxLines: _descExpanded ? null : 4,
            overflow: _descExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (long) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(
                _descExpanded ? 'Read less ‹' : 'Read more ›',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.text1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Overview ───────────────────────────────────────────────────────────────
  Widget _buildOverviewSection(Map<String, dynamic> p, List<_OvRow> rows) {
    final notice = p['noticePeriod']?.toString().trim();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Overview'),
              const Spacer(),
              if (notice != null && notice.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF354458), // Slate dark badge
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Notice Period :$notice',
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

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: List.generate((rows.length / 2).ceil(), (rowIndex) {
                final left = rows[rowIndex * 2];

                final right = rowIndex * 2 + 1 < rows.length
                    ? rows[rowIndex * 2 + 1]
                    : null;

                final isLast = rowIndex == ((rows.length / 2).ceil() - 1);

                return IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _ovCell(left, showBottom: !isLast)),

                      Container(width: 1, color: _C.border),

                      Expanded(
                        child: right != null
                            ? _ovCell(right, showBottom: !isLast)
                            : Container(),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ovCell(_OvRow row, {bool showBottom = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showBottom
            ? const Border(bottom: BorderSide(color: _C.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(row.icon, size: 18, color: _C.text1),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  row.value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.text1,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  row.label,
                  style: const TextStyle(fontSize: 12, color: _C.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ── Amenities ──────────────────────────────────────────────────────────────

  Widget _buildAmenitiesSection(List<_AmenItem> items) {
    final show = _amenExpanded ? items : items.take(6).toList();

    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Amenities'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...show.map(_amenityChip),
              if (!_amenExpanded && items.length > 6)
                GestureDetector(
                  onTap: () => setState(() => _amenExpanded = true),
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _C.chipBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.border),
                    ),
                    child: Center(
                      child: Text(
                        '+${items.length - 6}\nMore',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.text1,
                        ),
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

  Widget _amenityChip(_AmenItem a) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: _C.chipBg,
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
    final name = (userObj?['name'] ?? userObj?['username'] ?? 'Owner')
        .toString();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'O';
    final ownerId = p['userId'] is int
        ? p['userId'] as int
        : int.tryParse(p['userId']?.toString() ?? '');
    final propertyId = p['id'] is int
        ? p['id'] as int
        : int.tryParse(p['id']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF183828), Color(0xFF2A6040)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),

            // Name
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

            // Chat now button
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
                width: 139,
                height: 33,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2B3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Chat now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nearby ─────────────────────────────────────────────────────────────────

  Widget _buildNearbySection() {
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Nearby'),
          const SizedBox(height: 14),
          if (_nearbyLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _C.primary,
                ),
              ),
            )
          else if (_nearby.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
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
    final IconData icon;
    switch (place.type) {
      case 'Restaurant':
        icon = Icons.restaurant_rounded;
        break;
      case 'Bus Stop':
        icon = Icons.directions_bus_rounded;
        break;
      case 'Hospital':
        icon = Icons.local_hospital_rounded;
        break;
      case 'School':
        icon = Icons.school_rounded;
        break;
      case 'Supermarket':
        icon = Icons.shopping_cart_rounded;
        break;
      default:
        icon = Icons.place_rounded;
    }

    final bool hasPhoto = place.photoRef != null;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail / icon area
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60,
              height: 60,
              child: hasPhoto
                  ? Image.network(
                      'https://maps.googleapis.com/maps/api/place/photo'
                      '?maxwidth=140&photo_reference=${place.photoRef}&key=$_googleApiKey',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _nearbyIconBox(icon),
                    )
                  : _nearbyIconBox(icon),
            ),
          ),
          const SizedBox(width: 12),

          // Info
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
                  style: const TextStyle(fontSize: 12, color: _C.text3),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: _C.green,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        place.distance,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.green,
                        ),
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

  Widget _nearbyIconBox(IconData icon) => Container(
    height: double.infinity,
    color: const Color(0xFFF3F4F6),
    child: Center(child: Icon(icon, size: 28, color: _C.text3)),
  );

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(Map<String, dynamic> p) {
    final phone =
        p['secondaryNumber']?.toString() ??
        (p['user'] as Map<String, dynamic>?)?['phone']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border, width: 1.0),
                  ),
                  child: Center(
                    child: SvgPicture.string(
                      '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M20 2H4C2.9 2 2.01 2.9 2.01 4L2 22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2ZM18 14H6V12H18V14ZM18 11H6V9H18V11ZM18 8H6V6H18V8Z" fill="#1C2B3A"/>
</svg>''',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),

              // Contact button
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: _C.border, width: 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: phone != null
                        ? () => _launch('tel:$phone')
                        : null,
                    icon: const Icon(
                      Icons.phone,
                      size: 18,
                      color: Color(0xFF1C2B3A),
                    ),
                    label: const Text(
                      'Contact',
                      style: TextStyle(
                        color: Color(0xFF1C2B3A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Schedule Visit button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2B3A),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final commId = int.tryParse(p['id']?.toString() ?? '');
                      if (commId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid property ID')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisitSchedulerScreen(
                            propertyId: commId,
                            propertyType: 'Commercial',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Schedule Visit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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

  // ══════════════════════════════ SHARED WIDGETS ════════════════════════════

  Widget _gap() => Container(height: 8, color: _C.bg);

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: _C.text1,
      letterSpacing: -0.2,
    ),
  );

  Widget _featureChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: _C.chipBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _C.border),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _C.text2,
      ),
    ),
  );

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
          color: Colors.black.withOpacity(0.30),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, color: iconColor, size: 17)),
      ),
    ),
  );

  Widget _noImgPlaceholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D1F2D), Color(0xFF2E4A63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.apartment_rounded, size: 68, color: Colors.white24),
    ),
  );

  // ── Skeleton loading ───────────────────────────────────────────────────────

  Widget _buildSkeleton() => Scaffold(
    backgroundColor: _C.bg,
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(double.infinity, 300, radius: BorderRadius.zero),
          const SizedBox(height: 8),
          Container(
            color: _C.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(200, 24),
                const SizedBox(height: 8),
                _shimmer(150, 14),
                const SizedBox(height: 18),
                _shimmer(170, 34),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _shimmer(72, 30),
                    const SizedBox(width: 8),
                    _shimmer(82, 30),
                    const SizedBox(width: 8),
                    _shimmer(96, 30),
                    const SizedBox(width: 8),
                    _shimmer(82, 30),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: _C.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(120, 18),
                const SizedBox(height: 12),
                _shimmer(double.infinity, 14),
                const SizedBox(height: 6),
                _shimmer(double.infinity, 14),
                const SizedBox(height: 6),
                _shimmer(240, 14),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: _C.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _shimmer(120, 18),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _shimmer(double.infinity, 56)),
                    const SizedBox(width: 1),
                    Expanded(child: _shimmer(double.infinity, 56)),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(child: _shimmer(double.infinity, 56)),
                    const SizedBox(width: 1),
                    Expanded(child: _shimmer(double.infinity, 56)),
                  ],
                ),
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
      color: const Color(0xFFE9EAEC),
      borderRadius: radius ?? BorderRadius.circular(7),
    ),
  );

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() => Scaffold(
    backgroundColor: _C.bg,
    appBar: AppBar(
      backgroundColor: _C.primary,
      automaticallyImplyLeading: false,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
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
            const SizedBox(height: 18),
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
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: _C.primary),
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    elevation: 0,
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
