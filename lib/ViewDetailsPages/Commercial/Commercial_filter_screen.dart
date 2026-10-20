// Commercial_filter_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/ViewDetailsPages/Commercial/Commercial_filter_model.dart';
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

// --- CommercialFilterScreen ---------------------------------------------------
class CommercialFilterScreen extends StatelessWidget {
  final CommercialFilterModel initial;
  final List<dynamic> allProperties;
  final Function(CommercialFilterModel) onApply;

  const CommercialFilterScreen({
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

// --- _FiltersWidget -----------------------------------------------------------
class _FiltersWidget extends StatefulWidget {
  final CommercialFilterModel initial;
  final List<dynamic> allProperties;
  final Function(CommercialFilterModel) onApply;

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
  final _link = LayerLink();

  // -- Filter state (mirrors CommercialFilterModel fields) -------------------

  // DB: city (String)
  String _city = 'Chennai';

  // DB: commercialPropertyType (String?)
  String _commercialPropertyType = '';

  // DB: buildingType (String?)
  String _buildingType = '';

  // DB: propertyAge (String?)
  String _propertyAge = '';

  // DB: floor (Int?) � expressed as a range label
  String _floorRange = '';

  // DB: furnishing (Json?) � 'Full' | 'Semi' | 'None'
  String _furnishing = '';

  // DB: availableFrom (String? date)
  String _availability = '';

  // DB: idealFor (Json?) � 'Public' | 'Reserved'
  String _parking = '';

  // DB: expectedRent (Int?)
  RangeValues _rentRange = const RangeValues(0, 100000);
  static const double _maxRent = 100000;

  // Locality search state
  List<_Prediction> _sugg = [];
  _PlaceDetails? _place;
  bool _loading = false;
  bool _noResult = false;
  bool _isSaving = false;

  Timer? _debounce;
  OverlayEntry? _overlay;

  // -- Init -------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    // Pre-fill from initial filter
    _city = widget.initial.city.isNotEmpty ? widget.initial.city : 'Chennai';
    _commercialPropertyType = widget.initial.commercialPropertyType;
    _buildingType = widget.initial.buildingType;
    _propertyAge = widget.initial.propertyAge;
    _floorRange = widget.initial.floorRange;
    _furnishing = widget.initial.furnishing;
    _availability = widget.initial.availability;
    _parking = widget.initial.parking;

    final rMin = widget.initial.rentMin.clamp(0.0, _maxRent);
    final rMax =
        (widget.initial.rentMax >= 1000000 ? _maxRent : widget.initial.rentMax)
            .clamp(0.0, _maxRent);
    _rentRange = RangeValues(rMin, rMax);

    if (widget.initial.locality.isNotEmpty) {
      _ctrl.text = widget.initial.locality;
    } else if (widget.initial.search.isNotEmpty) {
      _ctrl.text = widget.initial.search;
    }

    _ctrl.addListener(_onText);
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ctrl.dispose();
    _focus.dispose();
    _dropOverlay();
    super.dispose();
  }

  // -- Live count -------------------------------------------------------------
  int get _liveCount {
    var list = List<dynamic>.from(widget.allProperties);

    // City
    if (_city.isNotEmpty) {
      list = list
          .where(
            (p) =>
                (p as Map)['city']?.toString().toLowerCase().trim() ==
                _city.toLowerCase().trim(),
          )
          .toList();
    }
    // Locality
    if (_ctrl.text.isNotEmpty) {
      final q = _ctrl.text.toLowerCase();
      list = list.where((p) {
        final m = p as Map;
        return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['street']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['landmark']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }
    // Commercial property type
    if (_commercialPropertyType.isNotEmpty) {
      final q = _commercialPropertyType.toLowerCase();
      list = list
          .where(
            (p) =>
                (p as Map)['commercialPropertyType']
                    ?.toString()
                    .toLowerCase() ==
                q,
          )
          .toList();
    }
    // Building type
    if (_buildingType.isNotEmpty) {
      final q = _buildingType.toLowerCase();
      list = list
          .where(
            (p) => (p as Map)['buildingType']?.toString().toLowerCase() == q,
          )
          .toList();
    }
    // Property age
    if (_propertyAge.isNotEmpty) {
      final q = _propertyAge.toLowerCase();
      list = list
          .where(
            (p) => (p as Map)['propertyAge']?.toString().toLowerCase() == q,
          )
          .toList();
    }
    // Floor range
    if (_floorRange.isNotEmpty) {
      list = list
          .where((p) => _checkFloor((p as Map)['floor'], _floorRange))
          .toList();
    }
    // Furnishing
    if (_furnishing.isNotEmpty) {
      final q = _furnishing.toLowerCase();
      list = list.where((p) {
        final fv = _parseFurnishing((p as Map)['furnishing']);
        return fv.contains(q);
      }).toList();
    }
    // Rent
    if (_rentRange.start > 0 || _rentRange.end < _maxRent) {
      list = list.where((p) {
        final rent =
            double.tryParse((p as Map)['expectedRent']?.toString() ?? '') ?? 0;
        if (rent <= 0) return true;
        return rent >= _rentRange.start && rent <= _rentRange.end;
      }).toList();
    }
    // Availability
    if (_availability.isNotEmpty) {
      final now = DateTime.now();
      list = list.where((p) {
        final avFrom = (p as Map)['availableFrom']?.toString();
        if (avFrom == null || avFrom.isEmpty) return true;
        final dt = DateTime.tryParse(avFrom);
        if (dt == null) return true;
        if (_availability == 'Immediately') return !dt.isAfter(now);
        if (_availability == 'Within 15 days')
          return !dt.isAfter(now.add(const Duration(days: 15)));
        if (_availability == 'Within 30 days')
          return !dt.isAfter(now.add(const Duration(days: 30)));
        return true;
      }).toList();
    }
    // Parking
    if (_parking.isNotEmpty) {
      list = list.where((p) {
        final otherFeatures = (p as Map)['otherFeatures'];
        if (otherFeatures == null) return false;
        Map<String, dynamic> features = {};
        try {
          features = otherFeatures is Map<String, dynamic>
              ? otherFeatures
              : Map<String, dynamic>.from(jsonDecode(otherFeatures.toString()));
        } catch (_) {
          return false;
        }
        final parking =
            features['parking']?.toString().trim().toLowerCase() ?? '';
        final selected = _parking.trim().toLowerCase();
        return parking == selected;
      }).toList();
    }

    return list.length;
  }

  bool _checkFloor(dynamic floorVal, String range) {
    final floor = int.tryParse(floorVal?.toString() ?? '');
    if (floor == null) return false;
    switch (range) {
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

  String _parseFurnishing(dynamic val) {
    if (val == null) return '';
    if (val is String) return val.toLowerCase();

    Map<String, dynamic> map = {};
    if (val is Map) {
      map = Map<String, dynamic>.from(val);
    } else {
      try {
        final decoded = jsonDecode(val.toString());
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    if (map.isEmpty) return '';

    if (map.containsKey('type')) {
      return map['type'].toString().toLowerCase();
    }

    if (map.containsKey('furnished')) {
      final isF = map['furnished'] == true || map['furnished'] == 'true';
      return isF ? 'fully furnished' : 'unfurnished';
    }

    return '';
  }

  // -- Text listener ----------------------------------------------------------
  void _onText() {
    final v = _ctrl.text;
    if (v.isEmpty) {
      _debounce?.cancel();
      _dropOverlay();
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

  void _onFocus() {
    if (!_focus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        _dropOverlay();
        setState(() {});
      });
    } else if (_sugg.isNotEmpty) {
      _showOverlay();
    }
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
    res.isNotEmpty ? _showOverlay() : _dropOverlay();
  }

  Future<void> _pick(_Prediction p) async {
    _dropOverlay();
    setState(() {
      _ctrl.text = p.mainText;
      _sugg = [];
      _loading = true;
      _noResult = false;
    });
    final d = await _Places.geocode(p.placeId);
    if (!mounted) return;
    setState(() {
      _place = d;
      _loading = false;
    });
  }

  void _clearSearch() {
    _dropOverlay();
    _ctrl.clear();
    setState(() {
      _sugg = [];
      _place = null;
      _noResult = false;
    });
    _focus.requestFocus();
  }

  void _resetAll() {
    _dropOverlay();
    _ctrl.clear();
    setState(() {
      _city = '';
      _commercialPropertyType = '';
      _buildingType = '';
      _propertyAge = '';
      _floorRange = '';
      _furnishing = '';
      _availability = '';
      _parking = '';
      _rentRange = const RangeValues(0, _maxRent);
      _sugg = [];
      _place = null;
      _noResult = false;
    });
  }

  // -- Save preference to backend ---------------------------------------------
  Future<void> _savePreference(CommercialFilterModel filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return;

      await http.post(
        Uri.parse('https://rentit-backend-omega.vercel.app/preferences'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'city': filter.city.isNotEmpty ? filter.city : null,
          'locality': filter.locality.isNotEmpty ? filter.locality : null,
          'search': filter.search.isNotEmpty ? filter.search : null,
          'commercialPropertyType': filter.commercialPropertyType.isNotEmpty
              ? filter.commercialPropertyType
              : null,
          'buildingType': filter.buildingType.isNotEmpty
              ? filter.buildingType
              : null,
          'propertyAge': filter.propertyAge.isNotEmpty
              ? filter.propertyAge
              : null,
          'floorRange': filter.floorRange.isNotEmpty ? filter.floorRange : null,
          'furnishing': filter.furnishing.isNotEmpty ? filter.furnishing : null,
          'availability': filter.availability.isNotEmpty
              ? filter.availability
              : null,
          'parking': filter.parking.isNotEmpty ? filter.parking : null,
          'rentMin': filter.rentMin,
          'rentMax': filter.rentMax,
        }),
      );
    } catch (e) {
      debugPrint('? Preferences save error: $e');
    }
  }

  // -- Apply ------------------------------------------------------------------
  Future<void> _applyFilters() async {
    if (_isSaving) return;
    _isSaving = true;
    _dropOverlay();

    final filter = CommercialFilterModel(
      city: _city,
      locality: _place?.locality ?? '',
      search: _place == null ? _ctrl.text.trim() : '',
      commercialPropertyType: _commercialPropertyType,
      buildingType: _buildingType,
      propertyAge: _propertyAge,
      floorRange: _floorRange,
      furnishing: _furnishing,
      availability: _availability,
      parking: _parking,
      rentMin: _rentRange.start,
      rentMax: _rentRange.end >= _maxRent ? 1000000.0 : _rentRange.end,
      // Preserve premium filters from the initial model
      amenities: widget.initial.amenities,
      nearby: widget.initial.nearby,
      restrictions: widget.initial.restrictions,
      premiumSort: widget.initial.premiumSort,
    );

    await _savePreference(filter);
    _isSaving = false;

    if (!mounted) return;
    widget.onApply(filter);
    Navigator.pop(context);
  }

  // -- Overlay helpers --------------------------------------------------------
  void _showOverlay() {
    _dropOverlay();
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: 16,
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(color: Colors.transparent, child: _dropdown()),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _dropOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ------------------------------ BUILD ------------------------------------

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
                  // -- City ---------------------------------------------------
                  _cityDropdownField(),
                  const SizedBox(height: 20),

                  // -- Search / Locality --------------------------------------
                  _section(
                    'Search Locality / Landmark',
                    _landmarkSearchField(),
                  ),
                  const SizedBox(height: 20),

                  // -- Rent Range ---------------------------------------------
                  // DB: expectedRent (Int?)
                  _section('Rent Range', _rentRangeSlider()),
                  const SizedBox(height: 20),

                  // -- Commercial Property Type -------------------------------
                  // DB: commercialPropertyType (String?)
                  _section('Property Type', _commercialPropertyTypeChips()),
                  const SizedBox(height: 20),

                  // -- Building Type ------------------------------------------
                  // DB: buildingType (String?)
                  _section('Building Type', _buildingTypeChips()),
                  const SizedBox(height: 20),

                  // -- Floor Range --------------------------------------------
                  // DB: floor (Int?)
                  _section('Floor', _floorRangeChips()),
                  const SizedBox(height: 20),

                  // -- Furnishing ---------------------------------------------
                  // DB: furnishing (Json?)
                  _section('Furnishing', _furnishingChips()),
                  const SizedBox(height: 20),

                  // -- Availability -------------------------------------------
                  // DB: availableFrom (String? date)
                  _section('Availability', _availabilityChips()),
                  const SizedBox(height: 20),

                  // -- Parking ------------------------------------------------
                  // DB: idealFor (Json?)
                  _section('Parking', _parkingChips()),
                ],
              ),
            ),
          ),
          _applyBar(),
        ],
      ),
    );
  }

  // -- Section wrapper --------------------------------------------------------
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

  // -- City dropdown ----------------------------------------------------------
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
                      color: isSel
                          ? const Color(0xFFEEF2FF)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: isSel ? const Color(0xFF6366F1) : _T.muted,
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
                              color: isSel ? _T.text : const Color(0xFF374151),
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
      ],
    ),
  );

  // -- Locality search field --------------------------------------------------
  Widget _landmarkSearchField() => CompositedTransformTarget(
    link: _link,
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _T.bg,
        border: Border.all(
          color: _focus.hasFocus ? _T.primary : _T.border,
          width: _focus.hasFocus ? 1.5 : 1,
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
              onTap: () {
                if (_ctrl.text.isNotEmpty && _sugg.isNotEmpty) _showOverlay();
              },
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
              child: const Icon(Icons.close_rounded, size: 18, color: _T.muted),
            )
          else
            const Icon(Icons.my_location_rounded, size: 18, color: _T.muted),
        ],
      ),
    ),
  );

  // -- Suggestions dropdown ---------------------------------------------------
  Widget _dropdown() => Container(
    constraints: const BoxConstraints(maxHeight: 280),
    decoration: BoxDecoration(
      color: _T.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _T.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _sugg.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: _T.border, indent: 44),
      itemBuilder: (_, i) {
        final p = _sugg[i];
        return InkWell(
          onTap: () => _pick(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _T.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: _T.accent,
                  ),
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
                          color: _T.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.secondaryText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          p.secondaryText,
                          style: const TextStyle(fontSize: 11, color: _T.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.north_west_rounded, size: 13, color: _T.muted),
              ],
            ),
          ),
        );
      },
    ),
  );

  // -- Rent Range Slider ------------------------------------------------------
  Widget _rentRangeSlider() => Column(
    children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: _T.sliderTrack,
          inactiveTrackColor: _T.border,
          thumbColor: _T.sliderTrack,
          overlayColor: _T.sliderTrack.withOpacity(0.12),
          rangeThumbShape: const RoundRangeSliderThumbShape(
            enabledThumbRadius: 10,
          ),
          rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
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

  // -- Commercial Property Type chips -----------------------------------------
  // DB: commercialPropertyType (String?)
  Widget _commercialPropertyTypeChips() {
    final types = [
      {'label': 'Office Space', 'icon': Icons.business_center_outlined},
      {'label': 'Co-Working', 'icon': Icons.groups_outlined},
      {'label': 'Shop', 'icon': Icons.storefront_outlined},
      {'label': 'Showroom', 'icon': Icons.store_outlined},
      {'label': 'Godown/Warehouse', 'icon': Icons.warehouse_outlined},
      {'label': 'Industrial Shed', 'icon': Icons.factory_outlined},
      {'label': 'Industrial Building', 'icon': Icons.domain_outlined},
      {'label': 'Other business', 'icon': Icons.more_horiz_rounded},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((t) {
        final lbl = t['label'] as String;
        final icon = t['icon'] as IconData;
        final sel = _commercialPropertyType == lbl;
        return GestureDetector(
          onTap: () => setState(() => _commercialPropertyType = sel ? '' : lbl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _T.primary : _T.chipBg,
              border: Border.all(
                color: sel ? _T.primary : _T.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: sel ? Colors.white : _T.muted2),
                const SizedBox(width: 6),
                Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : _T.muted2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // -- Building Type chips ----------------------------------------------------
  // DB: buildingType (String?)
  Widget _buildingTypeChips() {
    const types = [
      'Independent House',
      'Business Park',
      'Standalone Building',
      'Mall',
      'Independent Shop',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((lbl) {
        final sel = _buildingType == lbl;
        return _filterChip(
          label: lbl,
          selected: sel,
          onTap: () => setState(() => _buildingType = sel ? '' : lbl),
        );
      }).toList(),
    );
  }

  // -- Floor Range chips ------------------------------------------------------
  // DB: floor (Int?)
  Widget _floorRangeChips() {
    const ranges = [
      'Ground',
      '1 - 5',
      '6 - 10',
      '11 - 20',
      '21 - 50',
      '51 & above',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ranges.map((r) {
        final sel = _floorRange == r;
        return _filterChip(
          label: r,
          selected: sel,
          onTap: () => setState(() => _floorRange = sel ? '' : r),
        );
      }).toList(),
    );
  }

  // -- Furnishing chips -------------------------------------------------------
  // DB: furnishing (Json?) � first item / string value
  Widget _furnishingChips() {
    const opts = ["Fully Furnished", "Semi Furnished", "Unfurnished"];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final sel = _furnishing == o;
        return _filterChip(
          label: o,
          selected: sel,
          onTap: () => setState(() => _furnishing = sel ? '' : o),
        );
      }).toList(),
    );
  }

  // -- Availability chips -----------------------------------------------------
  // DB: availableFrom (String? date)
  Widget _availabilityChips() {
    const opts = ['Immediately', 'Within 15 days', 'Within 30 days'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final sel = _availability == o;
        return _filterChip(
          label: o,
          selected: sel,
          onTap: () => setState(() => _availability = sel ? '' : o),
        );
      }).toList(),
    );
  }

  // -- Parking chips ----------------------------------------------------------
  // DB: idealFor (Json?) � repurposed for parking type
  Widget _parkingChips() {
    const opts = ['Public', 'Reserved'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final sel = _parking == o;
        return _filterChip(
          label: o,
          selected: sel,
          onTap: () => setState(() => _parking = sel ? '' : o),
        );
      }).toList(),
    );
  }

  // -- Generic filter chip ----------------------------------------------------
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

  // -- Apply bar --------------------------------------------------------------
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
