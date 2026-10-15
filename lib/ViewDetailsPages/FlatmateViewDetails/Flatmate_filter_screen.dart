// Flatmate_filter_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/Flatmate_filter_model.dart';
import 'package:rentit/main/filter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Constants ----------------------------------------------------------------

const String _kGoogleApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";

const Map<String, Map<String, double>> _kCityCentres = {
  'Chennai': {'lat': 13.0827, 'lng': 80.2707},
};

// --- Theme --------------------------------------------------------------------

class _T {
  static const Color primary = Color(0xFF1A2B40);
  static const Color primaryBg = Color(0xFFF0FAF4);
  static const Color border = Color(0xFFE5E7EB);
  static const Color text = Color(0xFF1A1A2E);
  static const Color muted = Color(0xFF9CA3AF);
  static const Color muted2 = Color(0xFF4B5563);
  static const Color bg = Color(0xFFFFFFFF);
  static const Color chipBg = Color(0xFFF3F4F6);
  static const Color sliderTrack = Color(0xFF1A2B40);
  static const Color accent = Color(0xFF0A7C66);
}

// --- Models -------------------------------------------------------------------

class _Prediction {
  final String placeId, mainText, secondaryText;
  const _Prediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory _Prediction.fromJson(Map<String, dynamic> j) {
    final sf = j['structured_formatting'] as Map<String, dynamic>? ?? {};
    return _Prediction(
      placeId: j['place_id'] as String? ?? '',
      mainText: sf['main_text'] as String? ?? j['description'] as String? ?? '',
      secondaryText: sf['secondary_text'] as String? ?? '',
    );
  }
}

class _PlaceDetails {
  final String locality, city;
  const _PlaceDetails({this.locality = '', this.city = ''});
}

// --- Google Places Service ----------------------------------------------------

class _Places {
  static String _session = DateTime.now().millisecondsSinceEpoch.toString();
  static void _newSession() =>
      _session = DateTime.now().millisecondsSinceEpoch.toString();

  static Future<List<_Prediction>> autocomplete(
    String input,
    String city,
  ) async {
    if (input.trim().isEmpty) return [];
    final c = _kCityCentres[city];
    final loc = c != null
        ? '&location=${c['lat']},${c['lng']}&radius=25000&strictbounds=true'
        : '';
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&components=country:in$loc'
      '&sessiontoken=$_session&key=$_kGoogleApiKey',
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body['status'] != 'OK') return [];
      return (body['predictions'] as List)
          .map((p) => _Prediction.fromJson(p))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<_PlaceDetails> geocode(String placeId) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?place_id=${Uri.encodeComponent(placeId)}'
      '&sessiontoken=$_session&key=$_kGoogleApiKey',
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return const _PlaceDetails();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return const _PlaceDetails();
      _newSession();
      final comps = (body['results'][0]['address_components'] as List)
          .cast<Map<String, dynamic>>();
      String get(List<String> types) {
        for (final c in comps) {
          if ((c['types'] as List).cast<String>().any(types.contains))
            return c['long_name'] as String? ?? '';
        }
        return '';
      }

      return _PlaceDetails(
        locality: get([
          'sublocality_level_1',
          'sublocality_level_2',
          'neighborhood',
        ]),
        city: get(['locality']),
      );
    } catch (_) {
      return const _PlaceDetails();
    }
  }
}

// --- FlatmateFilterScreen (entry point) --------------------------------------

class FlatmateFilterScreen extends StatelessWidget {
  final FlatmateFilterModel initial;
  final List<dynamic> allProperties;
  final Function(FlatmateFilterModel) onApply;

  const FlatmateFilterScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _FiltersWidget(
          initial: initial,
          allProperties: allProperties,
          onApply: onApply,
        ),
      ),
    );
  }
}

// --- Filters Widget -----------------------------------------------------------

class _FiltersWidget extends StatefulWidget {
  final FlatmateFilterModel initial;
  final List<dynamic> allProperties;
  final Function(FlatmateFilterModel) onApply;

  const _FiltersWidget({
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<_FiltersWidget> createState() => _FiltersWidgetState();
}

class _FiltersWidgetState extends State<_FiltersWidget> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  // -- Filter state -----------------------------------------------------------
  String _city = '';
  String _tenantType = ''; // 'Male' | 'Female' | ''
  String _roomType = ''; // 'Single room' | 'Shared Room' | ''
  String _furnishing =
      ''; // 'Fully Furnished' | 'Semi Furnished' | 'Unfurnished' | ''
  String _propertyType =
      ''; // 'Apartment' | 'Independent House/Villa' | 'Gated Community Villa' | ''
  String _showOnly = ''; // 'Non Veg Allowed' | 'With Photos' | 'Gym' | ''
  bool _removeSeen = false;
  String _floor = ''; // 'Ground' | '1 to 3' | ... | ''
  String _parking = ''; // '2 Wheeler' | '4 Wheeler' | ''
  String _bathroom = ''; // '1 or more' | '2 or more' | '3 or more' | ''
  String _availability =
      ''; // 'Immediately' | 'Within 15 days' | 'Within 30 days' | ''

  RangeValues _rentRange = const RangeValues(0, 100000);
  static const double _maxRent = 100000;

  // -- Place search state -----------------------------------------------------
  List<_Prediction> _sugg = [];
  _PlaceDetails? _place;
  bool _loading = false;
  bool _noResult = false;
  bool _isSaving = false;

  Timer? _debounce;

  // -- Lifecycle --------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _city = 'Chennai';
    _propertyType = widget.initial.propertyType;
    _ctrl.addListener(_onText);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onText);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // -- Text listener ----------------------------------------------------------

  void _onText() {
    final v = _ctrl.text;
    if (v.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _sugg = [];
        _place = null;
        _noResult = false;
      });
      return;
    }
    if (_place != null) setState(() => _place = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(v));
  }

  Future<void> _fetch(String v) async {
    if (_city.isEmpty) return;
    setState(() {
      _loading = true;
      _noResult = false;
    });
    final res = await _Places.autocomplete(v, _city);
    if (!mounted) return;
    setState(() {
      _sugg = res;
      _loading = false;
      _noResult = res.isEmpty && v.isNotEmpty;
    });
  }

  Future<void> _pick(_Prediction p) async {
    setState(() {
      _ctrl.text = p.mainText;
      _sugg = [];
      _loading = true;
      _noResult = false;
    });
    _focus.unfocus();
    final d = await _Places.geocode(p.placeId);
    if (!mounted) return;
    setState(() {
      _place = d;
      _loading = false;
    });
  }

  void _clearSearch() {
    _ctrl.clear();
    setState(() {
      _sugg = [];
      _place = null;
      _noResult = false;
    });
    _focus.requestFocus();
  }

  // -- Reset all --------------------------------------------------------------

  void _resetAll() {
    _ctrl.clear();
    setState(() {
      _city = 'Chennai';
      _tenantType = '';
      _roomType = '';
      _furnishing = '';
      _propertyType = '';
      _showOnly = '';
      _removeSeen = false;
      _floor = '';
      _parking = '';
      _bathroom = '';
      _availability = '';
      _rentRange = const RangeValues(0, _maxRent);
      _sugg = [];
      _place = null;
      _noResult = false;
    });
  }

  // -- Save preference --------------------------------------------------------

  Future<void> _savePreference(PgFilterModel filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId");
      if (userId == null) return;
      await http.post(
        Uri.parse("https://rentit-backend-yti9.onrender.com/preferences"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "city": filter.city.isNotEmpty ? filter.city : null,
          "locality": filter.locality.isNotEmpty ? filter.locality : null,
          "search": filter.search.isNotEmpty ? filter.search : null,
          "rentMin": filter.rentMin,
          "rentMax": filter.rentMax,
        }),
      );
    } catch (e) {
      debugPrint("? API ERROR ?? $e");
    }
  }

  // -- Apply filters ----------------------------------------------------------

  Future<void> _applyFilters() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final filter = FlatmateFilterModel(
        city: _city,
        locality: _place?.locality ?? '',
        search: _place == null ? _ctrl.text.trim() : '',
        tenantType: _tenantType,
        roomType: _roomType,
        furnishing: _furnishing,
        propertyType: _propertyType,
        availability: _availability,
        parking: _parking,
        floor: _floor,
        bathroom: _bathroom,
        showOnly: _showOnly.isNotEmpty ? [_showOnly] : [],
        removeSeenProperties: _removeSeen,
        rentMin: _rentRange.start.toDouble(),
        rentMax: _rentRange.end >= _maxRent ? 0 : _rentRange.end.toDouble(),
      );

      if (!mounted) return;
      widget.onApply(filter);
      Navigator.pop(context);
    } finally {
      _isSaving = false;
    }
  }

  int get _liveCount {
    var list = List<dynamic>.from(widget.allProperties);

    if (_city.isNotEmpty) {
      list = list.where((p) {
        return (p as Map)['city']?.toString().toLowerCase().trim() ==
            _city.toLowerCase().trim();
      }).toList();
    }

    final loc = _place?.locality ?? '';
    if (loc.isNotEmpty) {
      final q = loc.toLowerCase();
      list = list.where((p) {
        final m = p as Map;
        return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['street']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['landmark']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }

    final search = _place == null ? _ctrl.text.trim().toLowerCase() : '';
    if (search.isNotEmpty) {
      final q = search;
      list = list.where((p) {
        final m = p as Map;
        return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['street']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['landmark']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['apartmentName']?.toString().toLowerCase().contains(q) ??
                false) ||
            (m['city']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_tenantType.isNotEmpty) {
      final want = _tenantType.toLowerCase();
      list = list.where((p) {
        final t =
            (p as Map)['tenantType']?.toString().toLowerCase().trim() ?? '';
        if (t.isEmpty || t == 'anyone') return true;
        return t == want;
      }).toList();
    }

    if (_roomType.isNotEmpty) {
      final want = _roomType.toLowerCase().trim();
      list = list.where((p) {
        return (p as Map)['roomType']?.toString().toLowerCase().trim() == want;
      }).toList();
    }

    if (_furnishing.isNotEmpty) {
      list = list.where((p) {
        return (p as Map)['furnishing']?.toString().toLowerCase().trim() ==
            _furnishing.toLowerCase().trim();
      }).toList();
    }

    if (_propertyType.isNotEmpty) {
      final Map<String, List<String>> propertyTypeMap = {
        'Apartment': ['Apartment'],
        'Independent House/Villa': [
          'Independent House',
          'Independent House/Villa',
          'Villa',
        ],
        'Gated Community Villa': ['Gated Community Villa'],
      };
      final allowedTypes = propertyTypeMap[_propertyType] ?? [_propertyType];
      list = list.where((p) {
        final apartmentType =
            (p as Map<String, dynamic>)['apartmentType']?.toString().trim() ??
            '';
        return allowedTypes.any(
          (type) => apartmentType.toLowerCase() == type.toLowerCase(),
        );
      }).toList();
    }

    if (_parking.isNotEmpty) {
      final want = _parking.toLowerCase();
      list = list.where((p) {
        final pk = (p as Map)['parking']?.toString().toLowerCase().trim() ?? '';
        if (want == '2 wheeler') return pk == 'bike' || pk == 'bike & car';
        if (want == '4 wheeler') return pk == 'car' || pk == 'bike & car';
        if (want == 'both') return pk == 'bike & car';
        return true;
      }).toList();
    }

    if (_floor.isNotEmpty) {
      list = list.where((p) {
        final fl = int.tryParse((p as Map)['floor']?.toString() ?? '');
        if (fl == null) return false;
        if (_floor == 'Ground') return fl == 0;
        if (_floor == '1 to 3') return fl >= 1 && fl <= 3;
        if (_floor == '4 to 6') return fl >= 4 && fl <= 6;
        if (_floor == '7 to 9') return fl >= 7 && fl <= 9;
        if (_floor == '10 & above') return fl >= 10;
        return false;
      }).toList();
    }

    if (_bathroom.isNotEmpty) {
      list = list.where((p) {
        final m = p as Map;
        final hasAttached =
            m['attachedBathroom'] == true ||
            m['bathroomType'] == 'Private Bathroom';
        if (_bathroom == '1 or more') return hasAttached;
        if (_bathroom == '2 or more' || _bathroom == '3 or more') return false;
        return true;
      }).toList();
    }

    if (_availability.isNotEmpty) {
      final now = DateTime.now();
      list = list.where((p) {
        final raw = (p as Map)['availableFrom']?.toString();
        if (raw == null || raw.isEmpty) return true;
        final dt = DateTime.tryParse(raw);
        if (dt == null) return true;
        if (_availability == 'Immediately') return !dt.isAfter(now);
        if (_availability == 'Within 15 days')
          return !dt.isAfter(now.add(const Duration(days: 15)));
        if (_availability == 'Within 30 days')
          return !dt.isAfter(now.add(const Duration(days: 30)));
        return true;
      }).toList();
    }

    if (_showOnly == 'Non Veg Allowed') {
      list = list.where((p) => (p as Map)['nonVegAllowed'] == true).toList();
    } else if (_showOnly == 'Gym') {
      list = list.where((p) => (p as Map)['gym'] == true).toList();
    } else if (_showOnly == 'With Photos') {
      list = list.where((p) {
        final imgs = (p as Map)['images'];
        return imgs is List && imgs.isNotEmpty;
      }).toList();
    }

    if (_rentRange.start > 0 ||
        (_rentRange.end > 0 && _rentRange.end < _maxRent)) {
      list = list.where((p) {
        final rent =
            double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ?? 0;
        if (rent <= 0) return true;
        final minOk = _rentRange.start <= 0 || rent >= _rentRange.start;
        final maxOk =
            _rentRange.end <= 0 ||
            _rentRange.end >= _maxRent ||
            rent <= _rentRange.end;
        return minOk && maxOk;
      }).toList();
    }

    return list.length;
  }

  // ------------------------------- BUILD ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24, color: _T.text),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Filters',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _T.text,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22, color: _T.text),
            onPressed: _resetAll,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _T.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // -- City ----------------------------------------------
                  _cityDropdownField(),
                  const SizedBox(height: 20),

                  // -- Locality Search + inline suggestions ---------------
                  _section(
                    'Search Locality / Landmark',
                    _localitySearchBlock(),
                  ),
                  const SizedBox(height: 20),

                  // -- Rent Range -----------------------------------------
                  _section('Rent Range', _rentRangeSlider()),
                  const SizedBox(height: 20),

                  // -- Tenant Type ----------------------------------------
                  _section('Tenant Type', _tenantTypeChips()),
                  const SizedBox(height: 20),

                  // -- Room Type ------------------------------------------
                  _section('Room Type', _roomTypeChips()),
                  const SizedBox(height: 20),

                  // -- Furnishing -----------------------------------------
                  _section('Furnishing', _furnishingChips()),
                  const SizedBox(height: 20),

                  // -- Apartment Type -------------------------------------
                  _section('Apartment Type', _apartmentTypeChips()),
                  const SizedBox(height: 20),

                  // -- Show Only ------------------------------------------
                  _section('Show Only', _showOnlyChips()),
                  const SizedBox(height: 20),

                  // -- Remove Seen Properties -----------------------------
                  _section('Remove Seen Properties', _removeSeenChip()),
                  const SizedBox(height: 20),

                  // -- Floors --------------------------------------------
                  _section('Floors', _floorChips()),
                  const SizedBox(height: 20),

                  // -- Parking -------------------------------------------
                  _section('Parking', _parkingChips()),
                  const SizedBox(height: 20),

                  // -- Bathroom ------------------------------------------
                  _section('Bathroom', _bathroomChips()),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _applyBar(),
        ],
      ),
    );
  }

  // --- Section wrapper ------------------------------------------------------

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _T.text,
        ),
      ),
      const SizedBox(height: 12),
      child,
    ],
  );

  // --- City dropdown --------------------------------------------------------

  Widget _cityDropdownField() => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: _T.bg,
      border: Border.all(color: _T.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_city_outlined, size: 18, color: _T.muted),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _city.isEmpty ? null : _city,
              isExpanded: true,
              hint: const Text(
                'Select City',
                style: TextStyle(fontSize: 14, color: _T.muted),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _T.muted,
              ),
              style: const TextStyle(fontSize: 14, color: _T.text),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _city = v;
                  _place = null;
                });
                _clearSearch();
              },
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
                          ? const Color(0xFFEEF2FF)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : _T.muted,
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
                                  ? _T.text
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
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
      ],
    ),
  );

  // --- Locality search field + inline suggestions ---------------------------
  //
  // Renders as a plain Column inside the scroll view � NO overlay, NO LayerLink.
  // Suggestions appear inline, pushing page content down, exactly like the
  // reference screenshot.

  Widget _localitySearchBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- Search input field --------------------------------------------
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _T.bg,
            border: Border.all(
              color: _focus.hasFocus ? _T.primary : _T.border,
              width: _focus.hasFocus ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18, color: _T.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(fontSize: 14, color: _T.text),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search locality or landmark',
                    hintStyle: TextStyle(fontSize: 14, color: _T.muted),
                  ),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _T.accent,
                  ),
                )
              else if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearch,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _T.muted,
                  ),
                )
              else
                const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: _T.muted,
                ),
            ],
          ),
        ),

        // -- Inline suggestions list ---------------------------------------
        if (_sugg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDADCE0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_sugg.length, (index) {
                  final p = _sugg[index];
                  final isLast = index == _sugg.length - 1;

                  // Choose icon based on place type hint
                  final IconData pinIcon;
                  final secLower = p.secondaryText.toLowerCase();
                  final mainLower = p.mainText.toLowerCase();
                  if (secLower.contains('mall') ||
                      secLower.contains('hospital') ||
                      secLower.contains('school') ||
                      secLower.contains('college') ||
                      mainLower.contains('square') ||
                      mainLower.contains('plaza') ||
                      mainLower.contains('complex')) {
                    pinIcon = Icons.store_outlined;
                  } else {
                    pinIcon = Icons.location_on_outlined;
                  }

                  return InkWell(
                    onTap: () => _pick(p),
                    splashColor: const Color(0xFFF1F3F4),
                    highlightColor: const Color(0xFFF1F3F4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                pinIcon,
                                size: 18,
                                color: const Color(0xFF9AA0A6),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.mainText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF202124),
                                      ),
                                    ),
                                    if (p.secondaryText.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        p.secondaryText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF5F6368),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            thickness: 0.6,
                            indent: 44,
                            endIndent: 0,
                            color: Color(0xFFF1F3F4),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

        // -- No results hint -----------------------------------------------
        if (_noResult)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDADCE0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 18,
                  color: Color(0xFF9AA0A6),
                ),
                SizedBox(width: 12),
                Text(
                  'No results found',
                  style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Rent Range Slider ----------------------------------------------------

  Widget _rentRangeSlider() => Column(
    children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: _T.sliderTrack,
          inactiveTrackColor: _T.border,
          thumbColor: _T.sliderTrack,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          overlayColor: _T.sliderTrack.withOpacity(0.12),
          rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          rangeThumbShape: const RoundRangeSliderThumbShape(
            enabledThumbRadius: 10,
          ),
        ),
        child: RangeSlider(
          values: _rentRange,
          min: 0,
          max: _maxRent,
          divisions: 100,
          onChanged: (v) => setState(() => _rentRange = v),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '? ${_formatNum(_rentRange.start.toInt())}',
            style: const TextStyle(fontSize: 12, color: _T.muted2),
          ),
          Text(
            _rentRange.end >= _maxRent
                ? '? 1,00,000+'
                : '? ${_formatNum(_rentRange.end.toInt())}',
            style: const TextStyle(fontSize: 12, color: _T.muted2),
          ),
        ],
      ),
    ],
  );

  String _formatNum(int n) {
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

  // --------------------------------------------------------------------------
  // FILTER WIDGETS
  // --------------------------------------------------------------------------

  // -- Tenant Type ---------------------------------------------------------

  Widget _tenantTypeChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _iconChip(
        label: 'Male',
        icon: Icons.male_rounded,
        selected: _tenantType == 'Male',
        onTap: () =>
            setState(() => _tenantType = _tenantType == 'Male' ? '' : 'Male'),
      ),
      _iconChip(
        label: 'Female',
        icon: Icons.female_rounded,
        selected: _tenantType == 'Female',
        onTap: () => setState(
          () => _tenantType = _tenantType == 'Female' ? '' : 'Female',
        ),
      ),
    ],
  );

  // -- Room Type ------------------------------------------------------------

  Widget _roomTypeChips() {
    final opts = <Map<String, dynamic>>[
      {'label': 'Single room', 'icon': Icons.person_outline},
      {'label': 'Shared Room', 'icon': Icons.people_outline},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final lbl = o['label'] as String;
        final icon = o['icon'] as IconData;
        final sel = _roomType == lbl;
        return _iconChip(
          label: lbl,
          icon: icon,
          selected: sel,
          onTap: () => setState(() => _roomType = sel ? '' : lbl),
        );
      }).toList(),
    );
  }

  // -- Furnishing -----------------------------------------------------------

  Widget _furnishingChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Fully Furnished', 'Semi Furnished', 'Unfurnished'].map((lbl) {
      final sel = _furnishing == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _furnishing = sel ? '' : lbl),
      );
    }).toList(),
  );

  // -- Apartment Type -------------------------------------------------------

  Widget _apartmentTypeChips() {
    const types = [
      'Apartment',
      'Independent House/Villa',
      'Gated Community Villa',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((type) {
        final sel = _propertyType == type;
        return _filterChip(
          label: type,
          selected: sel,
          onTap: () => setState(() => _propertyType = sel ? '' : type),
        );
      }).toList(),
    );
  }

  // -- Show Only ------------------------------------------------------------

  Widget _showOnlyChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Non Veg Allowed', 'With Photos', 'Gym'].map((lbl) {
      final sel = _showOnly == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _showOnly = sel ? '' : lbl),
      );
    }).toList(),
  );

  // -- Remove Seen Properties ------------------------------------------------

  Widget _removeSeenChip() => GestureDetector(
    onTap: () => setState(() => _removeSeen = !_removeSeen),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _removeSeen ? _T.primary : _T.chipBg,
        border: Border.all(
          color: _removeSeen ? _T.primary : _T.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _removeSeen
                ? Icons.visibility_off_rounded
                : Icons.visibility_outlined,
            size: 15,
            color: _removeSeen ? Colors.white : _T.muted2,
          ),
          const SizedBox(width: 6),
          Text(
            'Remove Seen Properties',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _removeSeen ? Colors.white : _T.muted2,
            ),
          ),
        ],
      ),
    ),
  );

  // -- Floors ---------------------------------------------------------------

  Widget _floorChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Ground', '1 to 3', '4 to 6', '7 to 9', '10 & above'].map((lbl) {
      final sel = _floor == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _floor = sel ? '' : lbl),
      );
    }).toList(),
  );

  // -- Parking --------------------------------------------------------------

  Widget _parkingChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['2 Wheeler', '4 Wheeler'].map((lbl) {
      final sel = _parking == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _parking = sel ? '' : lbl),
      );
    }).toList(),
  );

  // -- Bathroom -------------------------------------------------------------

  Widget _bathroomChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['1 or more', '2 or more', '3 or more'].map((lbl) {
      final sel = _bathroom == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _bathroom = sel ? '' : lbl),
      );
    }).toList(),
  );

  // --- Generic chips --------------------------------------------------------

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _T.primary : _T.chipBg,
        border: Border.all(
          color: selected ? _T.primary : _T.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? Colors.white : _T.muted2,
        ),
      ),
    ),
  );

  Widget _iconChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _T.primary : _T.chipBg,
        border: Border.all(
          color: selected ? _T.primary : _T.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : _T.muted2),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : _T.muted2,
            ),
          ),
        ],
      ),
    ),
  );

  // --- Apply Filters bottom bar ---------------------------------------------

  Widget _applyBar() => Container(
    color: _T.bg,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _applyFilters,
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
