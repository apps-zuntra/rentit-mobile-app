// -----------------------------------------------------------------------------
// Apartment_premium_filter_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/Apartment_filter_model.dart';

// -----------------------------------------------------------------------------
//  PALETTE
// -----------------------------------------------------------------------------
const Color _kDark = Color(0xFF1A2B40);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kText = Color(0xFF111827);
const Color _kText2 = Color(0xFF4B5563);
const Color _kText3 = Color(0xFF9CA3AF);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kBg = Color(0xFFF5F6F8);
const Color _kIndigo = Color(0xFF6366F1);
const Color _kIndigoBg = Color(0xFFEEF2FF);
const Color _kRed = Color(0xFFFF3B30);

// -----------------------------------------------------------------------------
//  STATIC OPTION DATA
// -----------------------------------------------------------------------------
const List<Map<String, String>> _kAmenities = [
  {'label': 'Lift', 'key': 'Lift'},
  {'label': 'Internet Services', 'key': 'Internet Services'},
  {'label': 'Air Conditioner', 'key': 'Air Conditioner'},
  {'label': 'Club House', 'key': 'Club House'},
  {'label': 'Intercom', 'key': 'Intercom'},
  {'label': 'Swimming Pool', 'key': 'Swimming Pool'},
  {'label': 'Children Play Area', 'key': 'Children Play Area'},
  {'label': 'Fire Safety', 'key': 'Fire Safety'},
  {'label': 'Servant Room', 'key': 'Servant Room'},
  {'label': 'Shopping Center', 'key': 'Shopping Center'},
  {'label': 'Gas Pipeline', 'key': 'Gas Pipeline'},
  {'label': 'Park', 'key': 'Park'},
  {'label': 'Rain Water Harvesting', 'key': 'Rain Water Harvesting'},
  {'label': 'Sewage Treatment Plant', 'key': 'Sewage Treatment Plant'},
  {'label': 'House Keeping', 'key': 'House Keeping'},
  {'label': 'Power Backup', 'key': 'Power Backup'},
  {'label': 'Visitor Parking', 'key': 'Visitor Parking'},
];

const List<Map<String, String>> _kRestrictions = [
  {'label': 'No Non-Veg', 'key': 'nonVegAllowed'},
  {'label': 'No Pets', 'key': 'petAllowed'},
];

const List<String> _kNearby = [
  'Bus Stop',
  'Metro',
  'School',
  'Hospital',
  'Mall',
  'Restaurant',
  'Park',
  'ATM',
];

const Map<String, Map<String, double>> _kCityCentres = {
  'Chennai': {'lat': 13.0827, 'lng': 80.2707},
};

const List<String> _kPropertyAges = [
  'Less than a year',
  '1 to 3 year',
  '3 to 5 year',
  '5 to 10 year',
  'more than 10 year',
];

const List<String> _kBathrooms = ['1 or more', '2 or more', '3 or more'];

const List<String> _kFloors = [
  'Ground',
  '1 to 3',
  '4 to 6',
  '7 to 9',
  '10 & above',
];

const List<String> _kShowOnly = [
  'Non Veg Allowed',
  'With Photos',
  'Gym',
  'Pet Friendly',
];

const String _kGoogleApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";
const String _kBaseUrl = "https://rentit-backend-omega.vercel.app";

// -----------------------------------------------------------------------------
//  AUTOCOMPLETE MODEL
// -----------------------------------------------------------------------------
class _PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  const _PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory _PlacePrediction.fromJson(Map<String, dynamic> j) {
    final sf = j['structured_formatting'] as Map? ?? {};
    return _PlacePrediction(
      placeId: j['place_id']?.toString() ?? '',
      mainText:
          sf['main_text']?.toString() ?? j['description']?.toString() ?? '',
      secondaryText: sf['secondary_text']?.toString() ?? '',
    );
  }
}

// -----------------------------------------------------------------------------
//  WIDGET
// -----------------------------------------------------------------------------
class ApartmentPremiumFilterScreen extends StatefulWidget {
  final ApartmentFilterModel initial;
  final List<dynamic> allProperties;
  final void Function(ApartmentFilterModel) onApply;

  const ApartmentPremiumFilterScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<ApartmentPremiumFilterScreen> createState() =>
      _ApartmentPremiumFilterScreenState();
}

class _ApartmentPremiumFilterScreenState
    extends State<ApartmentPremiumFilterScreen> {
  // -- State ------------------------------------------------------------------
  late ApartmentFilterModel _f;
  RangeValues _areaRange = const RangeValues(0, 10000);

  // -- Location search --------------------------------------------------------
  final TextEditingController _localityCtrl = TextEditingController();
  final FocusNode _localityFocus = FocusNode();
  List<_PlacePrediction> _suggestions = [];
  Timer? _debounce;

  // -- Loading ----------------------------------------------------------------
  bool _saving = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    _f = widget.initial.copyWith();

    // ? Default Chennai
    if (_f.city.isEmpty) {
      _f = _f.copyWith(city: 'Chennai');
    }

    _localityCtrl.text = _f.locality;
    _areaRange = RangeValues(_f.areaMin, _f.areaMax);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _localityCtrl.dispose();
    _localityFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Computed
  // -------------------------------------------------------------------------
  int get _liveCount {
    var list = List<dynamic>.from(widget.allProperties);
    list = _applyAllPremiumFilters(list, _f);
    return list.length;
  }

  // -------------------------------------------------------------------------
  // Google Places autocomplete
  // -------------------------------------------------------------------------
  void _onLocalityChanged(String value) {
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
    final city = _f.city;
    final centre = _kCityCentres[city];
    final bias = centre != null
        ? '&location=${centre['lat']},${centre['lng']}&radius=30000&strictbounds=true'
        : '';
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:in$bias&key=$_kGoogleApiKey',
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _suggestions = (body['predictions'] as List? ?? [])
            .map((e) => _PlacePrediction.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
    }
  }

  void _selectSuggestion(_PlacePrediction p) {
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

  // -------------------------------------------------------------------------
  // Toggle helpers
  // -------------------------------------------------------------------------
  void _toggle(
    List<String> current,
    String val,
    void Function(List<String>) update,
  ) {
    final copy = List<String>.from(current);
    copy.contains(val) ? copy.remove(val) : copy.add(val);
    setState(() => update(copy));
  }

  void _toggleAmenity(String k) =>
      _toggle(_f.amenities, k, (v) => _f = _f.copyWith(amenities: v));
  void _toggleRestriction(String k) =>
      _toggle(_f.restrictions, k, (v) => _f = _f.copyWith(restrictions: v));
  void _toggleNearby(String k) =>
      _toggle(_f.nearby, k, (v) => _f = _f.copyWith(nearby: v));
  void _togglePropertyAge(String k) =>
      _toggle(_f.propertyAges, k, (v) => _f = _f.copyWith(propertyAges: v));
  void _toggleShowOnly(String k) =>
      _toggle(_f.showOnly, k, (v) => _f = _f.copyWith(showOnly: v));
  void _toggleFloor(String k) =>
      _toggle(_f.floors, k, (v) => _f = _f.copyWith(floors: v));

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------
  void _reset() => setState(() {
    _f = ApartmentFilterModel().copyWith(
      city: 'Chennai',
      amenities: [],
      nearby: [],
      restrictions: [],
      premiumSort: '',
      locality: '',
      areaMin: 0,
      areaMax: 10000,
      propertyAges: [],
      showOnly: [],
      removeSeen: false,
      bathroom: '',
      floors: [],
    );

    _areaRange = const RangeValues(0, 10000);
    _localityCtrl.clear();
    _suggestions = [];
  });
  // -------------------------------------------------------------------------
  // Apply (save preferences + callback)
  // -------------------------------------------------------------------------
  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId != null) {
        await http
            .post(
              Uri.parse('$_kBaseUrl/preferences'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'userId': userId,
                'city': _f.city.isNotEmpty ? _f.city : null,
                'locality': _f.locality.isNotEmpty ? _f.locality : null,
                'amenities': _f.amenities,
                'nearby': _f.nearby,
                'restrictions': _f.restrictions,
                'premiumSort': _f.premiumSort,
                'areaMin': _f.areaMin,
                'areaMax': _f.areaMax,
                'propertyAges': _f.propertyAges,
                'showOnly': _f.showOnly,
                'removeSeen': _f.removeSeen,
                'bathroom': _f.bathroom,
                'floors': _f.floors,
              }),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Preferences save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    widget.onApply(_f);
    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  //  BUILD
  // ---------------------------------------------------------------------------
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
            // -- Location ----------------------------------------------------
            _buildLocationSection(),
            const SizedBox(height: 28),
            _divider,

            // -- Built-Up Area -----------------------------------------------
            _sectionLabel('Built-Up Area (sq. ft.)'),
            const SizedBox(height: 4),
            Text(
              '${_areaRange.start.toInt()} � ${_areaRange.end >= 10000 ? '10,000+' : _areaRange.end.toInt()} sq.ft',
              style: const TextStyle(fontSize: 13, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildAreaSlider(),
            const SizedBox(height: 28),

            // -- Property Age ------------------------------------------------
            _sectionLabel('Property Age'),
            const SizedBox(height: 12),
            _buildPropertyAgeGrid(),
            const SizedBox(height: 28),

            // -- Show Only ---------------------------------------------------
            _sectionLabel('Show Only'),
            const SizedBox(height: 12),
            _buildShowOnlyRow(),
            const SizedBox(height: 20),

            // -- Remove Seen -------------------------------------------------
            _buildRemoveSeenTile(),
            const SizedBox(height: 28),
            _divider,

            // -- Bathroom ----------------------------------------------------
            _sectionLabel('Bathrooms'),
            const SizedBox(height: 12),
            _buildBathroomRow(),
            const SizedBox(height: 28),

            // -- Floors ------------------------------------------------------
            _sectionLabel('Floor Preference'),
            const SizedBox(height: 12),
            _buildFloorGrid(),
            const SizedBox(height: 28),
            _divider,

            // -- Amenities ---------------------------------------------------
            _sectionLabel('Amenities'),
            const SizedBox(height: 12),
            _buildChips(
              items: _kAmenities.map((e) => e['label']!).toList(),
              selected: _f.amenities.map((k) {
                final m = _kAmenities.firstWhere(
                  (e) => e['key'] == k,
                  orElse: () => {'label': k},
                );
                return m['label']!;
              }).toList(),
              onTap: (label) {
                final m = _kAmenities.firstWhere(
                  (e) => e['label'] == label,
                  orElse: () => {'key': label},
                );
                _toggleAmenity(m['key']!);
              },
            ),
            const SizedBox(height: 28),

            // -- Nearby ------------------------------------------------------
            _sectionLabel('Nearby Facilities'),
            const SizedBox(height: 12),
            _buildChips(
              items: _kNearby,
              selected: _f.nearby,
              onTap: _toggleNearby,
            ),
            const SizedBox(height: 28),

            // -- House Rules -------------------------------------------------
            _sectionLabel('House Rules / Restrictions'),
            const SizedBox(height: 4),
            const Text(
              'Show only apartments that enforce these rules',
              style: TextStyle(fontSize: 12, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildChips(
              items: _kRestrictions.map((e) => e['label']!).toList(),
              selected: _f.restrictions.map((k) {
                final m = _kRestrictions.firstWhere(
                  (e) => e['key'] == k,
                  orElse: () => {'label': k},
                );
                return m['label']!;
              }).toList(),
              onTap: (label) {
                final m = _kRestrictions.firstWhere(
                  (e) => e['label'] == label,
                  orElse: () => {'key': label},
                );
                _toggleRestriction(m['key']!);
              },
            ),
            const SizedBox(height: 28),
            _divider,

            // -- Advanced Listing Sort ---------------------------------------
            _sectionLabel('Advanced Listing'),
            const SizedBox(height: 4),
            const Text(
              'Control how matching properties are ordered',
              style: TextStyle(fontSize: 12, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildSortButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomSheet: _buildApplyBar(),
    );
  }

  // -------------------------------------------------------------------------
  //  APP BAR
  // -------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.close, color: _kText, size: 22),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Premium Filters',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kText,
          ),
        ),
      ],
    ),
    centerTitle: true,
    actions: [
      TextButton(
        onPressed: _reset,
        child: const Text(
          'Reset',
          style: TextStyle(
            color: _kText2,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: _kBorder),
    ),
  );

  // -------------------------------------------------------------------------
  //  LOCATION SECTION
  // -------------------------------------------------------------------------
  Widget _buildLocationSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('Location'),
      const SizedBox(height: 12),

      // City dropdown
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _f.city.isEmpty ? null : _f.city,
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
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(fontSize: 14, color: _kText),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _f = _f.copyWith(city: v, locality: '');
                _localityCtrl.clear();
                _suggestions = [];
              });
            },
            items: _kCityCentres.keys.map((city) {
              final sel = city == _f.city;
              return DropdownMenuItem<String>(
                value: city,
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: sel ? _kIndigo : _kText3,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        city,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? _kText : const Color(0xFF374151),
                        ),
                      ),
                    ),
                    if (sel)
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: _kIndigo,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Locality autocomplete
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
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
                    style: const TextStyle(fontSize: 13, color: _kText),
                    decoration: const InputDecoration(
                      hintText: 'Search locality or landmark�',
                      hintStyle: TextStyle(
                        color: _kText3,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
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
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
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

  // -------------------------------------------------------------------------
  //  AREA SLIDER
  // -------------------------------------------------------------------------
  Widget _buildAreaSlider() => Column(
    children: [
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: _kDark,
          inactiveTrackColor: _kBorder,
          thumbColor: _kDark,
          overlayColor: _kDark.withOpacity(0.12),
          rangeThumbShape: const RoundRangeSliderThumbShape(
            enabledThumbRadius: 10,
          ),
          trackHeight: 4,
        ),
        child: RangeSlider(
          values: _areaRange,
          min: 0,
          max: 10000,
          divisions: 200,
          onChanged: (v) => setState(() {
            _areaRange = v;
            _f = _f.copyWith(areaMin: v.start, areaMax: v.end);
          }),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _areaBox(_areaRange.start.toInt().toString())),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '�',
              style: TextStyle(color: _kText3, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: _areaBox(
              _areaRange.end >= 10000
                  ? '10,000+'
                  : _areaRange.end.toInt().toString(),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _areaBox(String val) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: _kBorder, width: 1.5),
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
    ),
    child: Text(
      val,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        color: _kText,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // -------------------------------------------------------------------------
  //  PROPERTY AGE  � 2-col checkbox grid
  // -------------------------------------------------------------------------
  Widget _buildPropertyAgeGrid() {
    final w = (MediaQuery.of(context).size.width - 32 - 16) / 2;
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: _kPropertyAges.map((age) {
        final sel = _f.propertyAges.contains(age);
        return GestureDetector(
          onTap: () => _togglePropertyAge(age),
          child: SizedBox(
            width: w,
            child: Row(
              children: [
                _checkbox(sel),
                const SizedBox(width: 8),
                Text(age, style: const TextStyle(fontSize: 13, color: _kText2)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------------------
  //  SHOW ONLY BUTTONS
  // -------------------------------------------------------------------------
  Widget _buildShowOnlyRow() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kShowOnly.map((item) {
      final sel = _f.showOnly.contains(item);
      return _selectionChip(
        label: item,
        selected: sel,
        onTap: () => _toggleShowOnly(item),
      );
    }).toList(),
  );

  // -----------------------------------------------------------------------------
  // REMOVE SEEN TILE
  // -----------------------------------------------------------------------------
  Widget _buildRemoveSeenTile() => GestureDetector(
    onTap: () {
      setState(() {
        _f = _f.copyWith(removeSeen: !_f.removeSeen);
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _f.removeSeen ? _kIndigoBg : _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _f.removeSeen ? _kIndigo : _kBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          _checkbox(_f.removeSeen),
          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remove Seen Properties',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hide apartments you\'ve already viewed',
                  style: TextStyle(fontSize: 11, color: _kText3),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'New',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  // -------------------------------------------------------------------------
  //  BATHROOM ROW
  // -------------------------------------------------------------------------
  Widget _buildBathroomRow() => Row(
    children: _kBathrooms.map((b) {
      final sel = _f.bathroom == b;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _f = _f.copyWith(bathroom: sel ? '' : b)),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              decoration: BoxDecoration(
                color: sel ? _kDark : Colors.white,
                border: Border.all(color: sel ? _kDark : _kBorder, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  b,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _kText2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );

  // -------------------------------------------------------------------------
  //  FLOOR GRID  � 3-col
  // -------------------------------------------------------------------------
  Widget _buildFloorGrid() {
    const cols = 3;
    final spacing = 8.0;
    final w =
        (MediaQuery.of(context).size.width - 32 - spacing * (cols - 1)) / cols;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: _kFloors.map((floor) {
        final sel = _f.floors.contains(floor);
        return GestureDetector(
          onTap: () => _toggleFloor(floor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: w,
            height: 42,
            decoration: BoxDecoration(
              color: sel ? _kDark : Colors.white,
              border: Border.all(color: sel ? _kDark : _kBorder, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                floor,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : _kText2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------------------
  //  CHIPS  (amenities / nearby / restrictions)
  // -------------------------------------------------------------------------
  Widget _buildChips({
    required List<String> items,
    required List<String> selected,
    required void Function(String) onTap,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: items
        .map(
          (label) => _selectionChip(
            label: label,
            selected: selected.contains(label),
            onTap: () => onTap(label),
            rounded: true,
          ),
        )
        .toList(),
  );

  // -------------------------------------------------------------------------
  //  SORT BUTTONS
  // -------------------------------------------------------------------------
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sel) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : _kText2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  APPLY BAR (bottom sheet)
  // -------------------------------------------------------------------------
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
        onPressed: _saving ? null : _apply,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kDark,
          disabledBackgroundColor: _kDark.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'APPLY PREMIUM FILTERS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_liveCount RESULTS',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  // -------------------------------------------------------------------------
  //  SHARED UI HELPERS
  // -------------------------------------------------------------------------
  Widget _sectionLabel(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: _kText,
    ),
  );

  Widget get _divider => const Padding(
    padding: EdgeInsets.only(bottom: 24),
    child: Divider(height: 1, color: _kBg, thickness: 2),
  );

  Widget _checkbox(bool selected) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: selected ? _kDark : Colors.white,
      border: Border.all(color: selected ? _kDark : _kBorder, width: 1.5),
      borderRadius: BorderRadius.circular(4),
    ),
    child: selected
        ? const Icon(Icons.check, color: Colors.white, size: 12)
        : null,
  );

  Widget _selectionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool rounded = false,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _kDark : Colors.white,
        border: Border.all(color: selected ? _kDark : _kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(rounded ? 24 : 8),
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
}

// -----------------------------------------------------------------------------
//  FILTER LOGIC  (used for live count inside this screen)
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

List<dynamic> _applyAllPremiumFilters(
  List<dynamic> raw,
  ApartmentFilterModel f,
) {
  List<dynamic> list = List.from(raw);

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
      return (m['city']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['bhkType']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // Area range
  if (f.areaMin > 0 || f.areaMax < 10000) {
    list = list.where((p) {
      final raw = (p as Map)['builtUpArea'];
      if (raw == null) return true;
      final area = double.tryParse(raw.toString()) ?? 0;
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

  // Nearby
  if (f.nearby.isNotEmpty) {
    list = list.where((p) {
      final nb = _parseList(
        (p as Map)['nearby'],
      ).map((e) => e.toString().toLowerCase()).toList();
      return f.nearby.every(
        (item) => nb.any((n) => n.contains(item.toLowerCase())),
      );
    }).toList();
  }

  // Restrictions
  if (f.restrictions.isNotEmpty) {
    list = list.where((p) {
      final m = p as Map;
      return f.restrictions.every((key) => isFalseOrNull(m[key]));
    }).toList();
  }

  return list;
}
