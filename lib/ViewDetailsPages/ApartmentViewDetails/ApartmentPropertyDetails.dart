// ApartmentPropertyDetails.dart
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
import 'package:rentit/core/share_utils.dart';
import 'package:rentit/core/image_utils.dart';
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
  static const gold = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
}

// ─── Nearby place model ───────────────────────────────────────────────────────

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

// ─── Amenity model ────────────────────────────────────────────────────────────

class _AmenItem {
  final IconData icon;
  final String label;
  const _AmenItem(this.icon, this.label);
}

// ─── Overview row model ───────────────────────────────────────────────────────

class _OvRow {
  final IconData icon;
  final String label;
  final String value;
  const _OvRow(this.icon, this.label, this.value);
}

// ═════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class ApartmentPropertyDetailScreen extends ConsumerStatefulWidget {
  final int propertyId;
  const ApartmentPropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<ApartmentPropertyDetailScreen> createState() =>
      _ApartmentPropertyDetailScreenState();
}

class _ApartmentPropertyDetailScreenState
    extends ConsumerState<ApartmentPropertyDetailScreen>
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
  bool hasBookedVisit = false;
  Map<String, dynamic>? bookedVisit;

  List<_NearbyPlace> _nearby = [];
  bool _nearbyLoading = false;

  late PageController _imgCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _base = "https://rentit-backend-yti9.onrender.com";

  get video => null;

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
        .isLiked(widget.propertyId, 'apartment');
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
          .toggle(widget.propertyId, 'apartment');
      if (!mounted) return;
      _syncLike();
    } catch (_) {
      if (mounted) setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _load() async {
    if (widget.propertyId <= 0) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getInt('userId');

      final headers = {if (token != null) 'Authorization': 'Bearer $token'};

      // ✅ VIEW COUNT ONLY ONCE PER USER PER PROPERTY
      if (token != null && userId != null) {
        final viewedKey = 'apartment_view_${widget.propertyId}_user_$userId';

        final alreadyViewed = prefs.getBool(viewedKey) ?? false;

        if (!alreadyViewed) {
          try {
            final response = await http.post(
              Uri.parse('$_base/apartment/${widget.propertyId}/view'),
              headers: headers,
            );

            if (response.statusCode == 200 || response.statusCode == 201) {
              await prefs.setBool(viewedKey, true);
            }
          } catch (_) {}
        }
      }

      // ✅ FETCH PROPERTY DETAILS
      final res = await http.get(
        Uri.parse('$_base/apartment/${widget.propertyId}'),
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
        _loadVisitStatus();
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
  // ── Nearby via Google Places (or Nominatim fallback) ───────────────────────

  Future<void> _loadVisitStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('$_base/visit/property/${widget.propertyId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint('STATUS = ${res.statusCode}');
      debugPrint('BODY = ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && mounted) {
          setState(() {
            hasBookedVisit = true;
            bookedVisit = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Visit status error: $e');
    }
  }

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

      final places = await _fetchNominatimNearby(dLat, dLng);
      if (mounted) setState(() => _nearby = places);
    } catch (_) {
      // non-critical
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
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

  // ── Format helpers ─────────────────────────────────────────────────────────

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

    return rows;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD — unchanged from your original
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
    final video = p['video']?.toString();

    final amenList = (p['amenities'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final amenItems = _buildAmenities(amenList);
    final ovRows = _buildOverviewRows(p);

    String address = '';
    if (p['area'] != null && p['area'].toString().trim().isNotEmpty) {
      address = '${p['area']}, ${p['city'] ?? ''}';
    } else if (p['street'] != null &&
        p['street'].toString().trim().isNotEmpty) {
      address = '${p['street']}, ${p['city'] ?? ''}';
    } else {
      address = p['city']?.toString() ?? '';
    }

    final titleParts = <String>[
      if (p['bhkType'] != null) p['bhkType'].toString(),
      if (p['apartmentType'] != null) p['apartmentType'].toString(),
    ];
    final name = titleParts.isNotEmpty
        ? titleParts.join(' ')
        : (p['buildingType']?.toString() ?? 'Apartment');
    final fullAddress = address;

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                    final rentVal = p['expectedRent'];
                    final rentStr = rentVal != null
                        ? rentVal.toString()
                        : 'Rent on Call';
                    final areaStr = p['builtUpArea']?.toString() ?? '';
                    await ShareUtils.shareProperty(
                      title: name,
                      loc: fullAddress,
                      area: areaStr,
                      rent: rentStr,
                      imageUrl: images.isNotEmpty
                          ? images.first.toString()
                          : '',
                      propertyId:
                          p['id']?.toString() ?? widget.propertyId.toString(),
                    );
                  }),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildImageGallery(images, video),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(p, name, fullAddress),
                  _divider(),
                  if (p['description'] != null) ...[
                    _buildAboutSection(p),
                    _divider(),
                  ],
                  if (ovRows.isNotEmpty) ...[
                    _buildOverviewSection(p, ovRows),
                    _divider(),
                  ],
                  if (amenItems.isNotEmpty) ...[
                    _buildAmenitiesSection(amenItems),
                    _divider(),
                  ],
                  _buildOwnerSection(p),
                  _divider(),
                  _buildNearbySection(),
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
  // All section widgets below are IDENTICAL to your original — no changes.

  Widget _buildImageGallery(List images, String? video) {
    final totalItems = (video != null && video.isNotEmpty)
        ? images.length + 1
        : images.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imgCtrl,
          itemCount: totalItems == 0 ? 1 : totalItems,
          onPageChanged: (i) => setState(() => _activeImg = i),
          itemBuilder: (_, i) {
            if (totalItems == 0) return _noImgPlaceholder(double.infinity);
            if (video != null && video.isNotEmpty && i == 0) {
              return Stack(
                fit: StackFit.expand,
                children: [PropertyVideoPlayer(videoUrl: video)],
              );
            }
            final imageIndex = (video != null && video.isNotEmpty) ? i - 1 : i;
            return buildPropertyImage(
              images[imageIndex],
              fit: BoxFit.cover,
              baseUrl: _base,
              placeholder: () => _noImgPlaceholder(double.infinity),
            );
          },
        ),

        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalItems.clamp(0, 8),
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
              '${_activeImg + 1} / ${totalItems == 0 ? 1 : totalItems}',
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _C.text1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: _C.text3),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 13, color: _C.text2),
                  maxLines: 1,
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

          const SizedBox(height: 14),

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
                            text: ' /month',
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
              const Spacer(),
              if (p['deposit'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Deposit',
                      style: TextStyle(fontSize: 11, color: _C.text3),
                    ),
                    Text(
                      _fmt(p['deposit']),
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

          const SizedBox(height: 12),

          if (chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((c) => _featureChip(c)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Map<String, dynamic> p) {
    final desc = (p['description'] ?? '').toString();
    final long = desc.length > 160;
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Property',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _C.text1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(fontSize: 14, color: _C.text2, height: 1.6),
            maxLines: _descExpanded ? null : 4,
            overflow: _descExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (long) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _descExpanded ? 'Read less' : 'Read more',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.primary,
                    ),
                  ),
                  Icon(
                    _descExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: _C.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewSection(Map<String, dynamic> p, List<_OvRow> rows) {
    final notice = p['noticePeriod']?.toString();
    return Container(
      width: double.infinity,
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _C.text1,
                ),
              ),
              const Spacer(),
              if (notice != null && notice.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Notice Period :$notice Days',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              border: const TableBorder(
                horizontalInside: BorderSide(color: _C.border),
                verticalInside: BorderSide(color: _C.border),
              ),
              columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
              children: List.generate((rows.length / 2).ceil(), (index) {
                final left = rows[index * 2];
                final right = index * 2 + 1 < rows.length
                    ? rows[index * 2 + 1]
                    : null;
                return TableRow(
                  children: [
                    _ovCell(left),
                    right != null ? _ovCell(right) : const SizedBox(height: 60),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ovCell(_OvRow row) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(row.icon, size: 18, color: const Color(0xFF1F2A37)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2A37),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                row.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildAmenitiesSection(List<_AmenItem> items) {
    final show = _amenExpanded ? items : items.take(5).toList();
    return Container(
      width: double.infinity,
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amenities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.text1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...show.map((a) => _amenityChip(a)),
              if (!_amenExpanded && items.length > 5)
                GestureDetector(
                  onTap: () => setState(() => _amenExpanded = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.border),
                    ),
                    child: Text(
                      '+ ${items.length - 5}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(a.icon, size: 16, color: const Color(0xFF4B5563)),
        const SizedBox(width: 6),
        Text(
          a.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    ),
  );

  Widget _buildOwnerSection(Map<String, dynamic> p) {
    final userObj = p['user'] as Map<String, dynamic>?;
    final name = (userObj?['name'] ?? userObj?['username'] ?? 'Owner')
        .toString();

    final parts = name.trim().split(RegExp(r'\s+'));
    final initial = parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'O');

    final ownerId = p['userId'] is int
        ? p['userId'] as int
        : int.tryParse(p['userId']?.toString() ?? '');
    final propertyId = p['id'] is int
        ? p['id'] as int
        : int.tryParse(p['id']?.toString() ?? '');

    return Container(
      width: double.infinity,
      color: _C.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF2E5D4B),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _C.text1,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Chat now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              fontSize: 18,
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
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: _C.primary,
                  ),
                ),
              ),

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
                    final aptId = int.tryParse(p['id']?.toString() ?? '');
                    if (aptId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid property ID')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitSchedulerScreen(
                          propertyId: aptId,
                          propertyType: 'Apartment',
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

  // ══════════════════════════════ SMALL WIDGETS ════════════════════════════

  Widget _divider() => Container(height: 8, color: _C.bg);

  Widget _featureChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
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
      child: Icon(Icons.apartment_rounded, size: 64, color: Colors.white24),
    ),
  );

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _shimmer(70, 28),
                    const SizedBox(width: 8),
                    _shimmer(80, 28),
                    const SizedBox(width: 8),
                    _shimmer(90, 28),
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
