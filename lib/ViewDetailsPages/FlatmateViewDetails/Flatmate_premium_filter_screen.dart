// -----------------------------------------------------------------------------
// Flatmate_filter_screen.dart
// Full filter screen for the Flatmate module
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'Flatmate_filter_model.dart';

// --- Constants ----------------------------------------------------------------

const String _kGoogleApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE"; // ?? replace

const Map<String, Map<String, double>> _kCityCentres = {
  'Chennai':    {'lat': 13.0827, 'lng': 80.2707},
  'Coimbatore': {'lat': 11.0168, 'lng': 76.9558},
  'Hyderabad':  {'lat': 17.3850, 'lng': 78.4867},
  'Bangalore':  {'lat': 12.9716, 'lng': 77.5946},
};

// --- Theme --------------------------------------------------------------------

class _T {
  static const Color primary  = Color(0xFF1A2B40);
  static const Color accent   = Color(0xFF0A7C66);
  static const Color bg       = Color(0xFFFFFFFF);
  static const Color chipBg   = Color(0xFFF3F4F6);
  static const Color border   = Color(0xFFE5E7EB);
  static const Color text     = Color(0xFF1A1A2E);
  static const Color muted    = Color(0xFF9CA3AF);
  static const Color muted2   = Color(0xFF4B5563);
  static const Color greenBg  = Color(0xFFF0FAF4);
}

// --- Google Places Models -----------------------------------------------------

class _Prediction {
  final String placeId, mainText, secondaryText;
  const _Prediction({required this.placeId, required this.mainText, required this.secondaryText});

  factory _Prediction.fromJson(Map<String, dynamic> j) {
    final sf = j['structured_formatting'] as Map<String, dynamic>? ?? {};
    return _Prediction(
      placeId:       j['place_id'] as String? ?? '',
      mainText:      sf['main_text'] as String? ?? j['description'] as String? ?? '',
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
  static void _newSession() => _session = DateTime.now().millisecondsSinceEpoch.toString();

  static Future<List<_Prediction>> autocomplete(String input, String city) async {
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
      return (body['predictions'] as List).map((p) => _Prediction.fromJson(p)).toList();
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
      final comps = (body['results'][0]['address_components'] as List).cast<Map<String, dynamic>>();
      String get(List<String> types) {
        for (final c in comps) {
          if ((c['types'] as List).cast<String>().any(types.contains))
            return c['long_name'] as String? ?? '';
        }
        return '';
      }
      return _PlaceDetails(
        locality: get(['sublocality_level_1', 'sublocality_level_2', 'neighborhood']),
        city:     get(['locality']),
      );
    } catch (_) {
      return const _PlaceDetails();
    }
  }
}

// -----------------------------------------------------------------------------
// FlatmateFilterScreen
// -----------------------------------------------------------------------------

class FlatmateFilterScreen extends StatefulWidget {
  final FlatmateFilterModel initial;
  final List<dynamic> allProperties;
  final void Function(FlatmateFilterModel) onApply;

  const FlatmateFilterScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<FlatmateFilterScreen> createState() => _FlatmateFilterScreenState();
}

class _FlatmateFilterScreenState extends State<FlatmateFilterScreen> {
  // -- Controllers -----------------------------------------------------------
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  final _link  = LayerLink();

  // -- Filter state (mirrors FlatmateFilterModel) ----------------------------
  late String _city;
  late String _tenantType;
  late String _bhkType;
  late String _roomType;
  late String _furnishing;
  late String _propertyType;
  late String _parking;
  late String _floor;
  late String _bathroom;
  late String _availability;
  late List<String> _showOnly;
  late bool _removeSeenProperties;
  late RangeValues _rentRange;
  static const double _maxRent = 100000;

  // -- Locality search state -------------------------------------------------
  List<_Prediction> _sugg    = [];
  _PlaceDetails?    _place;
  bool              _loading = false;
  bool              _noResult = false;
  Timer?            _debounce;
  OverlayEntry?     _overlay;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _city                 = f.city;
    _tenantType           = f.tenantType;
    _bhkType              = f.bhkType;
    _roomType             = f.roomType;
    _furnishing           = f.furnishing;
    _propertyType         = f.propertyType;
    _parking              = f.parking;
    _floor                = f.floor;
    _bathroom             = f.bathroom;
    _availability         = f.availability;
    _showOnly             = List.from(f.showOnly);
    _removeSeenProperties = f.removeSeenProperties;
    _rentRange = RangeValues(
      f.rentMin.clamp(0, _maxRent),
      f.rentMax >= 1000000 ? _maxRent : f.rentMax.clamp(0, _maxRent),
    );

    if (f.locality.isNotEmpty) _ctrl.text = f.locality;

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

  // -- Text / focus listeners -------------------------------------------------

  void _onText() {
    final v = _ctrl.text;
    if (v.isEmpty) {
      _debounce?.cancel();
      _dropOverlay();
      setState(() { _sugg = []; _place = null; _noResult = false; });
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
    setState(() { _loading = true; _noResult = false; });
    final res = await _Places.autocomplete(v, _city);
    if (!mounted) return;
    setState(() {
      _sugg     = res;
      _loading  = false;
      _noResult = res.isEmpty && v.isNotEmpty;
    });
    res.isNotEmpty ? _showOverlay() : _dropOverlay();
  }

  Future<void> _pick(_Prediction p) async {
    _dropOverlay();
    setState(() { _ctrl.text = p.mainText; _sugg = []; _loading = true; });
    final d = await _Places.geocode(p.placeId);
    if (!mounted) return;
    setState(() { _place = d; _loading = false; });
  }

  void _clearSearch() {
    _dropOverlay();
    _ctrl.clear();
    setState(() { _sugg = []; _place = null; _noResult = false; });
    _focus.requestFocus();
  }

  void _resetAll() {
    _dropOverlay();
    _ctrl.clear();
    setState(() {
      _city                 = '';
      _tenantType           = '';
      _bhkType              = '';
      _roomType             = '';
      _furnishing           = '';
      _propertyType         = '';
      _parking              = '';
      _floor                = '';
      _bathroom             = '';
      _availability         = '';
      _showOnly             = [];
      _removeSeenProperties = false;
      _rentRange            = const RangeValues(0, _maxRent);
      _sugg                 = [];
      _place                = null;
      _noResult             = false;
    });
  }

  // -- Overlay ----------------------------------------------------------------

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
          child: Material(color: Colors.transparent, child: _buildDropdown()),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _dropOverlay() { _overlay?.remove(); _overlay = null; }

  // -- Apply ------------------------------------------------------------------

  void _applyFilters() {
    _dropOverlay();
    final updated = FlatmateFilterModel(
      city:                 _city,
      locality:             _place?.locality ?? '',
      search:               _place == null ? _ctrl.text.trim() : '',
      rentMin:              _rentRange.start,
      rentMax:              _rentRange.end >= _maxRent ? 1000000 : _rentRange.end,
      tenantType:           _tenantType,
      bhkType:              _bhkType,
      roomType:             _roomType,
      furnishing:           _furnishing,
      propertyType:         _propertyType,
      parking:              _parking,
      floor:                _floor,
      bathroom:             _bathroom,
      availability:         _availability,
      showOnly:             List.from(_showOnly),
      removeSeenProperties: _removeSeenProperties,
      // map showOnly ? boolean fields
      nonVegAllowed:        _showOnly.contains('Non Veg Allowed') ? true : null,
      gym:                  _showOnly.contains('Gym') ? true : null,
    );
    widget.onApply(updated);
    Navigator.pop(context);
  }

  // ------------------------------- BUILD ------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness:     Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cityDropdown(),
                    const SizedBox(height: 20),
                    _section('Location', _localityField()),
                    const SizedBox(height: 20),
                    _section('Rent Range', _rentRangeSlider()),
                    const SizedBox(height: 20),
                    _section('Tenant Type', _tenantTypeChips()),
                    const SizedBox(height: 20),
                    _section('BHK Type', _bhkTypeChips()),
                    const SizedBox(height: 20),
                    _section('Room Type', _roomTypeChips()),
                    const SizedBox(height: 20),
                    _section('Furnishing', _furnishingChips()),
                    const SizedBox(height: 20),
                    _section('Property Type', _propertyTypeChips()),
                    const SizedBox(height: 20),
                    _section('Availability', _availabilityChips()),
                    const SizedBox(height: 20),
                    _section('Floor', _floorChips()),
                    const SizedBox(height: 20),
                    _section('Parking', _parkingChips()),
                    const SizedBox(height: 20),
                    _section('Bathroom', _bathroomChips()),
                    const SizedBox(height: 20),
                    _section('Show Only', _showOnlyChips()),
                    const SizedBox(height: 20),
                    _section('Other', _otherOptions()),
                  ],
                ),
              ),
            ),
            _applyBar(),
          ],
        ),
      ),
    );
  }

  // -- AppBar -----------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor:      Colors.white,
    elevation:            0,
    scrolledUnderElevation: 0,
    centerTitle:          true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, size: 22, color: _T.text),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Filters',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _T.text),
    ),
    actions: [
      TextButton(
        onPressed: _resetAll,
        child: const Text(
          'Reset',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _T.accent),
        ),
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: _T.border),
    ),
  );

  // -- Section wrapper --------------------------------------------------------

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _T.text),
      ),
      const SizedBox(height: 12),
      child,
    ],
  );

  // -- City dropdown ----------------------------------------------------------

  Widget _cityDropdown() => Container(
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
              value:         _city.isEmpty ? null : _city,
              isExpanded:    true,
              hint: const Text('Select City', style: TextStyle(fontSize: 14, color: _T.muted)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _T.muted),
              style: const TextStyle(fontSize: 14, color: _T.text),
              dropdownColor: Colors.white,
              borderRadius:  BorderRadius.circular(14),
              onChanged: (v) {
                if (v == null) return;
                setState(() { _city = v; _place = null; });
                _clearSearch();
              },
              items: _kCityCentres.keys.map((city) {
                final sel = city == _city;
                return DropdownMenuItem<String>(
                  value: city,
                  child: Container(
                    margin:     const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color:        sel ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16,
                            color: sel ? const Color(0xFF6366F1) : _T.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            city,
                            style: TextStyle(
                              fontSize:   14,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                              color:      sel ? _T.text : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        if (sel) const Icon(Icons.check_rounded, size: 16, color: Color(0xFF6366F1)),
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

  Widget _localityField() => CompositedTransformTarget(
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
              focusNode:  _focus,
              style: const TextStyle(fontSize: 14, color: _T.text),
              decoration: const InputDecoration(
                border:         InputBorder.none,
                isDense:        true,
                contentPadding: EdgeInsets.zero,
                hintText:       'Search locality or landmark...',
                hintStyle:      TextStyle(fontSize: 14, color: _T.muted),
              ),
              onTap: () { if (_ctrl.text.isNotEmpty && _sugg.isNotEmpty) _showOverlay(); },
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _T.accent),
            )
          else if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: const Icon(Icons.close_rounded, size: 16, color: _T.muted),
            )
          else
            const Icon(Icons.my_location_rounded, size: 18, color: _T.muted),
        ],
      ),
    ),
  );

  // -- Suggestions dropdown ---------------------------------------------------

  Widget _buildDropdown() => Container(
    constraints: const BoxConstraints(maxHeight: 260),
    decoration: BoxDecoration(
      color: _T.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _T.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: ListView.separated(
      shrinkWrap:   true,
      padding:      EdgeInsets.zero,
      itemCount:    _sugg.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _T.border, indent: 44),
      itemBuilder: (_, i) {
        final p = _sugg[i];
        return InkWell(
          onTap: () => _pick(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: _T.greenBg, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on_outlined, size: 15, color: _T.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.mainText,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _T.text),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (p.secondaryText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(p.secondaryText,
                            style: const TextStyle(fontSize: 11, color: _T.muted),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
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
          trackHeight:       3,
          activeTrackColor:  _T.primary,
          inactiveTrackColor: _T.border,
          thumbColor:        _T.primary,
          thumbShape:        const RoundSliderThumbShape(enabledThumbRadius: 10),
          overlayColor:      _T.primary.withOpacity(0.12),
          rangeThumbShape:   const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
        ),
        child: RangeSlider(
          values:    _rentRange,
          min:       0,
          max:       _maxRent,
          divisions: 100,
          onChanged: (v) => setState(() => _rentRange = v),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('? ${_fmt(_rentRange.start.toInt())}',
              style: const TextStyle(fontSize: 12, color: _T.muted2)),
          Text(
            _rentRange.end >= _maxRent ? '? 1,00,000+' : '? ${_fmt(_rentRange.end.toInt())}',
            style: const TextStyle(fontSize: 12, color: _T.muted2),
          ),
        ],
      ),
    ],
  );

  String _fmt(int n) {
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
      if (count == 2 && i != 0) { result = ',$result'; count = 0; }
    }
    return '$result,$last3';
  }

  // -- Chip builders ----------------------------------------------------------

  /// Single-select chip group — tapping same value deselects
  Widget _singleSelectChips({
    required List<String> options,
    required String selected,
    required void Function(String) onSelect,
    IconData? Function(String)? iconOf,
  }) =>
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((lbl) {
          final sel  = selected == lbl;
          final icon = iconOf?.call(lbl);
          return _chip(
            label:    lbl,
            selected: sel,
            icon:     icon,
            onTap:    () => onSelect(sel ? '' : lbl),
          );
        }).toList(),
      );

  /// Multi-select chip group
  Widget _multiSelectChips({
    required List<String> options,
    required List<String> selected,
    required void Function(String) onToggle,
  }) =>
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((lbl) {
          final sel = selected.contains(lbl);
          return _chip(label: lbl, selected: sel, onTap: () => onToggle(lbl));
        }).toList(),
      );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:  selected ? _T.primary : _T.chipBg,
            border: Border.all(color: selected ? _T.primary : _T.border, width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : _T.muted2),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                  color:      selected ? Colors.white : _T.muted2,
                ),
              ),
            ],
          ),
        ),
      );

  // -- Individual filter sections ---------------------------------------------

  Widget _tenantTypeChips() => _singleSelectChips(
    options:  ['Male', 'Female', 'Anyone'],
    selected: _tenantType,
    onSelect: (v) => setState(() => _tenantType = v),
    iconOf: (lbl) => lbl == 'Male'
        ? Icons.male_rounded
        : lbl == 'Female'
            ? Icons.female_rounded
            : Icons.people_outline,
  );

  Widget _bhkTypeChips() => _singleSelectChips(
    options:  ['1 BHK', '2 BHK', '3 BHK', '4 BHK', '4+ BHK'],
    selected: _bhkType,
    onSelect: (v) => setState(() => _bhkType = v),
  );

  Widget _roomTypeChips() => _singleSelectChips(
    options:  ['Single room', 'Shared Room'],
    selected: _roomType,
    onSelect: (v) => setState(() => _roomType = v),
    iconOf: (lbl) => lbl == 'Single room' ? Icons.person_outline : Icons.people_outline,
  );

  Widget _furnishingChips() => _singleSelectChips(
    options:  ['Full', 'Semi', 'None'],
    selected: _furnishing,
    onSelect: (v) => setState(() => _furnishing = v),
  );

  Widget _propertyTypeChips() => _singleSelectChips(
    options:  [
      'Apartment',
      'Independent House/Villa',
      'Gated Societies',
      'Gated Community Villa',
    ],
    selected: _propertyType,
    onSelect: (v) => setState(() => _propertyType = v),
  );

  Widget _availabilityChips() => _singleSelectChips(
    options:  ['Immediately', 'Within 15 days', 'Within 30 days'],
    selected: _availability,
    onSelect: (v) => setState(() => _availability = v),
  );

  Widget _floorChips() => _singleSelectChips(
    options:  ['Ground', '1 to 3', '4 to 6', '7 to 9', '10 & above'],
    selected: _floor,
    onSelect: (v) => setState(() => _floor = v),
  );

  Widget _parkingChips() => _singleSelectChips(
    options:  ['2 Wheeler', '4 Wheeler', 'Both'],
    selected: _parking,
    onSelect: (v) => setState(() => _parking = v),
    iconOf:   (_) => Icons.local_parking_rounded,
  );

  Widget _bathroomChips() => _singleSelectChips(
    options:  ['1 or more', '2 or more', '3 or more'],
    selected: _bathroom,
    onSelect: (v) => setState(() => _bathroom = v),
  );

  Widget _showOnlyChips() => _multiSelectChips(
    options:  ['Non Veg Allowed', 'With Photos', 'Gym'],
    selected: _showOnly,
    onToggle: (v) => setState(() {
      _showOnly.contains(v) ? _showOnly.remove(v) : _showOnly.add(v);
    }),
  );

  Widget _otherOptions() => Row(
    children: [
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _removeSeenProperties = !_removeSeenProperties),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:  _removeSeenProperties ? _T.primary : _T.chipBg,
              border: Border.all(
                color: _removeSeenProperties ? _T.primary : _T.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_off_outlined, size: 16,
                    color: _removeSeenProperties ? Colors.white : _T.muted2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remove Seen Properties',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w500,
                      color:      _removeSeenProperties ? Colors.white : _T.muted2,
                    ),
                  ),
                ),
                if (_removeSeenProperties)
                  const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  // -- Apply bar --------------------------------------------------------------

  Widget _applyBar() => Container(
    color: _T.bg,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _applyFilters,
          style: ElevatedButton.styleFrom(
            backgroundColor: _T.primary,
            elevation:       0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'APPLY FILTERS',
            style: TextStyle(
              fontSize:    15,
              fontWeight:  FontWeight.w700,
              color:       Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    ),
  );
}
