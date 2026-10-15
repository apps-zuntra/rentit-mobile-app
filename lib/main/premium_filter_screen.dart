// premium_filter_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'filter_model.dart';

// -- Palette -------------------------------------------------------------------
const Color _kDark = Color(0xFF1A2B40);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kText = Color(0xFF111827);
const Color _kText2 = Color(0xFF4B5563);
const Color _kText3 = Color(0xFF9CA3AF);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kBg = Color(0xFFF5F6F8);

// -- Amenity data --------------------------------------------------------------
// UI label ? backend key mapping for pgAmenities:
//   'WiFi'          ? 'wifi'
//   'Lift'          ? 'lift'
//   'Mess'          ? 'mess'
//   'Laundry'       ? 'laundry'
//   'Common TV'     ? 'commonTV'
//   'Power Backup'  ? 'powerBackup'
//   'Refrigerator'  ? 'refrigerator'
//   'Room Cleaning' ? 'roomCleaning'
// Room-level amenities (checked via roomType[].amenities[]):
//   'AC', 'Cupboard', 'TV', 'Geyser', 'Attached Bathroom', 'Bedding'
const List<Map<String, String>> _kAmenities = [
  {'label': 'AC', 'backendKey': 'ac'},
  {'label': 'Cupboard', 'backendKey': 'cupboard'},
  {'label': 'TV', 'backendKey': 'tv'},
  {'label': 'WiFi', 'backendKey': 'wifi'},
  {'label': 'Geyser', 'backendKey': 'geyser'},
  {'label': 'Attached Bathroom', 'backendKey': 'attachedbathroom'},
  {'label': 'Bedding', 'backendKey': 'bedding'},
  {'label': 'Laundry', 'backendKey': 'laundry'},
  {'label': 'Room Cleaning', 'backendKey': 'roomCleaning'},
  {'label': 'Common TV', 'backendKey': 'commonTV'},
  {'label': 'Lift', 'backendKey': 'lift'},
  {'label': 'Power Backup', 'backendKey': 'powerBackup'},
  {'label': 'Refrigerator', 'backendKey': 'refrigerator'},
  {'label': 'Mess', 'backendKey': 'mess'},
];

// -- Restriction data ----------------------------------------------------------
// UI label ? backend key mapping for houseRules object:
//   'No Smoking'          ? 'smoking'
//   'No Alcohol'          ? 'drinking'
//   'No Loud Music'       ? 'loudMusic'
//   'No Non-Veg'          ? 'nonVeg'
//   'No Girls/Boys Entry' ? 'girlsEntry'
const List<Map<String, String>> _kRestrictions = [
  {'label': 'No Smoking', 'backendKey': 'smoking'},
  {'label': 'No Alcohol', 'backendKey': 'drinking'},
  {'label': 'No Loud Music', 'backendKey': 'loudMusic'},
  {'label': 'No Non-Veg', 'backendKey': 'nonVeg'},
  {'label': 'No Girls/Boys Entry', 'backendKey': 'girlsEntry'},
];

// -- Nearby data ---------------------------------------------------------------
const List<String> _kNearby = [
  'Bus stop',
  'Metro',
  'School',
  'Hospital',
  'Mall',
  'Restaurant',
];

// -- Google Places config ------------------------------------------------------
const String _kGoogleApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";

const Map<String, Map<String, double>> _kCityCentres = {
  'Chennai': {'lat': 13.0827, 'lng': 80.2707},
};

// -- Models --------------------------------------------------------------------
class _Prediction {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _Prediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory _Prediction.fromJson(Map<String, dynamic> j) {
    final sf = j['structured_formatting'] as Map? ?? {};
    return _Prediction(
      placeId: j['place_id']?.toString() ?? '',
      mainText:
          sf['main_text']?.toString() ?? j['description']?.toString() ?? '',
      secondaryText: sf['secondary_text']?.toString() ?? '',
    );
  }
}

// ------------------------------------------------------------------------------
class PremiumFilterScreen extends StatefulWidget {
  final PgFilterModel initial;
  final List<dynamic> allProperties;
  final void Function(PgFilterModel) onApply;

  const PremiumFilterScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<PremiumFilterScreen> createState() => _PremiumFilterScreenState();
}

class _PremiumFilterScreenState extends State<PremiumFilterScreen> {
  // -- State ------------------------------------------------------------------
  late PgFilterModel _f;
  bool _searchAlongMetro = false;

  // Locality / city search
  String _city = 'Chennai';
  final TextEditingController _localityCtrl = TextEditingController();
  final FocusNode _localityFocus = FocusNode();
  List<_Prediction> _suggestions = [];
  Timer? _debounce;

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    _f = widget.initial.copyWith();
    _localityCtrl.text = _f.locality;

    // ? Default Chennai
    _city = 'Chennai';
    _f = _f.copyWith(city: 'Chennai');

    // Existing value irundha adha use pannu
    if (_f.city.isNotEmpty) {
      _city = _f.city;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _localityCtrl.dispose();
    _localityFocus.dispose();
    super.dispose();
  }

  // -- Live count -------------------------------------------------------------
  int get _liveCount {
    var list = List<dynamic>.from(widget.allProperties);
    list = _applyStandardFilters(list, _f);

    // Amenities filter � uses backendKey stored in _f.amenities
    if (_f.amenities.isNotEmpty) {
      list = list.where((p) {
        return _f.amenities.every((key) => _hasAmenityByKey(p as Map, key));
      }).toList();
    }

    // Restrictions filter � uses backendKey stored in _f.restrictions
    if (_f.restrictions.isNotEmpty) {
      list = list.where((p) {
        final pgRestrictions = _parseList(
          (p as Map)['restrictions'],
        ).map((e) => e.toString().toLowerCase()).toList();
        if (pgRestrictions.isEmpty) return false;
        return _f.restrictions.every(
          (key) => pgRestrictions.contains(key.toLowerCase()),
        );
      }).toList();
    }

    return list.length;
  }

  // -- Google Places autocomplete ---------------------------------------------
  void _onLocalityChanged(String value) {
    // Update filter locality immediately for text search
    setState(() => _f = _f.copyWith(locality: value));

    if (value.length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _fetchSuggestions(value),
    );
  }

  Future<void> _fetchSuggestions(String input) async {
    if (_city.isEmpty) return;

    final centre = _kCityCentres[_city];
    String locationBias = '';
    if (centre != null) {
      locationBias =
          '&location=${centre['lat']},${centre['lng']}&radius=30000&strictbounds=true';
    }

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:in'
        '$locationBias'
        '&key=$_kGoogleApiKey',
      );

      final res = await http.get(uri);
      if (!mounted) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final predictions = body['predictions'] as List? ?? [];

      setState(() {
        _suggestions = predictions
            .map((e) => _Prediction.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('? Places autocomplete error: $e');
    }
  }

  void _selectSuggestion(_Prediction p) {
    setState(() {
      _localityCtrl.text = p.mainText;
      _f = _f.copyWith(locality: p.mainText);
      _suggestions = [];
      _localityFocus.unfocus();
    });
  }

  void _clearLocality() {
    setState(() {
      _localityCtrl.clear();
      _f = _f.copyWith(locality: '');
      _suggestions = [];
    });
  }

  // -- Apply ------------------------------------------------------------------
  Future<void> _apply() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId != null) {
        await http.post(
          Uri.parse('https://rentit-backend-yti9.onrender.com/preferences'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,

            // ? ADD THIS
            'city': _f.city.isNotEmpty ? _f.city : null,
            'locality': _f.locality.isNotEmpty ? _f.locality : null,
            'search': _f.locality.isNotEmpty ? _f.locality : null,

            // existing
            'amenities': _f.amenities,
            'nearby': _f.nearby,
            'restrictions': _f.restrictions,
            'premiumSort': _f.premiumSort,
          }),
        );
      }
    } catch (e) {
      debugPrint('? Preferences save error: $e');
    }

    widget.onApply(_f);
    if (mounted) Navigator.pop(context);
  }

  // -- Reset ------------------------------------------------------------------
  void _reset() => setState(() {
    _f = _f.copyWith(
      amenities: [],
      nearby: [],
      restrictions: [],
      premiumSort: '',
      locality: '',
    );
    _localityCtrl.clear();
    _suggestions = [];
    _searchAlongMetro = false;
    _city = '';
  });

  // -- Toggle helpers ---------------------------------------------------------
  void _toggleAmenity(String backendKey) {
    final copy = List<String>.from(_f.amenities);
    copy.contains(backendKey) ? copy.remove(backendKey) : copy.add(backendKey);
    setState(() => _f = _f.copyWith(amenities: copy));
  }

  void _toggleRestriction(String backendKey) {
    final copy = List<String>.from(_f.restrictions);
    copy.contains(backendKey) ? copy.remove(backendKey) : copy.add(backendKey);
    setState(() => _f = _f.copyWith(restrictions: copy));
  }

  void _toggleNearby(String val) {
    final copy = List<String>.from(_f.nearby);
    copy.contains(val) ? copy.remove(val) : copy.add(val);
    setState(() => _f = _f.copyWith(nearby: copy));
  }

  // ------------------------------- BUILD ------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Location Section -------------------------------------------
            _buildLocationSection(),
            const SizedBox(height: 24),

            // -- Search Type ------------------------------------------------
            // _buildSearchTypeSection(),

            // -- Amenities --------------------------------------------------
            _sectionTitle('Amenities'),
            const SizedBox(height: 12),
            _buildAmenityChips(),
            const SizedBox(height: 28),

            // -- Nearby Facilities ------------------------------------------
            _sectionTitle('Nearby Facilities'),
            const SizedBox(height: 12),
            _buildNearbyChips(),
            const SizedBox(height: 28),

            // -- House Rules / Restrictions ---------------------------------
            _sectionTitle('House Rules / Restrictions'),
            const SizedBox(height: 4),
            const Text(
              'Show PGs that enforce these rules',
              style: TextStyle(fontSize: 11, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildRestrictionChips(),
            const SizedBox(height: 28),

            // -- Advanced Listing -------------------------------------------
            _sectionTitle('Advanced Listing'),
            const SizedBox(height: 12),
            _buildSortButtons(),
          ],
        ),
      ),
      bottomSheet: _buildApplyBar(),
    );
  }

  // -- App bar ----------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: _kText, size: 24),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Container(
        //   padding: const EdgeInsets.all(6),
        //   decoration: BoxDecoration(
        //     color: _kOrange.withOpacity(0.15),
        //     shape: BoxShape.circle,
        //   ),
        //   child: const Icon(
        //     Icons.workspace_premium_rounded,
        //     color: _kOrange,
        //     size: 18,
        //   ),
        // ),
        // const SizedBox(width: 8),
        const Text(
          'Premium Filters',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xff2f3542),
          ),
        ),
      ],
    ),
    centerTitle: true,
    actions: [
      IconButton(
        onPressed: _reset,
        icon: const Icon(Icons.refresh_rounded, color: _kText2, size: 22),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _kBorder),
    ),
  );

  // -- Location section -------------------------------------------------------
  Widget _buildLocationSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Location'),
      const SizedBox(height: 12),

      // City dropdown
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(12), // smoother
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _city.isEmpty ? null : _city,
            isExpanded: true,

            hint: const Text(
              'Select City',
              style: TextStyle(color: _kText3, fontSize: 13),
            ),

            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kText3,
              size: 20,
            ),

            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14), // popup style

            style: const TextStyle(fontSize: 14, color: _kText),

            onChanged: (v) {
              if (v == null) return;

              setState(() {
                _city = v;

                // update filter
                _f = _f.copyWith(city: _city);

                // clear locality
                _localityCtrl.clear();
                _f = _f.copyWith(locality: '');

                _suggestions = [];
              });
            },

            // ?? PREMIUM ITEM UI (MAIN FIX)
            items: _kCityCentres.keys.map((city) {
              final isSelected = city == _city;

              return DropdownMenuItem<String>(
                value: city,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected
                        ? const Color(0xFFEEF2FF) // ?? highlight
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isSelected ? const Color(0xFF6366F1) : _kText3,
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          city,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? _kText
                                : const Color(0xFF374151),
                          ),
                        ),
                      ),

                      // ? check icon
                      if (isSelected)
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),

      const SizedBox(height: 12),
      _sectionTitle('Search Type'),
      const SizedBox(height: 12),
      // Locality / landmark search field
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // Search input row
            Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: _kText3, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _localityCtrl,
                    focusNode: _localityFocus,
                    onChanged: _onLocalityChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search locality or landmark',
                      hintStyle: TextStyle(
                        color: _kText3,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: const TextStyle(fontSize: 13, color: _kText),
                  ),
                ),
                if (_localityCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: _clearLocality,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.close_rounded,
                        color: _kText3,
                        size: 18,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),

            // Suggestions list
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) {
                    final p = _suggestions[i];
                    return InkWell(
                      onTap: () => _selectSuggestion(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: _kText3,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.mainText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kText,
                                    ),
                                  ),
                                  if (p.secondaryText.isNotEmpty)
                                    Text(
                                      p.secondaryText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _kText3,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ],
  );

  // -- Search type section ----------------------------------------------------
  Widget _buildSearchTypeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Search Type'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            _searchTypeBtn(
              label: 'Locality Search',
              icon: Icons.location_on_outlined,
              selected: !_searchAlongMetro,
              onTap: () => setState(() => _searchAlongMetro = false),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _searchTypeBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? _kText : _kText3),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? _kText : _kText3,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // -- Amenity chips � stores backendKey in _f.amenities ---------------------
  Widget _buildAmenityChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kAmenities.map((item) {
      final key = item['backendKey']!;
      final label = item['label']!;
      final isSel = _f.amenities.contains(key);
      return _chip(
        label: label,
        selected: isSel,
        onTap: () => _toggleAmenity(key),
      );
    }).toList(),
  );

  // -- Nearby chips � stores label string in _f.nearby -----------------------
  Widget _buildNearbyChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kNearby.map((item) {
      final isSel = _f.nearby.contains(item);
      return _chip(
        label: item,
        selected: isSel,
        onTap: () => _toggleNearby(item),
      );
    }).toList(),
  );

  // -- Restriction chips � stores backendKey in _f.restrictions --------------
  Widget _buildRestrictionChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kRestrictions.map((item) {
      final key = item['backendKey']!;
      final label = item['label']!;
      final isSel = _f.restrictions.contains(key);
      return _chip(
        label: label,
        selected: isSel,
        onTap: () => _toggleRestriction(key),
      );
    }).toList(),
  );

  // -- Generic chip -----------------------------------------------------------
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _kDark : Colors.white,
        border: Border.all(color: selected ? _kDark : _kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _kText2,
        ),
      ),
    ),
  );

  // -- Section title ----------------------------------------------------------
  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: _kText,
    ),
  );

  // -- Sort buttons -----------------------------------------------------------
  Widget _buildSortButtons() => Row(
    children: [
      _sortBtn(label: 'Newly Added', value: 'new'),
      const SizedBox(width: 10),
      _sortBtn(label: 'Recently Posted', value: 'recent'),
    ],
  );

  Widget _sortBtn({required String label, required String value}) {
    final sel = _f.premiumSort == value;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            setState(() => _f = _f.copyWith(premiumSort: sel ? '' : value)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          decoration: BoxDecoration(
            color: sel ? _kDark : Colors.white,
            border: Border.all(color: sel ? _kDark : _kBorder, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : _kText2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Apply bar --------------------------------------------------------------
  Widget _buildApplyBar() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: const Border(top: BorderSide(color: _kBorder)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      MediaQuery.of(context).padding.bottom + 12,
    ),
    child: SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _apply,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          'APPLY FILTERS ($_liveCount RESULTS)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Standalone helpers (used by liveCount and ViewAllProperties.dart)
// -----------------------------------------------------------------------------

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

/// Check a property for a given amenity using the backend key.
///
/// Backend structure:
///   pgAmenities: { wifi, lift, mess, laundry, commonTV, powerBackup,
///                  refrigerator, roomCleaning }  ? exact keys
///   roomType[].amenities: ["AC", "Cupboard", "Geyser", ...]
///   societyAmenities / amenities: []
bool _hasAmenityByKey(Map p, String backendKey) {
  // UI key ? Database value mapping
  const Map<String, List<String>> amenityAliases = {
    'ac': ['ac'],
    'cupboard': ['cupboard'],
    'tv': ['tv'],
    'wifi': ['wifi'],
    'geyser': ['geyser'],
    'attachedbathroom': [
      'attached bathroom',
      'attachedbathroom',
      'attached_bathroom',
    ],
    'bedding': ['bedding'],
    'laundry': ['laundry'],
    'roomCleaning': ['room cleaning', 'roomcleaning'],
    'commonTV': ['common tv', 'commontv'],
    'lift': ['lift'],
    'powerBackup': ['power backup', 'powerbackup'],
    'refrigerator': ['refrigerator', 'fridge'],
    'mess': ['mess'],
  };

  // Normalize helper
  String normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  }

  final aliases = amenityAliases[backendKey] ?? [backendKey];

  final normalizedTargets = aliases.map((e) => normalize(e)).toList();

  // 1?? Check pgAmenities object
  final pgAm = p['pgAmenities'];
  if (pgAm is Map) {
    for (final alias in aliases) {
      if (pgAm[alias] == true) return true;
      if (pgAm[backendKey] == true) return true;
    }
  }

  // 2?? Check roomType[].amenities[]
  final rooms = _parseList(p['roomType']);

  for (final room in rooms) {
    if (room is! Map) continue;

    final roomAmenities = _parseList(room['amenities']);

    for (final item in roomAmenities) {
      final normalizedItem = normalize(item.toString());

      for (final target in normalizedTargets) {
        if (normalizedItem == target ||
            normalizedItem.contains(target) ||
            target.contains(normalizedItem)) {
          return true;
        }
      }
    }
  }

  // 3?? Check societyAmenities + amenities arrays
  final otherAmenities = [
    ..._parseList(p['societyAmenities']),
    ..._parseList(p['amenities']),
  ];

  for (final item in otherAmenities) {
    final normalizedItem = normalize(item.toString());

    for (final target in normalizedTargets) {
      if (normalizedItem == target ||
          normalizedItem.contains(target) ||
          target.contains(normalizedItem)) {
        return true;
      }
    }
  }

  return false;
}

/// Apply all standard (non-premium) filter fields.
List<dynamic> _applyStandardFilters(List<dynamic> raw, PgFilterModel f) {
  List<dynamic> list = List.from(raw);

  // City
  if (f.city.isNotEmpty) {
    list = list.where((p) {
      final c = (p as Map)['city']?.toString().toLowerCase().trim() ?? '';
      return c == f.city.toLowerCase().trim();
    }).toList();
  }

  // Locality / free-text search
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
      return (m['city']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['landmark']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['propertyName']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['street']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // PG For ? preferredTenant
  if (f.pgFor.isNotEmpty && f.pgFor != 'Anyone') {
    final want = f.pgFor.toLowerCase();
    list = list.where((p) {
      final tenants = _parseList(
        (p as Map)['preferredTenant'],
      ).map((e) => e.toString().toLowerCase()).toList();
      if (tenants.isEmpty) return true;
      return tenants.contains(want) ||
          tenants.contains('anyone') ||
          tenants.contains('any');
    }).toList();
  }

  // Room type ? roomType[].sharing
  if (f.sharingTypes.isNotEmpty) {
    list = list.where((p) {
      final rooms = _parseList((p as Map)['roomType']);
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

  // Preferred tenant ? preferredGuests
  if (f.preferredTenant.isNotEmpty && f.preferredTenant != 'Anyone') {
    final want = f.preferredTenant.toLowerCase();
    list = list.where((p) {
      final guests = _parseList(
        (p as Map)['preferredGuests'],
      ).map((e) => e.toString().toLowerCase()).toList();
      if (guests.isEmpty) return true;
      return guests.any(
            (g) => g == want || g.contains(want) || want.contains(g),
          ) ||
          guests.contains('anyone') ||
          guests.contains('any');
    }).toList();
  }

  // Availability ? availableFrom
  if (f.availability.isNotEmpty) {
    final now = DateTime.now();
    list = list.where((p) {
      final avFrom = (p as Map)['availableFrom']?.toString();
      if (avFrom == null || avFrom.isEmpty) return true;
      final dt = DateTime.tryParse(avFrom);
      if (dt == null) return true;
      if (f.availability == 'Immediately') return !dt.isAfter(now);
      if (f.availability == 'Within 15 days') {
        return !dt.isAfter(now.add(const Duration(days: 15)));
      }
      if (f.availability == 'Within 30 days') {
        return !dt.isAfter(now.add(const Duration(days: 30)));
      }
      return true;
    }).toList();
  }

  // Parking ? parking field
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

  // Food included ? foodIncluded (bool)
  if (f.foodIncluded != null) {
    list = list.where((p) {
      final fi = (p as Map)['foodIncluded'];
      final included = fi == true || fi?.toString() == 'true';
      return f.foodIncluded! ? included : !included;
    }).toList();
  }

  // Rent range ? roomType[].rent
  if (f.rentMin > 0 || (f.rentMax > 0 && f.rentMax < 1000000)) {
    list = list.where((p) {
      final rooms = _parseList((p as Map)['roomType']);
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

  return list;
}
