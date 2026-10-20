// PropertyDetails.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rentit/main/chatscreen.dart';
import 'package:rentit/screen/visit_scheduler_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/share_utils.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────

class _C {
  static const primary = Color(0xFF1B2D3E);
  static const primaryDark = Color(0xFF1B2D3E);
  static const primaryLight = Color(0xFFEEF3F8);
  static const accent = Color(0xFF2F4253);
  static const bg = Color(0xFFF5F6FA);
  static const card = Color(0xFFFFFFFF);
  static const text1 = Color(0xFF0D1B2A);
  static const text2 = Color(0xFF4A5568);
  static const text3 = Color(0xFF9AA5B4);
  static const border = Color(0xFFE8ECF2);
  static const gold = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const tagBg = Color(0xFFFFF4E0);
  static const tagFg = Color(0xFFB45309);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final int propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _prop;
  bool _loading = true;
  String? _error;

  int _activeImg = 0;
  bool _descExpanded = false;
  bool _rulesExpanded = true;
  bool _isLiked = false;
  bool _likeLoading = false;
  int _selectedRoomIndex = 0;
  List<_NearbyItem> _nearby = [];
  bool _nearbyLoading = false;
  bool _amenExpanded = false;

  late PageController _imgCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _base = "https://rentit-backend-omega.vercel.app";

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

  void _syncLike() {
    if (!mounted) return;
    final liked = ref
        .read(likeProvider.notifier)
        .isLiked(widget.propertyId, 'pg');
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
      await ref.read(likeProvider.notifier).toggle(widget.propertyId, 'pg');
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
      final token = prefs.getString("token");
      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };
      try {
        await http.post(
          Uri.parse("$_base/property/${widget.propertyId}/view"),
          headers: headers,
        );
      } catch (_) {}
      final response = await http.get(
        Uri.parse("$_base/property/${widget.propertyId}"),
        headers: headers,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _prop = jsonDecode(response.body);
          _loading = false;
        });
        _fadeCtrl.forward();
        _syncLike();
        if (_prop != null) {
          _loadNearby(_prop!);
        }
      } else {
        setState(() {
          _error = "Failed to load property (${response.statusCode})";
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

  Future<void> _loadNearby(Map<String, dynamic> prop) async {
    final lat = prop['latitude'];
    final lng = prop['longitude'];
    if (lat == null || lng == null) return;
    if (!mounted) return;
    setState(() => _nearbyLoading = true);
    try {
      final dLat = double.tryParse(lat.toString()) ?? 0;
      final dLng = double.tryParse(lng.toString()) ?? 0;
      final places = _isPG
          ? await _fetchNearbyPGsFromDb(dLat, dLng)
          : await _fetchNominatimNearby(dLat, dLng);
      if (mounted) setState(() => _nearby = places);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  Future<List<_NearbyItem>> _fetchNominatimNearby(
    double lat,
    double lng,
  ) async {
    const queries = [
      {
        'amenity': 'restaurant',
        'label': 'Restaurant',
        'img':
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=100&q=80',
      },
      {
        'amenity': 'bus_stop',
        'label': 'Bus Stop',
        'img':
            'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=100&q=80',
      },
      {
        'amenity': 'hospital',
        'label': 'Hospital',
        'img':
            'https://images.unsplash.com/photo-1586773860418-d3b31966cfb7?w=100&q=80',
      },
      {
        'amenity': 'school',
        'label': 'School',
        'img':
            'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=100&q=80',
      },
    ];
    final places = <_NearbyItem>[];
    for (final q in queries) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?format=json&limit=1&amenity=${q['amenity']}'
          '&lat=$lat&lon=$lng&radius=1500',
        );
        final res = await http.get(url, headers: {'User-Agent': 'RentIt/1.0'});
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isEmpty) continue;
        final r = data.first as Map<String, dynamic>;
        final name = r['display_name']?.toString().split(',').first ?? '';
        final rlat = double.tryParse(r['lat']?.toString() ?? '') ?? lat;
        final rlng = double.tryParse(r['lon']?.toString() ?? '') ?? lng;
        final dlat = rlat - lat;
        final dlng = rlng - lng;
        final km = (dlat * dlat + dlng * dlng) * 12321.0;
        final dist =
            '${(km < 0 ? 0.0 : km * 111.0).toStringAsFixed(1)} km away';
        places.add(_NearbyItem(q['img']!, name, q['label']!, dist));
      } catch (_) {}
    }
    return places;
  }

  String _formatImgUrl(dynamic img) {
    if (img == null || img.toString().isEmpty) {
      return "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=120&q=80";
    }
    final s = img.toString();
    if (s.startsWith("http")) return s;
    return "$_base/$s";
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<List<_NearbyItem>> _fetchNearbyPGsFromDb(
    double lat,
    double lng,
  ) async {
    final places = <_NearbyItem>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final response = await http.get(
        Uri.parse("$_base/property/all"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final all = jsonDecode(response.body) as List<dynamic>;
        final currentIdStr = widget.propertyId.toString();

        final otherPGs = <Map<String, dynamic>>[];

        for (final item in all) {
          if (item is! Map<String, dynamic>) continue;
          final idStr = item['id']?.toString() ?? '';
          if (idStr == currentIdStr) continue;

          final type = (item['propertyType'] ?? '').toString().toLowerCase();
          final type2 = (item['propertyType2'] ?? '').toString().toLowerCase();
          final isPG =
              type.contains('pg') ||
              type2.contains('pg') ||
              type.contains('hostel') ||
              type2.contains('hostel');
          if (!isPG) continue;

          final platVal = item['latitude'];
          final plngVal = item['longitude'];
          if (platVal == null || plngVal == null) continue;

          final plat = double.tryParse(platVal.toString());
          final plng = double.tryParse(plngVal.toString());
          if (plat == null || plng == null) continue;

          // Calculate distance
          final distanceKm = _calculateDistance(lat, lng, plat, plng);
          otherPGs.add({'prop': item, 'distance': distanceKm});
        }

        // Sort by distance
        otherPGs.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );

        // Take top 4
        for (final item in otherPGs.take(4)) {
          final propMap = item['prop'] as Map<String, dynamic>;
          final dist = item['distance'] as double;

          final name =
              (propMap['propertyName'] ??
                      propMap['propertyType2'] ??
                      propMap['propertyType'] ??
                      'PG')
                  .toString();

          // Gender label
          final genderLabel = pgGenderLabel(propMap);

          // Image
          final images = _list(propMap['images']);
          final imgUrl = _formatImgUrl(images.isNotEmpty ? images.first : null);

          // ID
          final pgId = int.tryParse(propMap['id']?.toString() ?? '') ?? 0;

          places.add(
            _NearbyItem(
              imgUrl,
              name,
              genderLabel,
              '${dist.toStringAsFixed(1)} km away',
              pgId: pgId,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching nearby PGs: $e");
    }
    return places;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(dynamic n) {
    if (n == null) return "—";
    final num = double.tryParse(n.toString());
    if (num == null) return n.toString();
    final str = num.toStringAsFixed(0);
    if (str.length <= 3) return "₹$str";
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
    return "₹${buf.toString().split('').reversed.join()},$last3";
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
    if (v == null) return "";
    if (v is String) {
      try {
        final p = jsonDecode(v);
        if (p is List) return p.join(", ");
        return p.toString();
      } catch (_) {
        return v;
      }
    }
    if (v is List) return v.join(", ");
    return v.toString();
  }

  String _ago(dynamic v) {
    try {
      final d = DateTime.parse(v.toString());
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo ago";
      if (diff.inDays > 0) return "${diff.inDays}d ago";
      if (diff.inHours > 0) return "${diff.inHours}h ago";
      return "Just now";
    } catch (_) {
      return "Recently";
    }
  }

  String _fmtDate(dynamic v) {
    try {
      final d = DateTime.parse(v.toString());
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${d.day} ${m[d.month - 1]} ${d.year}";
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  bool get _isPG {
    final p = _prop!;
    final t = (p['propertyType'] ?? '').toString().toLowerCase();
    final t2 = (p['propertyType2'] ?? '').toString().toLowerCase();
    return t.contains('pg') ||
        t2.contains('pg') ||
        t.contains('hostel') ||
        t2.contains('hostel');
  }

  String formatSharingName(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.contains('three') || s.contains('3')) return 'Three Sharing Room';
    if (s.contains('two') || s.contains('double') || s.contains('2'))
      return 'Two Sharing Room';
    if (s.contains('single') || s.contains('1')) return 'Single Room';
    if (s.contains('four') || s.contains('4')) return 'Four Sharing Room';
    if (s.isEmpty) return 'Room';
    return s
            .split(' ')
            .map((word) {
              if (word.isEmpty) return '';
              return word[0].toUpperCase() + word.substring(1);
            })
            .join(' ') +
        (s.endsWith('room') ? '' : ' Room');
  }

  String pgGenderLabel(Map<String, dynamic> p) {
    final g = (p['gender'] ?? '').toString().toLowerCase().trim();
    if (g == 'male' || g == 'boys' || g == 'boy') return 'Boys PG';
    if (g == 'female' || g == 'girls' || g == 'girl') return 'Girls PG';
    if (g == 'unisex' || g == 'anyone' || g == 'mixed') return 'Unisex PG';
    return 'Unisex PG';
  }

  List<Map<String, dynamic>> _rooms() {
    final p = _prop!;
    final rooms = <Map<String, dynamic>>[];
    final raw = p['roomType'];
    if (raw != null) {
      for (final item in _list(raw)) {
        if (item is Map) {
          rooms.add({
            'name':
                item['sharing']?.toString() ??
                item['type']?.toString() ??
                item['name']?.toString() ??
                'Room',
            'rent': item['rent'] ?? item['price'],
            'deposit': item['deposit'],
            'availability': item['availability'] ?? item['slots'],
            'amenities': _list(item['amenities']),
          });
        }
      }
    }
    if (rooms.isEmpty && p['rent'] != null) {
      rooms.add({
        'name': 'Single Room',
        'rent': p['rent'],
        'deposit': p['deposit'],
        'availability': p['noOfAvailableSlots'],
        'amenities': [],
      });
    }
    return rooms;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
    final address = [
      p['street'],
      p['locality'],
      p['landmark'],
      p['city'],
      p['pincode'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(", ");
    final rooms = _isPG ? _rooms() : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── SLIVER APP BAR ────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: _C.primaryDark,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              automaticallyImplyLeading: false,
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
                    _toggleLike,
                    color: _isLiked ? _C.red : Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    right: 10,
                    top: 10,
                    bottom: 10,
                  ),
                  child: _circleBtn(Icons.share_outlined, () async {
                    final rentVal = p['rent'] ?? p['expectedRent'];
                    final rentStr = rentVal != null
                        ? '₹$rentVal/mo'
                        : 'Rent on Call';
                    final titleStr =
                        p['pgName'] ??
                        p['propertyName'] ??
                        p['propertyType'] ??
                        'PG in ${p['locality'] ?? p['city'] ?? ''}';
                    await ShareUtils.shareProperty(
                      title: titleStr.toString(),
                      loc: address,
                      area: '',
                      rent: rentStr,
                      imageUrl: images.isNotEmpty
                          ? images.first.toString()
                          : '',
                      propertyId: widget.propertyId.toString(),
                    );
                  }, color: Colors.white),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildImageGallery(images, p),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TITLE CARD ──────────────────────────────────────────
                  _buildTitleCard(p, address, rooms),

                  if ((p['propertyDescription'] ?? p['description']) == null)
                    _sectionDivider(),

                  // ── ABOUT PROPERTY ─────────────────────────────────────
                  if ((p['propertyDescription'] ?? p['description']) != null)
                    _buildAboutCard(p),

                  // ── OVERVIEW ───────────────────────────────────────────
                  _buildOverviewCard(p),

                  _sectionDivider(),

                  // ── ROOM TYPES (PG) ────────────────────────────────────
                  if (_isPG && rooms.isNotEmpty) ...[
                    _buildRoomsCard(rooms),
                    _sectionDivider(),
                  ],

                  // ── AMENITIES ──────────────────────────────────────────
                  _buildAmenitiesCard(p),

                  _sectionDivider(),

                  // ── CONTACT ────────────────────────────────────────────
                  _buildContactCard(p),

                  _sectionDivider(),

                  // ── NEARBY ─────────────────────────────────────────────
                  _buildNearbyCard(p),

                  _sectionDivider(),

                  // ── RULES & REGULATIONS ───────────────────────────────
                  if (p['rulesAndRegulation'] != null ||
                      _list(p['restrictions']).isNotEmpty) ...[
                    _buildRulesCard(p),
                    _sectionDivider(),
                  ],

                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(p),
    );
  }

  // ══════════════════════════════ SECTIONS ════════════════════════════════

  // ── Image gallery ──────────────────────────────────────────────────────

  Widget _buildImageGallery(List images, Map<String, dynamic> p) {
    final imgCount = images.isEmpty ? 1 : images.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        if (imgCount <= 1 || !_imgCtrl.hasClients) return;
        final newOffset = _imgCtrl.offset - details.delta.dx;
        _imgCtrl.jumpTo(
          newOffset.clamp(0.0, _imgCtrl.position.maxScrollExtent),
        );
      },
      onHorizontalDragEnd: (details) {
        if (imgCount <= 1 || !_imgCtrl.hasClients) return;
        final velocity = details.primaryVelocity ?? 0;
        final currentPage = _imgCtrl.page ?? _activeImg.toDouble();

        int targetPage;
        if (velocity < -300) {
          targetPage = (_activeImg + 1).clamp(0, imgCount - 1);
        } else if (velocity > 300) {
          targetPage = (_activeImg - 1).clamp(0, imgCount - 1);
        } else {
          targetPage = currentPage.round().clamp(0, imgCount - 1);
        }

        _imgCtrl.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Images ──────────────────────────────────────────────────
          PageView.builder(
            controller: _imgCtrl,
            physics: const NeverScrollableScrollPhysics(), // 👈 key fix
            itemCount: imgCount,
            onPageChanged: (i) => setState(() => _activeImg = i),
            itemBuilder: (_, i) {
              if (images.isEmpty) return _noImg(double.infinity);
              return buildPropertyImage(
                images[i],
                fit: BoxFit.cover,
                baseUrl: _base,
                placeholder: () => _noImg(double.infinity),
              );
            },
          ),

          // ── Top gradient ─────────────────────────────────────────────
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),

          // ── Bottom gradient ──────────────────────────────────────────
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

          // ── Dot indicators ────────────────────────────────────────────
          if (imgCount > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 60, // leave room for counter badge
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(imgCount > 10 ? 10 : imgCount, (i) {
                  final isActive =
                      i == _activeImg ||
                      (imgCount > 10 && i == 9 && _activeImg >= 9);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // ── Counter badge ────────────────────────────────────────────
          Positioned(
            bottom: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_activeImg + 1} / $imgCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Title card ─────────────────────────────────────────────────────────

  Widget _buildTitleCard(
    Map<String, dynamic> p,
    String address,
    List<Map<String, dynamic>> rooms,
  ) {
    final name =
        (p['propertyName'] ??
                p['propertyType2'] ??
                p['propertyType'] ??
                "Property")
            .toString();
    final type2 = (p['propertyType2'] ?? p['propertyType'] ?? '').toString();
    final postedAgo = _ago(p['createdAt']);

    return _card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property name
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.text1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),

          // Address row
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: _C.text3),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  address.isNotEmpty ? address : (p['city']?.toString() ?? ""),
                  style: const TextStyle(fontSize: 12, color: _C.text2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Type + posted
          Row(
            children: [
              Icon(
                _isPG ? Icons.group_outlined : Icons.person_outline_rounded,
                size: 13,
                color: _C.text2,
              ),
              const SizedBox(width: 4),
              Text(
                _isPG
                    ? pgGenderLabel(p)
                    : (type2.isNotEmpty ? type2 : "Property"),
                style: const TextStyle(
                  fontSize: 12,
                  color: _C.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Text("•", style: TextStyle(fontSize: 12, color: _C.text3)),
              const SizedBox(width: 8),
              const Icon(Icons.access_time_rounded, size: 12, color: _C.text3),
              const SizedBox(width: 4),
              Text(
                "Posted $postedAgo",
                style: const TextStyle(fontSize: 12, color: _C.text3),
              ),
            ],
          ),

          if (_isPG && rooms.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildRoomPricePills(rooms),
          ] else ...[
            const SizedBox(height: 14),
            _buildSinglePrice(p),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomPricePills(List<Map<String, dynamic>> rooms) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: rooms.map((room) {
          final idx = rooms.indexOf(room);
          final isSelected = idx == _selectedRoomIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRoomIndex = idx;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF9E6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE2A93E)
                      : const Color(0xFFE8ECF2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatSharingName(room['name'].toString()),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFB45309)
                          : const Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        room['rent'] != null ? _fmt(room['rent']) : "—",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFFB45309)
                              : const Color(0xFF1B2D3E),
                        ),
                      ),
                      Text(
                        "/mo",
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? const Color(0xFFB45309).withOpacity(0.7)
                              : const Color(0xFF9AA5B4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSinglePrice(Map<String, dynamic> p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p['rent'] != null ? _fmt(p['rent']) : "Price on request",
              style: TextStyle(
                fontSize: p['rent'] != null ? 26 : 16,
                fontWeight: FontWeight.w800,
                color: _C.primary,
              ),
            ),
            if (p['rent'] != null)
              const Text(
                "/month",
                style: TextStyle(fontSize: 12, color: _C.text3),
              ),
          ],
        ),
        const Spacer(),
        if (p['deposit'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "Deposit",
                style: TextStyle(fontSize: 10, color: _C.text3),
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
    );
  }

  // ── About card ─────────────────────────────────────────────────────────

  Widget _buildAboutCard(Map<String, dynamic> p) {
    final desc = (p['propertyDescription'] ?? p['description'] ?? "")
        .toString();
    final long = desc.length > 150;
    return Container(
      width: double.infinity,
      color: _C.bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("About Property"),
          const SizedBox(height: 4),
          Text(
            desc.isEmpty ? "No description provided." : desc,
            style: const TextStyle(
              fontSize: 13.5,
              color: _C.text2,
              height: 1.65,
            ),
            maxLines: _descExpanded ? null : 4,
            overflow: _descExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          if (long) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(
                _descExpanded ? "Show less ▲" : "Read more ›",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Overview card (table layout as requested) ─────────────────────────

  Widget _buildOverviewCard(Map<String, dynamic> p) {
    // Notice period badge
    final noticePeriod = p['noticePeriod'] ?? 15;
    final foodVal = p['foodIncluded'] == true
        ? (_text(p['foodType']).isNotEmpty ? _text(p['foodType']) : "Included")
        : "No Food";
    final foodLabel = "Food Facility";

    // Build overview rows — each row has 2 items
    final overviewItems = <_OverviewItem>[];

    void tryAdd(
      IconData icon,
      dynamic rawVal,
      String label, {
      String? fallback,
    }) {
      final val = rawVal?.toString() ?? fallback ?? '';
      if (val.trim().isNotEmpty) {
        overviewItems.add(_OverviewItem(icon, val, label));
      }
    }

    if (_isPG) {
      tryAdd(
        Icons.person_outline_rounded,
        p['gender'] != null ? _capitalize(p['gender'].toString()) : null,
        "PG for",
        fallback: "Male",
      );

      final tenantList = _list(p['preferredTenant']);
      final tenantVal = tenantList.isNotEmpty
          ? tenantList.map((e) => _capitalize(e.toString())).join(', ')
          : "Student";
      tryAdd(Icons.school_outlined, tenantVal, "Preferred Tenant");

      tryAdd(
        Icons.local_parking_rounded,
        p['parking'],
        "Parking",
        fallback: "Bike & Car",
      );

      overviewItems.add(
        _OverviewItem(Icons.restaurant_rounded, foodVal, foodLabel),
      );

      final postedDate = p['availableFrom'] != null
          ? _fmtDate(p['availableFrom'])
          : (p['createdAt'] != null
                ? _fmtDate(p['createdAt'])
                : "Mar 11, 2026");
      tryAdd(Icons.calendar_month_outlined, postedDate, "Posted On");

      tryAdd(
        Icons.access_time_rounded,
        p['gateClosingTime'],
        "Gate closing Time",
        fallback: "11:00 pm",
      );
    } else {
      tryAdd(
        Icons.person_outline_rounded,
        p['gender'] != null ? _capitalize(p['gender'].toString()) : null,
        "Gender Preference",
      );
      tryAdd(
        Icons.school_outlined,
        p['preferredTenant'] != null ? _text(p['preferredTenant']) : null,
        "Preferred Tenant",
      );
      tryAdd(Icons.local_parking_rounded, p['parking'], "Parking");
      if (p['availableFrom'] != null) {
        tryAdd(
          Icons.calendar_today_rounded,
          _fmtDate(p['availableFrom']),
          "Available From",
        );
      }
      if (p['floor'] != null) {
        tryAdd(
          Icons.layers_rounded,
          "${p['floor']}${p['totalFloor'] != null ? ' / ${p['totalFloor']}' : ''}",
          "Floor",
        );
      }
      if (p['builtUpArea'] != null) {
        tryAdd(
          Icons.square_foot_rounded,
          "${p['builtUpArea']} sq.ft",
          "Built-up Area",
        );
      }
      if (p['facing'] != null)
        tryAdd(Icons.explore_rounded, p['facing'], "Facing");
      if (p['propertyAge'] != null)
        tryAdd(Icons.home_rounded, p['propertyAge'], "Property Age");
      if (p['occupancy'] != null)
        tryAdd(Icons.vpn_key_rounded, p['occupancy'], "Occupancy");
    }

    if (overviewItems.isEmpty) return const SizedBox.shrink();

    // Pair items into rows of 2
    final rows = <List<_OverviewItem>>[];
    for (int i = 0; i < overviewItems.length; i += 2) {
      rows.add([
        overviewItems[i],
        if (i + 1 < overviewItems.length) overviewItems[i + 1],
      ]);
    }

    return _card(
      padding: const EdgeInsets.fromLTRB(8.5, 16, 8.5, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader("Overview"),
              const Spacer(),
              if (_isPG)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _C.primaryDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Notice Period :$noticePeriod Days",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Table layout
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: _C.border, width: 1),
                  verticalInside: BorderSide(color: _C.border, width: 1),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                },
                children: rows.map((row) {
                  return TableRow(
                    children: [
                      _overviewCell(row[0]),
                      row.length > 1 ? _overviewCell(row[1]) : const SizedBox(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCell(_OverviewItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(item.icon, size: 20, color: _C.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 11, color: _C.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rooms card ─────────────────────────────────────────────────────────

  Widget _buildRoomsCard(List<Map<String, dynamic>> rooms) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rooms.map((room) => _buildRoomTile(room)).toList(),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final amenities = _list(room['amenities']);
    final icons = _roomAmenIcons(amenities);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          // Top row: name + price + book button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatSharingName(room['name'].toString()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          room['rent'] != null ? _fmt(room['rent']) : "—",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _C.text1,
                          ),
                        ),
                        const Text(
                          " /month",
                          style: TextStyle(fontSize: 12, color: _C.text3),
                        ),
                      ],
                    ),
                    if (room['deposit'] != null)
                      Text(
                        "Deposit ${_fmt(room['deposit'])}",
                        style: const TextStyle(fontSize: 11, color: _C.text3),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 151,
                height: 28,
                child: ElevatedButton(
                  onPressed: () {
                    final p = _prop!;
                    final propertyId = int.tryParse(p['id'].toString());
                    if (propertyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invalid property ID")),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitSchedulerScreen(
                          propertyId: propertyId,
                          propertyType: 'PG',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primaryDark,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Book",
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

          const SizedBox(height: 8),

          // Amenity icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: icons.map((a) => _amenIconCol(a)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _amenIconCol(_AmenItem a) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(a.icon, size: 22, color: _C.text2),
        const SizedBox(height: 5),
        Text(
          a.label,
          style: const TextStyle(fontSize: 10, color: _C.text3),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<_AmenItem> _roomAmenIcons(List amenities) {
    return [
      const _AmenItem(Icons.checkroom_rounded, "Cupboard", _C.text2),
      const _AmenItem(Icons.ac_unit_rounded, "AC", _C.text2),
      const _AmenItem(Icons.remove_red_eye_rounded, "Att. Bath", _C.text2),
      const _AmenItem(Icons.tv_outlined, "TV", _C.text2),
      const _AmenItem(Icons.wifi_rounded, "Wifi", _C.text2),
    ];
  }

  // ── Amenities card ─────────────────────────────────────────────────────

  Widget _buildAmenitiesCard(Map<String, dynamic> p) {
    final items = _extractAmenities(p);
    if (items.isEmpty) return const SizedBox.shrink();
    final show = _amenExpanded ? items : items.take(6).toList();

    return _card(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Amenities"),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              ...show.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
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
              }),
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

  List<_AmenItem> _extractAmenities(Map<String, dynamic> p) {
    final items = <_AmenItem>[];
    void add(bool condition, IconData icon, String label) {
      if (condition) items.add(_AmenItem(icon, label, _C.text2));
    }

    final pgAmenText = _text(p['pgAmenities']).toLowerCase();
    add(
      p['wifi'] == true || pgAmenText.contains('wifi'),
      Icons.wifi_rounded,
      "WiFi",
    );
    add(
      pgAmenText.contains('ac') || pgAmenText.contains('air'),
      Icons.ac_unit_rounded,
      "AC",
    );
    add(pgAmenText.contains('gym'), Icons.people_outline_rounded, "Gym");
    add(pgAmenText.contains('cctv'), Icons.shield_outlined, "CCTV");
    add(
      p['powerBackup'] == true || pgAmenText.contains('power'),
      Icons.bolt_rounded,
      "Power Backup",
    );
    add(
      p['mess'] == true || pgAmenText.contains('mess'),
      Icons.restaurant_rounded,
      "Mess",
    );
    add(
      p['laundry'] != null || pgAmenText.contains('laundry'),
      Icons.local_laundry_service_rounded,
      "Laundry",
    );
    add(p['parking'] != null, Icons.local_parking_rounded, "Parking");
    add(p['lift'] != null, Icons.elevator_rounded, "Lift");

    final existingLabels = items.map((i) => i.label.toLowerCase()).toSet();
    for (final a in _list(p['pgAmenities'])) {
      final name = a.toString().toLowerCase();
      if (existingLabels.contains(name)) continue;
      existingLabels.add(name);
      IconData icon = Icons.check_circle_outline_rounded;
      if (name.contains('gym')) icon = Icons.people_outline_rounded;
      if (name.contains('pool')) icon = Icons.pool_rounded;
      if (name.contains('park')) icon = Icons.park_rounded;
      if (name.contains('cctv')) icon = Icons.shield_outlined;
      if (name.contains('ac')) icon = Icons.ac_unit_rounded;
      items.add(_AmenItem(icon, a.toString(), _C.text2));
    }
    return items;
  }

  // ── Contact card ────────────────────────────────────────────────────────

  Widget _buildContactCard(Map<String, dynamic> p) {
    final name = (p['contactName'] ?? p['ownerName'] ?? "Owner").toString();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "?";
    final rawOwner = p['userId'] ?? p['ownerId'];
    final ownerId = rawOwner is Map
        ? (rawOwner['id'] as num?)?.toInt()
        : int.tryParse(rawOwner?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border, width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.green,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Chat Now button
            GestureDetector(
              onTap: () {
                final propertyId = int.tryParse(p['id']?.toString() ?? '');
                if (propertyId == null || ownerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Chat unavailable for this property"),
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _C.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Chat now",
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
    );
  }

  // ── Nearby card ─────────────────────────────────────────────────────────

  Widget _buildNearbyItemCard(_NearbyItem item) {
    return GestureDetector(
      onTap: () {
        if (item.pgId != null && item.pgId! > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(propertyId: item.pgId!),
            ),
          );
        }
      },
      child: Container(
        width: 198.21,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF2)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade100,
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 24,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _C.text1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.type,
                    style: const TextStyle(fontSize: 11, color: _C.text3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: _C.green,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.distance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _C.green,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildNearbyCard(Map<String, dynamic> p) {
    if (_nearbyLoading) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Nearby"),
            const SizedBox(height: 14),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _C.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_nearby.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Nearby"),
            const SizedBox(height: 12),
            const Text(
              "No nearby PGs found.",
              style: TextStyle(fontSize: 13, color: _C.text3),
            ),
          ],
        ),
      );
    }

    if (_isPG) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Nearby"),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _nearby.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildNearbyItemCard(item),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Nearby"),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: _nearby.length,
            itemBuilder: (_, i) {
              final item = _nearby[i];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _C.text1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.type,
                            style: const TextStyle(
                              fontSize: 9,
                              color: _C.text3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 9,
                                color: _C.green,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  item.distance,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _C.green,
                                    fontWeight: FontWeight.w600,
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
            },
          ),
        ],
      ),
    );
  }

  // ── Rules card ─────────────────────────────────────────────────────────

  Widget _buildRulesCard(Map<String, dynamic> p) {
    final rules = p['rulesAndRegulation']?.toString() ?? "";
    final rawRestrictions = p['restrictions'];
    final list = <String>[];

    if (rawRestrictions is Map) {
      if (rawRestrictions['smoking'] == true) list.add("No smoking");
      if (rawRestrictions['drinking'] == true) list.add("No Drinking");
      if (rawRestrictions['loudMusic'] == true) list.add("No Loud Music");
      if (rawRestrictions['nonVeg'] == true) list.add("No Non-Veg");
      if (rawRestrictions['girlsEntry'] == true) list.add("No Girls Entry");
    } else if (rawRestrictions is List) {
      for (final r in rawRestrictions) {
        list.add(r.toString());
      }
    } else if (rawRestrictions is String && rawRestrictions.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawRestrictions);
        if (parsed is Map) {
          if (parsed['smoking'] == true) list.add("No smoking");
          if (parsed['drinking'] == true) list.add("No Drinking");
          if (parsed['loudMusic'] == true) list.add("No Loud Music");
          if (parsed['nonVeg'] == true) list.add("No Non-Veg");
          if (parsed['girlsEntry'] == true) list.add("No Girls Entry");
        } else if (parsed is List) {
          for (final r in parsed) {
            list.add(r.toString());
          }
        }
      } catch (_) {
        list.add(rawRestrictions);
      }
    }

    if (list.isEmpty && rules.isEmpty) return const SizedBox.shrink();

    return _card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: _C.text2),
                const SizedBox(width: 8),
                const Text(
                  "Rules & Regulations",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.text1,
                  ),
                ),
                const Spacer(),
                Icon(
                  _rulesExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.text3,
                  size: 22,
                ),
              ],
            ),
          ),
          if (_rulesExpanded) ...[
            const SizedBox(height: 12),
            if (list.isNotEmpty)
              ...list.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 5, color: _C.text2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.text2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (rules.isNotEmpty)
              Text(
                rules,
                style: const TextStyle(
                  fontSize: 13,
                  color: _C.text2,
                  height: 1.6,
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Bottom action bar ──────────────────────────────────────────────────

  Widget _buildBottomBar(Map<String, dynamic> p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border, width: 1),
                ),
                alignment: Alignment.center,
                child: SvgPicture.string(
                  '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M20 2H4C2.9 2 2.01 2.9 2.01 4L2 22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2ZM18 14H6V12H18V14ZM18 11H6V9H18V11ZM18 8H6V6H18V8Z" fill="#1C2B3A"/>
</svg>''',
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 10),

              // Contact button
              Expanded(
                flex: 111,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: _C.border, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: p['mobileNo'] != null
                        ? () => _launch("tel:${p['mobileNo']}")
                        : null,
                    icon: const Icon(
                      Icons.phone_rounded,
                      color: _C.primary,
                      size: 18,
                    ),
                    label: const Text(
                      "Contact",
                      style: TextStyle(
                        color: _C.primary,
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
                flex: 164,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primaryDark,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final propertyId = int.tryParse(p['id'].toString());
                      if (propertyId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Invalid property ID")),
                        );
                        return;
                      }
                      final propertyType =
                          (p['propertyType']?.toString().trim().isNotEmpty ??
                              false)
                          ? p['propertyType'].toString()
                          : (p['propertyType2']?.toString().trim().isNotEmpty ??
                                false)
                          ? p['propertyType2'].toString()
                          : 'PG';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisitSchedulerScreen(
                            propertyId: propertyId,
                            propertyType: propertyType,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Schedule Visit",
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

  // ══════════════════════════════ SMALL HELPERS ════════════════════════════

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      color: _C.card,
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _sectionDivider() => Container(height: 8, color: _C.bg);

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _C.text1,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _circleBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _noImg(double h) {
    return Container(
      height: h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.primaryDark, _C.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.apartment_rounded, size: 60, color: Colors.white30),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // ── Skeleton ────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _shimmer(double.infinity, 280),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmer(200, 22),
                  const SizedBox(height: 10),
                  _shimmer(150, 14),
                  const SizedBox(height: 20),
                  _shimmer(double.infinity, 56),
                  const SizedBox(height: 16),
                  _shimmer(double.infinity, 100),
                  const SizedBox(height: 16),
                  _shimmer(double.infinity, 160),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmer(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF0),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // ── Error screen ─────────────────────────────────────────────────────────

  Widget _buildError() {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primaryDark,
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
                  color: _C.primaryLight,
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
                "Something went wrong",
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
                      "Go Back",
                      style: TextStyle(color: _C.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Retry",
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
}

// ─── Data models ──────────────────────────────────────────────────────────────

class _AmenItem {
  final IconData icon;
  final String label;
  final Color color;
  const _AmenItem(this.icon, this.label, this.color);
}

class _OverviewItem {
  final IconData icon;
  final String value;
  final String label;
  const _OverviewItem(this.icon, this.value, this.label);
}

class _NearbyItem {
  final String imageUrl;
  final String name;
  final String type;
  final String distance;
  final int? pgId;
  const _NearbyItem(
    this.imageUrl,
    this.name,
    this.type,
    this.distance, {
    this.pgId,
  });
}
