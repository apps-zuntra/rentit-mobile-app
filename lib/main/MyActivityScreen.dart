// my_activity_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/ApartmentPropertyDetails.dart';
import 'package:rentit/ViewDetailsPages/Commercial/CommercialPropertyDetails.dart';
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/FlatmatePropertyDetails.dart';
import 'package:rentit/feature/like/provider/like_provider.dart';
import 'package:rentit/main/PropertyDetails.dart';
import 'package:rentit/core/image_utils.dart';
import 'package:rentit/core/property_utils.dart';

import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:rentit/screen/visit_scheduler_screen.dart';

abstract class ApiConstants {
  static const String baseUrl = "https://rentit-backend-omega.vercel.app";
}

bool _hasValidMap(Map<String, dynamic> item, String key) {
  final val = item[key];
  if (val is Map && val.isNotEmpty) return true;
  if (val is List && val.isNotEmpty) {
    final first = val.first;
    if (first is Map && first.isNotEmpty) return true;
  }
  return false;
}

Widget _getDetailScreen(
  Map<String, dynamic> item,
  Map<String, dynamic> nestedProp,
  int resolvedId,
) {
  // ── 1. Explicit ID fields — most reliable ──────────────────────────────────
  if (_safeInt(item['flatmateId']) > 0) {
    return FlatmateDetailScreen(propertyId: resolvedId);
  }
  if (_safeInt(item['commercialId']) > 0) {
    return CommercialPropertyDetailScreen(propertyId: resolvedId);
  }
  if (_safeInt(item['apartmentId']) > 0) {
    return ApartmentPropertyDetailScreen(propertyId: resolvedId);
  }

  // ── 2. Nested object key ───────────────────────────────────────────────────
  if (_hasValidMap(item, 'flatmate') ||
      _hasValidMap(item, 'flatmates') ||
      _hasValidMap(item, 'flatemate')) {
    return FlatmateDetailScreen(propertyId: resolvedId);
  }
  if (_hasValidMap(item, 'commercial')) {
    return CommercialPropertyDetailScreen(propertyId: resolvedId);
  }
  if (_hasValidMap(item, 'apartment')) {
    // Could still be an apartment OR commercial — check propertyType below.
    // Fall through to type-string check first.
  }

  // ── 3. propertyType / apartmentType string inside nested object ────────────
  final typeRaw =
      (nestedProp['propertyType'] ??
              nestedProp['apartmentType'] ??
              nestedProp['commercialPropertyType'] ??
              item['propertyType'] ??
              item['apartmentType'] ??
              '')
          .toString()
          .toUpperCase();

  if (typeRaw.contains('FLATMATE')) {
    return FlatmateDetailScreen(propertyId: resolvedId);
  }
  if (typeRaw.contains('COMMERCIAL') ||
      (nestedProp['commercialPropertyType']?.toString().isNotEmpty ?? false)) {
    return CommercialPropertyDetailScreen(propertyId: resolvedId);
  }
  if (typeRaw.contains('PG') || typeRaw.contains('HOSTEL')) {
    return PropertyDetailScreen(propertyId: resolvedId);
  }
  if (typeRaw.contains('APARTMENT') ||
      (nestedProp['bhkType']?.toString().isNotEmpty ?? false) ||
      (nestedProp['apartmentType']?.toString().isNotEmpty ?? false)) {
    return ApartmentPropertyDetailScreen(propertyId: resolvedId);
  }

  // ── 4. Apartment nested key (deferred from step 2) ─────────────────────────
  if (_hasValidMap(item, 'apartment')) {
    return ApartmentPropertyDetailScreen(propertyId: resolvedId);
  }

  // ── 5. PG / Hostel — propertyId or property nested key ────────────────────
  // homeId / home → treated as PG-style unified property
  return PropertyDetailScreen(propertyId: resolvedId);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────────────────────

const Color _primary = Color(0xFF1A2B40);
const Color _primaryLight = Color(0xFFF0FAF4);
const Color _green = Color(0xFF0A7C66);
const Color _orange = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _text = Color(0xFF111827);
const Color _text2 = Color(0xFF4B5563);
const Color _text3 = Color(0xFF9CA3AF);
const Color _border = Color(0xFFE5E7EB);
const Color _bg = Color(0xFFF5F6F8);

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
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

List<String> _parseImages(dynamic val) {
  return extractPropertyImages(val, ApiConstants.baseUrl);
}

List<String> _getFeatures(Map<String, dynamic> p) {
  final features = <String>[];

  final sqft = p['builtUpArea'] ?? p['area'] ?? p['squareFeet'] ?? p['sqft'];
  if (sqft != null &&
      sqft.toString().trim().isNotEmpty &&
      sqft.toString() != '0') {
    features.add('${sqft.toString().trim()} sq.ft');
  }

  final furnishing = formatFurnishing(p['furnishing']);
  if (furnishing.isNotEmpty) {
    features.add(furnishing);
  }

  final floor = p['floor'] ?? p['floorNo'];
  if (floor != null && floor.toString().trim().isNotEmpty) {
    features.add('Floor ${floor.toString().trim()}');
  }

  final bhk = p['bhkType']?.toString().trim();
  if (bhk != null && bhk.isNotEmpty) {
    features.add(bhk);
  }

  final amenities = _parseList(p['amenities']);
  features.addAll(
    amenities.map((e) => e.toString().trim()).where((s) => s.isNotEmpty),
  );

  final pgAmenities = p['pgAmenities'];
  if (pgAmenities is Map) {
    pgAmenities.forEach((key, value) {
      if (value == true) {
        features.add(
          key
              .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
              .trim(),
        );
      }
    });
  }

  final parking = (p['parking'] ?? '').toString().trim();
  if (parking.isNotEmpty &&
      parking.toLowerCase() != 'none' &&
      parking.toLowerCase() != 'null') {
    features.add('Parking');
  }
  if (p['petAllowed'] == true) features.add('Pet Friendly');
  if (p['foodIncluded'] == true) features.add('Food Included');

  return features.toSet().toList();
}

String _apartmentTitle(Map<String, dynamic> p) {
  final parts = <String>[
    if (p['bhkType'] != null) p['bhkType'].toString(),
    if (p['apartmentType'] != null) p['apartmentType'].toString(),
    if (p['buildingType'] != null) p['buildingType'].toString(),
  ];
  return parts.isNotEmpty ? parts.join(' ') : 'Apartment';
}

String _getAddress(Map<String, dynamic> p) {
  final street = (p['street'] ?? '').toString().trim();
  final landmark = (p['landmark'] ?? '').toString().trim();
  final city = (p['city'] ?? '').toString().trim();

  final parts = <String>[];

  if (street.isNotEmpty && street.toLowerCase() != 'null') {
    parts.add(street);
  }
  if (landmark.isNotEmpty &&
      landmark.toLowerCase() != 'null' &&
      landmark != street) {
    parts.add(landmark);
  }
  if (city.isNotEmpty && city.toLowerCase() != 'null') {
    parts.add(city);
  }

  return parts.isNotEmpty ? parts.join(', ') : 'Location not available';
}

String? _formatRent(dynamic val) {
  if (val == null) return null;
  final num = double.tryParse(val.toString());
  if (num == null || num <= 0) return null;
  final s = num.toInt().toString();
  if (s.length <= 3) return '₹$s';
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
  return '₹${buf.toString().split('').reversed.join()},$last3';
}

String _shortAgo(dynamic createdAt) {
  if (createdAt == null) return '';
  try {
    final diff = DateTime.now().difference(
      DateTime.parse(createdAt.toString()),
    );
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'just now';
  } catch (_) {
    return '';
  }
}

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

String? _extractDate(dynamic raw) {
  if (raw == null) return null;
  try {
    final dt = DateTime.parse(raw.toString());
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return null;
  }
}

String? _extractTime(dynamic raw) {
  if (raw == null) return null;
  try {
    final dt = DateTime.parse(raw.toString());
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return null;
  }
}

String _buildTitle(Map<String, dynamic> p) {
  final localityRaw = p['locality']?.toString().trim() ?? '';
  final locality = localityRaw.toLowerCase() == 'unknown' ? '' : localityRaw;

  // Commercial
  final commType =
      (p['commercialPropertyType'] ?? p['spaceType'] ?? p['commercialType'])
          ?.toString()
          .trim() ??
      '';
  if (commType.isNotEmpty) {
    return locality.isNotEmpty ? '$commType in $locality' : commType;
  }

  // Apartment / Villa
  final bhk = p['bhkType']?.toString().trim() ?? '';
  final aptType =
      (p['apartmentType'] ?? p['buildingType'])?.toString().trim() ?? '';
  if (bhk.isNotEmpty || aptType.isNotEmpty) {
    final typeName = [bhk, aptType].where((s) => s.isNotEmpty).join(' ');
    return locality.isNotEmpty ? '$typeName in $locality' : typeName;
  }

  // Flatmate
  final roomTypeStr = p['roomType']?.toString().trim() ?? '';
  if (p['flatmateId'] != null || p['flatmate'] != null) {
    final name = roomTypeStr.isNotEmpty ? roomTypeStr : 'Flatmate Listing';
    return locality.isNotEmpty ? '$name in $locality' : name;
  }

  // Generic Property Name / Type
  final propertyName = p['propertyName']?.toString().trim() ?? '';
  if (propertyName.isNotEmpty) {
    return locality.isNotEmpty ? '$propertyName in $locality' : propertyName;
  }

  final villaType = p['villaType']?.toString().trim() ?? '';
  if (villaType.isNotEmpty) {
    return locality.isNotEmpty
        ? '$villaType Villa in $locality'
        : '$villaType Villa';
  }

  final propertyType = p['propertyType']?.toString().trim() ?? '';
  if (propertyType.isNotEmpty && propertyType.toLowerCase() != 'null') {
    return locality.isNotEmpty ? '$propertyType in $locality' : propertyType;
  }

  return locality.isNotEmpty ? 'Property in $locality' : 'Property';
}

String _buildAddress(Map<String, dynamic> p) {
  final parts = [p['locality'], p['city']]
      .where(
        (e) =>
            e != null &&
            e.toString().trim().isNotEmpty &&
            e.toString().toLowerCase() != 'unknown',
      )
      .map((e) => e.toString().trim())
      .toSet()
      .toList();
  final loc = parts.isNotEmpty
      ? parts.join(', ')
      : (p['street']?.toString() ?? '');
  if (loc.isNotEmpty && loc.toLowerCase() != 'null') return loc;
  final fallback =
      (p['location'] ??
              p['address'] ??
              p['fullAddress'] ??
              p['googleAddress'] ??
              '')
          .toString()
          .trim();
  return (fallback.isNotEmpty && fallback.toLowerCase() != 'null')
      ? fallback
      : 'Location on Request';
}

String _tenantType(Map<String, dynamic> apartment) {
  final tenants = _parseList(apartment['preferredTenant']);
  if (tenants.isNotEmpty) return tenants.first.toString();
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
//  RESOLVE NESTED PROPERTY OBJECT  (shared by shortlist + visits)
// ─────────────────────────────────────────────────────────────────────────────

/// Extracts the nested property map from a liked / visit item.
/// Checks all known key names in priority order.
Map<String, dynamic>? _getValid(Map<String, dynamic> item, String key) {
  final val = item[key];
  if (val is Map && val.isNotEmpty) return Map<String, dynamic>.from(val);
  if (val is List && val.isNotEmpty) {
    final first = val.first;
    if (first is Map && first.isNotEmpty)
      return Map<String, dynamic>.from(first);
  }
  return null;
}

Map<String, dynamic> _extractNestedProp(Map<String, dynamic> item) {
  final valid =
      _getValid(item, 'commercial') ??
      _getValid(item, 'apartment') ??
      _getValid(item, 'flatmate') ??
      _getValid(item, 'flatmates') ??
      _getValid(item, 'flatemate') ??
      _getValid(item, 'property') ??
      _getValid(item, 'pg') ??
      _getValid(item, 'home');

  final res = Map<String, dynamic>.from(item);
  if (valid != null) {
    res.addAll(valid);
  }
  return res;
}

/// Resolves the integer ID for the nested property from a liked / visit item.
int _resolveId(Map<String, dynamic> item, Map<String, dynamic> nestedProp) {
  // Explicit typed IDs first
  final flatmateId = _safeInt(item['flatmateId']);
  if (flatmateId > 0) return flatmateId;

  final commercialId = _safeInt(item['commercialId']);
  if (commercialId > 0) return commercialId;

  final apartmentId = _safeInt(item['apartmentId']);
  if (apartmentId > 0) return apartmentId;

  final propertyId = _safeInt(item['propertyId']);
  if (propertyId > 0) return propertyId;

  final homeId = _safeInt(item['homeId']);
  if (homeId > 0) return homeId;

  // Fallback to nested prop's own id
  return _safeInt(nestedProp['id']);
}

// ═════════════════════════════════════════════════════════════════════════════
//  MY ACTIVITY SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class MyActivityScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const MyActivityScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends ConsumerState<MyActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialIndex)
          ..addListener(() {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (r) => r.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final likesAsync = ref.watch(likeProvider);
    final visitsAsync = ref.watch(visitProvider);

    final shortlistCount = likesAsync.maybeWhen(
      data: (d) => d.length,
      orElse: () => 0,
    );
    final pendingVisitsCount = visitsAsync.maybeWhen(
      data: (d) => d
          .whereType<Map<String, dynamic>>()
          .where(
            (v) => [
              'pending',
              'confirmed',
              'calling',
            ].contains(v['status']?.toString().toLowerCase()),
          )
          .length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text(
          'My Activity',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Colors.black,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _SegmentedTabBar(
              controller: _tabController,
              shortlistCount: shortlistCount,
              visitsCount: pendingVisitsCount,
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ShortlistedTab(likesAsync: likesAsync, ref: ref),
          _VisitsTab(visitsAsync: visitsAsync, ref: ref),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEGMENTED TAB BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedTabBar extends StatelessWidget {
  final TabController controller;
  final int shortlistCount;
  final int visitsCount;

  const _SegmentedTabBar({
    required this.controller,
    required this.shortlistCount,
    required this.visitsCount,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TabBar(
      controller: controller,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.black,
      unselectedLabelColor: Colors.grey.shade500,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      indicator: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      tabs: [
        _tabLabel('Shortlisted', shortlistCount, controller.index == 0),
        _tabLabel('Visits', visitsCount, controller.index == 1),
      ],
    ),
  );

  Tab _tabLabel(String label, int count, bool active) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          _CountBadge(count: count, active: active),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  COUNT BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final bool active;
  const _CountBadge({required this.count, this.active = true});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF1A2B40) : Colors.grey.shade400,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHORTLISTED TAB  (clean rewrite)
// ═════════════════════════════════════════════════════════════════════════════

class _ShortlistedTab extends StatelessWidget {
  final AsyncValue<List<dynamic>> likesAsync;
  final WidgetRef ref;

  const _ShortlistedTab({required this.likesAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    return likesAsync.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (raw) {
        if (raw.isEmpty) return const _EmptyShortlist();

        final items = raw.whereType<Map<String, dynamic>>().toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _listHeader(
              '${items.length} saved ${items.length == 1 ? 'property' : 'properties'}',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final type =
                      _safeInt(item['flatmateId']) > 0 ||
                          item['flatmate'] != null
                      ? 'flatmate'
                      : _safeInt(item['commercialId']) > 0 ||
                            item['commercial'] != null ||
                            item['Commercial'] != null
                      ? 'commercial'
                      : _safeInt(item['apartmentId']) > 0 ||
                            item['apartment'] != null ||
                            item['Apartment'] != null
                      ? 'apartment'
                      : 'pg';
                  final id = _safeInt(item['flatmateId']) > 0
                      ? _safeInt(item['flatmateId'])
                      : _safeInt(item['commercialId']) > 0
                      ? _safeInt(item['commercialId'])
                      : _safeInt(item['apartmentId']) > 0
                      ? _safeInt(item['apartmentId'])
                      : _safeInt(item['propertyId']);
                  final savedAt = item['createdAt'] ?? item['updatedAt'];
                  return _ShortlistCard(
                    likeItem: item,
                    propertyId: id,
                    savedAt: savedAt,
                    onRemove: () {
                      if (id > 0)
                        ref.read(likeProvider.notifier).toggle(id, type);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHORTLIST CARD  (clean rewrite)
// ─────────────────────────────────────────────────────────────────────────────

class _ShortlistCard extends StatefulWidget {
  final Map<String, dynamic> likeItem;
  final int propertyId;
  final dynamic savedAt;
  final VoidCallback onRemove;

  const _ShortlistCard({
    required this.likeItem,
    required this.propertyId,
    required this.savedAt,
    required this.onRemove,
  });

  @override
  State<_ShortlistCard> createState() => _ShortlistCardState();
}

class _ShortlistCardState extends State<_ShortlistCard> {
  Map<String, dynamic>? _prop;
  String _type = 'property';
  bool _loading = true;

  static const _base = 'https://rentit-backend-omega.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (widget.propertyId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final headers = {'Authorization': 'Bearer $token'};

      final hasFlatmate =
          _safeInt(widget.likeItem['flatmateId']) > 0 ||
          (widget.likeItem['flatmate'] is Map &&
              (widget.likeItem['flatmate'] as Map).isNotEmpty);
      final hasCommercial =
          _safeInt(widget.likeItem['commercialId']) > 0 ||
          (widget.likeItem['commercial'] is Map &&
              (widget.likeItem['commercial'] as Map).isNotEmpty);
      final hasApartment =
          _safeInt(widget.likeItem['apartmentId']) > 0 ||
          (widget.likeItem['apartment'] is Map &&
              (widget.likeItem['apartment'] as Map).isNotEmpty);

      final candidates = <Map<String, String>>[];
      if (hasFlatmate)
        candidates.add({
          'url': '$_base/flatmate/${widget.propertyId}',
          'type': 'flatmate',
        });
      if (hasCommercial)
        candidates.add({
          'url': '$_base/commercial/${widget.propertyId}',
          'type': 'commercial',
        });
      if (hasApartment)
        candidates.add({
          'url': '$_base/apartment/${widget.propertyId}',
          'type': 'apartment',
        });

      for (final t in ['property', 'flatmate', 'commercial', 'apartment']) {
        final url = '$_base/$t/${widget.propertyId}';
        if (!candidates.any((c) => c['url'] == url)) {
          candidates.add({'url': url, 'type': t});
        }
      }

      for (final c in candidates) {
        try {
          final res = await http
              .get(Uri.parse(c['url']!), headers: headers)
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data is Map<String, dynamic> && data['id'] != null && mounted) {
              setState(() {
                _prop = data;
                _type = c['type']!;
                _loading = false;
              });
              return;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _title(Map<String, dynamic> p) {
    final loc = _locality(p);
    final comm = (p['commercialPropertyType'] ?? p['spaceType'] ?? '')
        .toString()
        .trim();
    if (comm.isNotEmpty) return loc.isNotEmpty ? '$comm in $loc' : comm;
    final bhk = (p['bhkType'] ?? '').toString().trim();
    final aptType = (p['apartmentType'] ?? p['buildingType'] ?? '')
        .toString()
        .trim();
    if (bhk.isNotEmpty || aptType.isNotEmpty) {
      final name = [bhk, aptType].where((s) => s.isNotEmpty).join(' ');
      return loc.isNotEmpty ? '$name in $loc' : name;
    }
    final roomType = (p['roomType'] ?? '').toString().trim();
    if (_type == 'flatmate' || p['tenantType'] != null) {
      final name = roomType.isNotEmpty ? roomType : 'Flatmate Listing';
      return loc.isNotEmpty ? '$name in $loc' : name;
    }
    final propName = (p['propertyName'] ?? '').toString().trim();
    if (propName.isNotEmpty)
      return loc.isNotEmpty ? '$propName in $loc' : propName;
    final propType = (p['propertyType'] ?? '').toString().trim();
    if (propType.isNotEmpty && propType.toLowerCase() != 'null') {
      return loc.isNotEmpty ? '$propType in $loc' : propType;
    }
    return loc.isNotEmpty ? 'Property in $loc' : 'Property';
  }

  String _locality(Map<String, dynamic> p) {
    return [p['locality'], p['city']]
        .where(
          (e) =>
              e != null &&
              e.toString().trim().isNotEmpty &&
              e.toString().toLowerCase() != 'unknown',
        )
        .map((e) => e.toString().trim())
        .toSet()
        .join(', ');
  }

  String _address(Map<String, dynamic> p) {
    final loc = _locality(p);
    if (loc.isNotEmpty) return loc;
    return (p['street'] ?? p['address'] ?? 'Location on Request')
        .toString()
        .trim();
  }

  String _rent(Map<String, dynamic> p) {
    dynamic rt = p['roomType'];
    if (rt is String && rt.trim().startsWith('[')) {
      try {
        rt = jsonDecode(rt);
      } catch (_) {}
    }
    if (rt is List && rt.isNotEmpty) {
      final rents =
          rt
              .map((r) => double.tryParse(r['rent']?.toString() ?? '') ?? 0.0)
              .where((r) => r > 0)
              .toList()
            ..sort();
      if (rents.isNotEmpty) return '\u20b9${_fmt(rents.first)}/mo';
    }
    final raw =
        p['expectedRent'] ?? p['rent'] ?? p['monthlyRent'] ?? p['price'];
    final num = double.tryParse(raw?.toString() ?? '');
    if (num != null && num > 0) return '\u20b9${_fmt(num)}/mo';
    return 'Rent on Call';
  }

  String _fmt(double n) {
    final s = n.toInt().toString();
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

  List<String> _chips(Map<String, dynamic> p) {
    final chips = <String>{};
    final bhk = (p['bhkType'] ?? '').toString().trim();
    if (bhk.isNotEmpty) chips.add(bhk);
    final furnishing = formatFurnishing(p['furnishing']);
    if (furnishing.isNotEmpty) chips.add(furnishing);
    final floor = p['floor'] ?? p['floorNo'];
    if (floor != null && floor.toString().isNotEmpty) chips.add('Floor $floor');
    final sqft = p['builtUpArea'] ?? p['area'] ?? p['squareFeet'];
    if (sqft != null && sqft.toString() != '0') chips.add('${sqft} sq.ft');
    final pgAm = p['pgAmenities'];
    if (pgAm is Map) {
      pgAm.forEach((k, v) {
        if (v == true)
          chips.add(
            k
                .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
                .trim(),
          );
      });
    }
    final amenities = _parseList(p['amenities']);
    chips.addAll(
      amenities.map((e) => e.toString().trim()).where((s) => s.isNotEmpty),
    );
    return chips.take(6).toList();
  }

  void _openDetails(BuildContext context) {
    if (widget.propertyId <= 0) return;
    Widget screen;
    switch (_type) {
      case 'flatmate':
        screen = FlatmateDetailScreen(propertyId: widget.propertyId);
        break;
      case 'commercial':
        screen = CommercialPropertyDetailScreen(propertyId: widget.propertyId);
        break;
      case 'apartment':
        screen = ApartmentPropertyDetailScreen(propertyId: widget.propertyId);
        break;
      default:
        screen = PropertyDetailScreen(propertyId: widget.propertyId);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final p = _prop;
    if (p == null) return const SizedBox.shrink();

    final images = _parseImages(p['images']);
    final title = _title(p);
    final address = _address(p);
    final rent = _rent(p);
    final chips = _chips(p);
    final timeLabel = _shortAgo(widget.savedAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                images.isNotEmpty
                    ? buildPropertyImage(
                        images.first,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        baseUrl: ApiConstants.baseUrl,
                        placeholder: () => _placeholder(),
                      )
                    : _placeholder(),
                if (timeLabel.isNotEmpty)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // BODY
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rent,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'FEATURES',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: chips
                        .map(
                          (e) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => _openDetails(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2B40),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: widget.onRemove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFCECEC),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Remove',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
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
    );
  }

  Widget _placeholder() => Container(
    height: 200,
    width: double.infinity,
    color: const Color(0xFFF0FAF4),
    child: const Center(
      child: Icon(Icons.apartment_outlined, size: 52, color: Color(0xFF0A7C66)),
    ),
  );
}
// ═════════════════════════════════════════════════════════════════════════════
//  VISITS TAB
// ═════════════════════════════════════════════════════════════════════════════

class _VisitsTab extends StatelessWidget {
  final AsyncValue<List<dynamic>> visitsAsync;
  final WidgetRef ref;

  const _VisitsTab({required this.visitsAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    return visitsAsync.when(
      loading: () => const _LoadingList(),
      error: (e, _) => _ErrorState(message: e.toString()),
      data: (raw) {
        final visits = raw.whereType<Map<String, dynamic>>().toList();
        if (visits.isEmpty) return const _EmptyVisits();

        final pending = visits
            .where(
              (v) => [
                'pending',
                'confirmed',
                'calling',
              ].contains(v['status']?.toString().toLowerCase()),
            )
            .length;
        final cancelled = visits
            .where((v) => v['status']?.toString().toLowerCase() == 'cancelled')
            .length;
        final subtitle =
            '$pending active${cancelled > 0 ? ' · $cancelled cancelled' : ''}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _listHeader(subtitle),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: visits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final visit = visits[i];
                  final nestedProp = _extractNestedProp(visit);
                  final visitId = _safeInt(visit['id']);

                  return _VisitCard(
                    visit: visit,
                    apartment: nestedProp,
                    onViewDetails: () =>
                        _openPropertyDetails(context, visit, nestedProp),
                    onReschedule: () =>
                        _openReschedule(context, visit, nestedProp, visitId),
                    onCancel: () {
                      if (visitId > 0) {
                        ref.read(visitProvider.notifier).cancelVisit(visitId);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openPropertyDetails(
    BuildContext context,
    Map<String, dynamic> visit,
    Map<String, dynamic> nestedProp,
  ) {
    final id = _resolveId(visit, nestedProp);
    if (id == 0 || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _getDetailScreen(visit, nestedProp, id),
      ),
    );
  }

  Future<void> _openReschedule(
    BuildContext context,
    Map<String, dynamic> visit,
    Map<String, dynamic> nestedProp,
    int visitId,
  ) async {
    final id = _resolveId(visit, nestedProp);
    if (id == 0 || !context.mounted) return;

    final rawDT = visit['visitDateTime'] ?? visit['scheduledAt'];
    final initialDate = _extractDate(rawDT) ?? visit['date']?.toString();
    final initialTime = _extractTime(rawDT) ?? visit['time']?.toString();
    final safeVisitId = visitId > 0 ? visitId : null;

    final type = _safeInt(visit['flatmateId']) > 0 || visit['flatmate'] != null
        ? 'flatmate'
        : _safeInt(visit['commercialId']) > 0 || visit['commercial'] != null
        ? 'commercial'
        : _safeInt(visit['apartmentId']) > 0 || visit['apartment'] != null
        ? 'apartment'
        : (visit['propertyType']?.toString() ?? 'pg');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitSchedulerScreen(
          propertyId: id,
          propertyType: type,
          visitId: safeVisitId,
          initialDate: initialDate,
          initialTime: initialTime,
        ),
      ),
    );

    if (result == true) {
      // ignore: unused_result
      ref.invalidate(visitProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  VISIT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final Map<String, dynamic> apartment;
  final VoidCallback onViewDetails;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  const _VisitCard({
    required this.visit,
    required this.apartment,
    required this.onViewDetails,
    required this.onReschedule,
    required this.onCancel,
  });

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Not scheduled';
    try {
      final dt = DateTime.parse(raw.toString());
      const months = [
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
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Invalid date';
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      return '$hour:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (visit['status'] ?? 'pending').toString().toLowerCase();
    final isPending = status == 'pending';
    final images = _parseImages(apartment['images']);
    final imageUrl = images.isNotEmpty ? images.first : null;
    final title = _buildTitle(apartment);
    final address = _getAddress(apartment);
    final dateText = _formatDate(visit['visitDateTime']);
    final timeText = _formatTime(visit['visitDateTime']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(imageUrl: imageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusPill(status: status),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      if (address.isNotEmpty) _AddressRow(address: address),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DateTimeRow(dateText: dateText, timeText: timeText),
            const SizedBox(height: 12),
            if (isPending)
              _PendingActions(
                onViewDetails: onViewDetails,
                onReschedule: onReschedule,
                onCancel: onCancel,
              )
            else
              _ViewDetailsButton(onPressed: onViewDetails),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _Thumbnail extends StatelessWidget {
  final String? imageUrl;
  const _Thumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: buildPropertyImage(
      imageUrl,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      baseUrl: ApiConstants.baseUrl,
      placeholder: () => _placeholder(),
    ),
  );

  Widget _placeholder() => Container(
    width: 90,
    height: 90,
    decoration: BoxDecoration(
      color: _primaryLight,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Center(
      child: Icon(Icons.apartment_outlined, size: 32, color: _green),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isCancelled = status == 'cancelled';

    final bg = isPending
        ? const Color(0xFFFFF3E0)
        : isCancelled
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFECFDF5);
    final border = isPending
        ? const Color(0xFFFFB74D)
        : isCancelled
        ? const Color(0xFFFFCDD2)
        : const Color(0xFF6EE7B7);
    final color = isPending
        ? const Color(0xFFE65100)
        : isCancelled
        ? _red
        : _green;
    final icon = isPending
        ? Icons.access_time_rounded
        : isCancelled
        ? Icons.cancel_outlined
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '${status[0].toUpperCase()}${status.substring(1)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final String address;
  const _AddressRow({required this.address});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 3),
      Expanded(
        child: Text(
          address,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _DateTimeRow extends StatelessWidget {
  final String dateText;
  final String timeText;
  const _DateTimeRow({required this.dateText, required this.timeText});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 6),
        Text(
          dateText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const Spacer(),
        Container(height: 20, width: 1, color: Colors.grey.shade400),
        const Spacer(),
        if (timeText.isNotEmpty) ...[
          Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            timeText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ],
    ),
  );
}

class _PendingActions extends StatelessWidget {
  final VoidCallback onViewDetails;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  const _PendingActions({
    required this.onViewDetails,
    required this.onReschedule,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: onViewDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'View Details',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: onReschedule,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Reschedule',
              style: TextStyle(
                fontSize: 13,
                color: _primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        height: 44,
        width: 44,
        child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFFEBEE),
            side: const BorderSide(color: Color(0xFFFFCDD2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Color(0xFFE53935),
            size: 20,
          ),
        ),
      ),
    ],
  );
}

class _ViewDetailsButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ViewDetailsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 40,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'View Details',
        style: TextStyle(
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED LIST HEADER
// ─────────────────────────────────────────────────────────────────────────────

Widget _listHeader(String text) => Container(
  width: double.infinity,
  color: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  child: Text(
    text,
    style: TextStyle(
      color: Colors.grey.shade600,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  ),
);

// ═════════════════════════════════════════════════════════════════════════════
//  EMPTY STATES
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyShortlist extends StatelessWidget {
  const _EmptyShortlist();

  @override
  Widget build(BuildContext context) => const _EmptyState(
    icon: Icons.favorite_border,
    title: 'No saved properties',
    subtitle: 'Tap the heart on any listing to save it here.',
  );
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();

  @override
  Widget build(BuildContext context) => _EmptyState(
    icon: Icons.calendar_today_outlined,
    title: 'No visits scheduled',
    subtitle: 'Schedule a visit from any property listing.',
    actionLabel: 'Browse Properties',
    onAction: () => Navigator.pop(context),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: _primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 36, color: _primary),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  LOADING / ERROR
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: 3,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (_, __) => Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(140, 14),
                const SizedBox(height: 8),
                _shimmer(100, 12),
                const SizedBox(height: 8),
                _shimmer(80, 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shimmer(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go back'),
          ),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  VISIT PROVIDER
// ═════════════════════════════════════════════════════════════════════════════

final visitProvider = AsyncNotifierProvider<VisitNotifier, List<dynamic>>(
  VisitNotifier.new,
);

class VisitNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() => _fetch();

  Future<List<dynamic>> _fetch() async {
    final token = await _token();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/visit/my'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    return [];
  }

  Future<void> cancelVisit(int visitId) async {
    final token = await _token();
    if (token == null) return;

    await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/visit/$visitId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    ref.invalidateSelf();
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');
}
