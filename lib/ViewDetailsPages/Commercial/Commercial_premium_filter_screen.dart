// Commercial_premium_filter_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/ViewDetailsPages/Commercial/Commercial_filter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Palette -------------------------------------------------------------------
const Color _kDark = Color(0xFF1A2B40);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kText = Color(0xFF111827);
const Color _kText2 = Color(0xFF4B5563);
const Color _kText3 = Color(0xFF9CA3AF);
const Color _kBorder = Color(0xFFE5E7EB);

// -- Google Places config ------------------------------------------------------
const String _kGoogleApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";

const Map<String, Map<String, double>> _kCityCentres = {
  'Chennai': {'lat': 13.0827, 'lng': 80.2707},
};

const List<Map<String, String>> _kAmenities = [
  {'label': 'Lift', 'backendKey': 'lift'}, // "Personal" / "Common"
  {
    'label': 'Power Backup',
    'backendKey': 'powerBackup',
  }, // "Partial Backup" / "Full Backup" / "DG Backup"
  {
    'label': 'Security',
    'backendKey': 'security',
  }, // "Security Guard" / "CCTV" / "Gated Security" / "24/7 Security"
  {'label': 'Washroom', 'backendKey': 'washroom'}, // "Shared" / "Private"
  {
    'label': 'Water Storage',
    'backendKey': 'waterStorage',
  }, // "Overhead Tank" / "Underground Tank" / "24/7 Water Supply"
  {
    'label': 'Parking',
    'backendKey': 'parking',
  }, // "Public" / "Reserved" / "Public And Reserved"
];
// NOTE: Removed the duplicate 'CCTV' entry � security covers it since the value IS "CCTV"

// -- Floor ranges --------------------------------------------------------------
// DB: floor (Int?) � must match _floorInRange() switch cases exactly
const List<String> _kFloorRanges = [
  'Ground',
  '1 - 5',
  '6 - 10',
  '11 - 20',
  '21 - 50',
  '51 & above',
];

// -- Property age --------------------------------------------------------------
// DB: propertyAge (String?)
const List<String> _kPropertyAges = [
  'Less than a year',
  '1 to 3 years',
  '3 to 5 years',
  '5 to 10 years',
  'More than 10 years',
];

// -- Prediction model ----------------------------------------------------------
class _Prediction {
  final String placeId, mainText, secondaryText;
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

// -- Floor helper (must match CommercialViewDetails._floorInRange exactly) -----
bool _floorInRange(dynamic floorVal, String range) {
  int? floor;
  if (floorVal is int)
    floor = floorVal;
  else if (floorVal is double)
    floor = floorVal.toInt();
  else if (floorVal != null)
    floor = int.tryParse(floorVal.toString().trim());
  if (floor == null) return false;

  switch (range.trim()) {
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

// -- Amenity check helper ------------------------------------------------------
// DB: otherFeatures is a JSON map with string values e.g. {"lift": "Common", "parking": "Public"}
// We check if the key exists AND has a non-null / non-empty / non-"None" / non-"No" value
bool _hasAmenityByKey(Map p, String backendKey) {
  final of = p['otherFeatures'];

  Map<String, dynamic> features = {};
  if (of is Map<String, dynamic>) {
    features = of;
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

// ------------------------------------------------------------------------------
class CommercialPremiumFilterScreen extends StatefulWidget {
  final CommercialFilterModel initial;
  final List<dynamic> allProperties;
  final void Function(CommercialFilterModel) onApply;

  const CommercialPremiumFilterScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<CommercialPremiumFilterScreen> createState() =>
      _CommercialPremiumFilterScreenState();
}

class _CommercialPremiumFilterScreenState
    extends State<CommercialPremiumFilterScreen> {
  // -- State ------------------------------------------------------------------
  late CommercialFilterModel _f;

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
    _city = _f.city.isNotEmpty ? _f.city : 'Chennai';
    _localityCtrl.text = _f.locality.isNotEmpty ? _f.locality : _f.search;
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

    // City
    if (_city.isNotEmpty) {
      list = list.where((p) {
        final city = (p as Map)['city']?.toString().toLowerCase().trim() ?? '';
        return city == _city.toLowerCase().trim();
      }).toList();
    }

    // Locality
    if (_localityCtrl.text.isNotEmpty) {
      final q = _localityCtrl.text.toLowerCase();
      list = list.where((p) {
        final m = p as Map;
        return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['street']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['landmark']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Amenities ? DB: otherFeatures (Json?)
    if (_f.amenities.isNotEmpty) {
      list = list.where((p) {
        return _f.amenities.every((key) => _hasAmenityByKey(p as Map, key));
      }).toList();
    }

    // Floor multi-select ? DB: floor (Int?)
    if (_f.nearby.isNotEmpty) {
      list = list.where((p) {
        return _f.nearby.any(
          (range) => _floorInRange((p as Map)['floor'], range),
        );
      }).toList();
    }

    // Property age multi-select ? DB: propertyAge (String?)
    if (_f.restrictions.isNotEmpty) {
      list = list.where((p) {
        final age = (p as Map)['propertyAge']?.toString() ?? '';
        return _f.restrictions.any((r) => age.toLowerCase() == r.toLowerCase());
      }).toList();
    }

    return list.length;
  }

  // -- Google Places ----------------------------------------------------------
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
    if (_city.isEmpty) return;
    final centre = _kCityCentres[_city];
    String bias = '';
    if (centre != null) {
      bias =
          '&location=${centre['lat']},${centre['lng']}&radius=30000&strictbounds=true';
    }
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:in$bias'
        '&key=$_kGoogleApiKey',
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final preds = body['predictions'] as List? ?? [];
      setState(() {
        _suggestions = preds
            .map((e) => _Prediction.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Places error: $e');
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

  // -- Toggle helpers ---------------------------------------------------------
  void _toggleAmenity(String key) {
    final copy = List<String>.from(_f.amenities);
    copy.contains(key) ? copy.remove(key) : copy.add(key);
    setState(() => _f = _f.copyWith(amenities: copy));
  }

  void _toggleFloor(String val) {
    final copy = List<String>.from(_f.nearby);
    copy.contains(val) ? copy.remove(val) : copy.add(val);
    setState(() => _f = _f.copyWith(nearby: copy));
  }

  void _toggleAge(String val) {
    final copy = List<String>.from(_f.restrictions);
    copy.contains(val) ? copy.remove(val) : copy.add(val);
    setState(() => _f = _f.copyWith(restrictions: copy));
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
    _city = '';
  });

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
            'city': _f.city.isNotEmpty ? _f.city : null,
            'locality': _f.locality.isNotEmpty ? _f.locality : null,
            'amenities': _f.amenities,
            'nearby': _f.nearby,
            'restrictions': _f.restrictions,
            'premiumSort': _f.premiumSort,
          }),
        );
      }
    } catch (e) {
      debugPrint('Preferences save error: $e');
    }
    widget.onApply(_f);
    if (mounted) Navigator.pop(context);
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
            // -- Location ---------------------------------------------------
            _buildLocationSection(),
            const SizedBox(height: 28),

            // -- Amenities --------------------------------------------------
            _sectionTitle('Amenities'),
            const SizedBox(height: 4),
            const Text(
              'Filter by available amenities',
              style: TextStyle(fontSize: 11, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildAmenityChips(),
            const SizedBox(height: 28),

            // -- Floor Range ------------------------------------------------
            _sectionTitle('Floor'),
            const SizedBox(height: 4),
            const Text(
              'Select one or more floor ranges',
              style: TextStyle(fontSize: 11, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildFloorChips(),
            const SizedBox(height: 28),

            // -- Property Age -----------------------------------------------
            _sectionTitle('Property Age'),
            const SizedBox(height: 4),
            const Text(
              'Select one or more age ranges',
              style: TextStyle(fontSize: 11, color: _kText3),
            ),
            const SizedBox(height: 12),
            _buildPropertyAgeChips(),
            const SizedBox(height: 28),

            // -- Show Only --------------------------------------------------
            _sectionTitle('Show Only'),
            const SizedBox(height: 12),
            _buildShowOnlyButton(),
          ],
        ),
      ),
      bottomSheet: _buildApplyBar(),
    );
  }

  // -- AppBar -----------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: _kText, size: 24),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(width: 6),
        Text(
          'Premium Filters',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2F3542),
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        onPressed: _reset,
        icon: const Icon(Icons.refresh_rounded, color: _kText2, size: 22),
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: _kBorder),
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _city.isEmpty ? null : _city,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(fontSize: 14, color: _kText),
            hint: const Text(
              'Select City',
              style: TextStyle(color: _kText3, fontSize: 13),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kText3,
              size: 20,
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _city = v;
                _f = _f.copyWith(city: v, locality: '');
                _localityCtrl.clear();
                _suggestions = [];
              });
            },
            items: _kCityCentres.keys.map((city) {
              final isSel = city == _city;
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
                    color: isSel ? const Color(0xFFEEF2FF) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isSel ? const Color(0xFF6366F1) : _kText3,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          city,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSel ? _kText : const Color(0xFF374151),
                          ),
                        ),
                      ),
                      if (isSel)
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

      const SizedBox(height: 16),
      _sectionTitle('Search Locality'),
      const SizedBox(height: 12),

      // Locality search field + suggestions
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(10),
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

            // Autocomplete suggestions
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

  // -- Amenity chips ----------------------------------------------------------
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

  // -- Floor chips ------------------------------------------------------------
  Widget _buildFloorChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kFloorRanges.map((r) {
      final isSel = _f.nearby.contains(r);
      return _chip(label: r, selected: isSel, onTap: () => _toggleFloor(r));
    }).toList(),
  );

  // -- Property age chips -----------------------------------------------------
  Widget _buildPropertyAgeChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: _kPropertyAges.map((age) {
      final isSel = _f.restrictions.contains(age);
      return _chip(label: age, selected: isSel, onTap: () => _toggleAge(age));
    }).toList(),
  );

  // -- Show Only button -------------------------------------------------------
  Widget _buildShowOnlyButton() {
    const value = 'New Listings';
    final sel = _f.premiumSort == value;
    return GestureDetector(
      onTap: () =>
          setState(() => _f = _f.copyWith(premiumSort: sel ? '' : value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: sel ? _kDark : Colors.white,
          border: Border.all(color: sel ? _kDark : _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.sparkles,
              size: 15,
              color: sel ? _kOrange : _kText3,
            ),
            const SizedBox(width: 8),
            Text(
              'New Listings Only',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : _kText2,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
