import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/core/image_utils.dart';

const String _pgBaseUrl = "https://rentit-backend-yti9.onrender.com";

// -------------------------------------------------------------
//  MODEL
// -------------------------------------------------------------
class PGListingModel {
  final int id;
  final String name;
  final String city;
  final String locality;
  final double rent;
  final bool foodIncluded;
  final String gender;
  final List<dynamic> images;
  final String sharingType;
  final List<Map<String, dynamic>> sharingOptions;
  final List<String> amenities;
  final String postedAgo;
  final bool isActive;
  final int views;
  final int contacted;

  PGListingModel({
    required this.id,
    required this.name,
    required this.city,
    required this.locality,
    required this.rent,
    required this.foodIncluded,
    required this.gender,
    required this.images,
    required this.sharingType,
    required this.sharingOptions,
    required this.amenities,
    required this.postedAgo,
    this.isActive = true,
    this.views = 0,
    this.contacted = 0,
  });

  factory PGListingModel.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> options = [];
    if (j["roomType"] != null) {
      try {
        final rt = j["roomType"] is String
            ? jsonDecode(j["roomType"])
            : j["roomType"];
        if (rt is Map) {
          rt.forEach((key, value) {
            if (value != null) options.add({"type": key, "price": value});
          });
        }
      } catch (_) {}
    }

    List<String> amen = [];
    if (j["pgAmenities"] != null) {
      try {
        final a = j["pgAmenities"] is String
            ? jsonDecode(j["pgAmenities"])
            : j["pgAmenities"];
        if (a is List) {
          amen = a.map((e) => e.toString()).toList();
        } else if (a is Map) {
          a.forEach((k, v) {
            if (v == true) amen.add(k.toString());
          });
        }
      } catch (_) {}
    }

    String ago = "Just now";
    if (j["createdAt"] != null) {
      try {
        final created = DateTime.parse(j["createdAt"]);
        final diff = DateTime.now().difference(created);
        if (diff.inDays > 0) {
          ago = "${diff.inDays}d ago";
        } else if (diff.inHours > 0) {
          ago = "${diff.inHours}h ago";
        } else {
          ago = "${diff.inMinutes}m ago";
        }
      } catch (_) {}
    }

    String genderRaw = (j["preferredTenant"] != null)
        ? (j["preferredTenant"] is Map
              ? (j["preferredTenant"]["gender"] ?? "Unisex").toString()
              : "Unisex")
        : (j["gender"] ?? "Unisex").toString();

    String genderLabel = genderRaw.toLowerCase() == "male"
        ? "Mens"
        : genderRaw.toLowerCase() == "female"
        ? "Womens"
        : "Unisex";

    return PGListingModel(
      id: j["id"] ?? 0,
      name: j["propertyName"] ?? "PG Accommodation",
      city: j["city"] ?? "",
      locality: j["locality"] ?? "",
      rent: (j["rent"] ?? 0).toDouble(),
      foodIncluded: j["foodIncluded"] ?? false,
      gender: genderLabel,
      images: extractPropertyImages(j["images"], _pgBaseUrl),
      sharingType: j["sharingType"]?["type"] ?? "Single",
      sharingOptions: options,
      amenities: amen,
      postedAgo: ago,
      isActive: j["isActive"] ?? true,
      views: j["views"] ?? (50 + (j["id"] ?? 0) * 13) % 500,
      contacted: j["contacted"] ?? (2 + (j["id"] ?? 0) * 3) % 40,
    );
  }
}

// -------------------------------------------------------------
//  SCREEN
// -------------------------------------------------------------
class PGListingScreen extends StatefulWidget {
  final String type;

  const PGListingScreen({super.key, required this.type});

  @override
  State<PGListingScreen> createState() => _PGListingScreenState();
}

class _PGListingScreenState extends State<PGListingScreen> {
  List<PGListingModel> _all = [];
  List<PGListingModel> _filtered = [];
  bool _loading = true;
  String? _error;

  String _sortBy = "default";
  bool _withFood = false;
  String _genderFilter = "all";
  RangeValues _budgetRange = const RangeValues(0, 50000);

  @override
  void initState() {
    super.initState();
    _fetchPGs();
  }

  Future<void> _fetchPGs() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse("$_pgBaseUrl/property/all"));
      if (!mounted) return;
      final decoded = jsonDecode(res.body);
      final List list = decoded is List ? decoded : decoded["data"] ?? [];
      final allPGs = list
          .where(
            (p) => (p["propertyType"] ?? "").toString().toLowerCase().contains(
              "pg",
            ),
          )
          .map((p) => PGListingModel.fromJson(p))
          .toList();
      if (!mounted) return;
      setState(() {
        _all = allPGs;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    List<PGListingModel> result = List.from(_all);
    if (widget.type == "Mens PG") {
      result = result.where((p) => p.gender.toLowerCase() == "mens").toList();
    } else if (widget.type == "Womens PG") {
      result = result.where((p) => p.gender.toLowerCase() == "womens").toList();
    }
    if (_withFood) result = result.where((p) => p.foodIncluded).toList();
    if (_genderFilter != "all") {
      result = result
          .where((p) => p.gender.toLowerCase() == _genderFilter.toLowerCase())
          .toList();
    }
    if (_sortBy == "low")
      result.sort((a, b) => a.rent.compareTo(b.rent));
    else if (_sortBy == "high")
      result.sort((a, b) => b.rent.compareTo(a.rent));
    setState(() => _filtered = result);
  }

  String _imgUrl(dynamic img) {
    if (img == null || img.toString().isEmpty) {
      return "https://via.placeholder.com/400x240?text=No+Image";
    }
    if (img.toString().startsWith("http")) return img.toString();
    return "$_pgBaseUrl/${img.toString()}";
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final k = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
      return "?${k}k";
    }
    return "?${v.toInt()}";
  }

  // -------------------------------------------------------------
  //  BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          _buildAppBar(),
          _buildFilterBar(),
          _buildResultCount(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1EB6A8)),
                  )
                : _error != null
                ? _errorView()
                : _filtered.isEmpty
                ? _emptyView()
                : RefreshIndicator(
                    color: const Color(0xFF1EB6A8),
                    onRefresh: _fetchPGs,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) =>
                          _PGListingCard(pg: _filtered[i], imgUrl: _imgUrl),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // -- APP BAR --------------------------------------------------
  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 4,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => showSearch(
                context: context,
                delegate: _PGSearchDelegate(_all, _imgUrl, _fmt),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Search PG in "${widget.type}"',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- FILTER BAR -----------------------------------------------
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              icon: Icons.sort,
              label: "Sort",
              active: _sortBy != "default",
              onTap: _openSortSheet,
            ),
            const SizedBox(width: 8),
            _filterChip(
              icon: Icons.tune,
              label: "Filters",
              active: false,
              onTap: _openFilterSheet,
            ),
            const SizedBox(width: 8),
            _filterChip(
              icon: Icons.restaurant,
              label: "With Food",
              active: _withFood,
              onTap: () {
                setState(() => _withFood = !_withFood);
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _filterChip(
              icon: Icons.people_outline,
              label: "Gender",
              active: _genderFilter != "all",
              onTap: _openGenderSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1EB6A8) : Colors.white,
          border: Border.all(
            color: active ? const Color(0xFF1EB6A8) : const Color(0xFFDDDDDD),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : Colors.black87),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : Colors.black87,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 13, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  // -- RESULT COUNT ---------------------------------------------
  Widget _buildResultCount() {
    return Container(
      color: const Color(0xFFF2F2F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            "${_filtered.length} total properties",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }

  // -- BOTTOM SHEETS ---------------------------------------------
  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sort By",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...[
              ("default", "Relevance"),
              ("low", "Price: Low to High"),
              ("high", "Price: High to Low"),
            ].map(
              (opt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Radio<String>(
                  value: opt.$1,
                  groupValue: _sortBy,
                  activeColor: const Color(0xFF1EB6A8),
                  onChanged: (v) {
                    setState(() => _sortBy = v!);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
                title: Text(opt.$2),
                onTap: () {
                  setState(() => _sortBy = opt.$1);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Filters",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _withFood = false;
                        _genderFilter = "all";
                        _sortBy = "default";
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Reset",
                      style: TextStyle(color: Color(0xFF1EB6A8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Budget Range",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              RangeSlider(
                values: _budgetRange,
                min: 0,
                max: 50000,
                divisions: 50,
                activeColor: const Color(0xFF1EB6A8),
                labels: RangeLabels(
                  "?${_budgetRange.start.toInt()}",
                  "?${_budgetRange.end.toInt()}",
                ),
                onChanged: (v) {
                  setLocal(() => _budgetRange = v);
                  setState(() => _budgetRange = v);
                  _applyFilters();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Food Included"),
                value: _withFood,
                activeColor: const Color(0xFF1EB6A8),
                onChanged: (v) {
                  setLocal(() => _withFood = v);
                  setState(() => _withFood = v);
                  _applyFilters();
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EB6A8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Apply Filters",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openGenderSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Gender",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...[
              ("all", "All"),
              ("mens", "Mens PG"),
              ("womens", "Womens PG"),
              ("unisex", "Unisex / Co-living"),
            ].map(
              (opt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Radio<String>(
                  value: opt.$1,
                  groupValue: _genderFilter,
                  activeColor: const Color(0xFF1EB6A8),
                  onChanged: (v) {
                    setState(() => _genderFilter = v!);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
                title: Text(opt.$2),
                onTap: () {
                  setState(() => _genderFilter = opt.$1);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.home_work_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text(
          "No PGs found",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          "Try adjusting your filters",
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _errorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          _error ?? "Something went wrong",
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _fetchPGs,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1EB6A8),
          ),
          child: const Text("Retry", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

// -------------------------------------------------------------
//  PG LISTING CARD � matches the screenshot exactly
// -------------------------------------------------------------
class _PGListingCard extends StatefulWidget {
  final PGListingModel pg;
  final String Function(dynamic) imgUrl;

  const _PGListingCard({required this.pg, required this.imgUrl});

  @override
  State<_PGListingCard> createState() => _PGListingCardState();
}

class _PGListingCardState extends State<_PGListingCard> {
  @override
  Widget build(BuildContext context) {
    final pg = widget.pg;
    final imageUrl = pg.images.isNotEmpty
        ? widget.imgUrl(pg.images.first)
        : "https://via.placeholder.com/400x220?text=No+Image";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- IMAGE -----------------------------------------
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                buildPropertyImage(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  baseUrl: _pgBaseUrl,
                  placeholder: () => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 40),
                    ),
                  ),
                ),
                // Active badge � top right
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: pg.isActive
                          ? const Color(0xFF2ECC71)
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pg.isActive ? "Active" : "Inactive",
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
          ),

          // -- DETAILS SECTION -------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row: name + price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        pg.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "? ${pg.rent.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}/month",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF888888),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${pg.locality}, ${pg.city}",
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Stats row: views + contacted
                Row(
                  children: [
                    _statChip(
                      icon: Icons.visibility_outlined,
                      label: "${pg.views} views",
                    ),
                    const SizedBox(width: 16),
                    _statChip(
                      icon: Icons.chat_bubble_outline,
                      label: "${pg.contacted} contacted",
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),

                // Action buttons row
                Row(
                  children: [
                    // Edit button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Color(0xFF555555),
                        ),
                        label: const Text(
                          "Edit",
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCCCCCC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Get Premium button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showPremiumDialog(context, pg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2340),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Get Premium",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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

  Widget _statChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF888888)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
      ],
    );
  }

  void _showPremiumDialog(BuildContext context, PGListingModel pg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF1A2340),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Upgrade to Premium",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              pg.name,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const _PremiumFeatureTile(
              icon: Icons.bolt,
              label: "Top placement in search results",
            ),
            const _PremiumFeatureTile(
              icon: Icons.verified,
              label: "Verified badge on your listing",
            ),
            const _PremiumFeatureTile(
              icon: Icons.bar_chart,
              label: "Advanced analytics & insights",
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2340),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Upgrade Now",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PremiumFeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PremiumFeatureTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1EB6A8), size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
//  SEARCH DELEGATE
// -------------------------------------------------------------
class _PGSearchDelegate extends SearchDelegate<String> {
  final List<PGListingModel> all;
  final String Function(dynamic) imgUrl;
  final String Function(double) fmtPrice;

  _PGSearchDelegate(this.all, this.imgUrl, this.fmtPrice);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  String get searchFieldLabel => "Search PG by locality or name...";

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ""),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ""),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final q = query.toLowerCase().trim();
    final results = q.isEmpty
        ? all
        : all
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.locality.toLowerCase().contains(q) ||
                    p.city.toLowerCase().contains(q),
              )
              .toList();

    if (results.isEmpty) {
      return const Center(child: Text("No results found"));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: results.length,
      itemBuilder: (_, i) => _PGListingCard(pg: results[i], imgUrl: imgUrl),
    );
  }
}
