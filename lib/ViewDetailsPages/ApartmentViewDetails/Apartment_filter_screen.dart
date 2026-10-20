// ─────────────────────────────────────────────────────────────────────────────
// Apartment_filter_screen.dart
// Standard filter screen — city, locality/landmark search, BHK, rent range,
// tenant, furnishing, availability, parking, lease-only, owner-hosting.
// Returns updated ApartmentFilterModel via widget.onApply callback.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/Apartment_filter_model.dart';

// ── Google Places API Key ──────────────────────────────────────────────────
const String _kMapsApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE"; // <-- your key

// ── Palette (must match ApartmentViewDetails) ──────────────────────────────
const Color _kDark   = Color(0xFF1A2B40);
const Color _kText   = Color(0xFF111827);
const Color _kText2  = Color(0xFF4B5563);
const Color _kText3  = Color(0xFF9CA3AF);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kBg     = Color(0xFFF5F6F8);
const Color _kRed    = Color(0xFFFF3B30);

// ── Static option lists ────────────────────────────────────────────────────
const _kCities       = ['Chennai', 'Coimbatore', 'Bangalore', 'Hyderabad'];
const _kBhkTypes     = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK', '4+ BHK'];
const _kTenants      = ['Family', 'Company', 'Bachelor Male', 'Bachelor Female'];
const _kFurnishing   = ['Full', 'Semi', 'None'];
const _kAvailability = ['Immediately', 'Within 15 days', 'Within 30 days', 'After 30 days'];
const _kParkingTypes = ['2 Wheeler', '4 Wheeler'];

// ── Autocomplete suggestion model ─────────────────────────────────────────
class _PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory _PlaceSuggestion.fromJson(Map<String, dynamic> j) {
    final st = j['structured_formatting'] as Map<String, dynamic>? ?? {};
    return _PlaceSuggestion(
      placeId:       j['place_id'] as String? ?? '',
      mainText:      st['main_text'] as String? ?? j['description'] as String? ?? '',
      secondaryText: st['secondary_text'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ApartmentFilterScreen extends StatefulWidget {
  final ApartmentFilterModel              initial;
  final List<dynamic>                     allProperties;
  final void Function(ApartmentFilterModel) onApply;

  const ApartmentFilterScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<ApartmentFilterScreen> createState() => _ApartmentFilterScreenState();
}

class _ApartmentFilterScreenState extends State<ApartmentFilterScreen> {
  late ApartmentFilterModel _f;
  late RangeValues _rentRange;

  // ── Locality search state ────────────────────────────────────────────────
  final TextEditingController _localityCtrl = TextEditingController();
  final FocusNode             _localityFocus = FocusNode();
  List<_PlaceSuggestion>      _sugg          = [];
  bool                        _loading       = false;
  bool                        _noResult      = false;
  Timer?                      _debounce;

  // ── Country/component bias derived from selected city ───────────────────
  // Google Places: restrict to India; optionally pass city as location bias
  static const _countryCode = 'IN';

  @override
  void initState() {
    super.initState();
    _f = widget.initial.copyWith();
    _rentRange = RangeValues(
      _f.rentMin.clamp(0, 500000),
      _f.rentMax.clamp(0, 500000),
    );

    // Pre-fill locality field if filter already has a value
    if (_f.locality.isNotEmpty) {
      _localityCtrl.text = _f.locality;
    }

    _localityFocus.addListener(() => setState(() {}));
    _localityCtrl.addListener(_onLocalityChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _localityCtrl.dispose();
    _localityFocus.dispose();
    super.dispose();
  }

  // ── Debounced Places Autocomplete fetch ──────────────────────────────────
  void _onLocalityChanged() {
    final query = _localityCtrl.text.trim();

    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _sugg     = [];
        _noResult = false;
        _loading  = false;
        _f        = _f.copyWith(locality: '');
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String input) async {
    if (!mounted) return;
    setState(() { _loading = true; _noResult = false; });

    // Build components param to restrict to selected city when available
    final components = _f.city.isNotEmpty
        ? 'country:$_countryCode'          // You can extend to locality:${_f.city} if needed
        : 'country:$_countryCode';

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input':      input,
      'types':      'geocode',             // returns localities, sub-localities, etc.
      'components': components,
      'key':        _kMapsApiKey,
    });

    try {
      final res = await http.get(uri);
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data        = jsonDecode(res.body) as Map<String, dynamic>;
        final predictions = (data['predictions'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .map(_PlaceSuggestion.fromJson)
            .toList();

        setState(() {
          _sugg     = predictions;
          _noResult = predictions.isEmpty;
          _loading  = false;
        });
      } else {
        setState(() { _loading = false; _noResult = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _noResult = true; });
    }
  }

  // ── User picks a suggestion ──────────────────────────────────────────────
  void _pickSuggestion(_PlaceSuggestion p) {
    // Use mainText as the locality filter value (e.g. "Adyar", "T Nagar")
    final label = p.mainText;
    _localityCtrl.removeListener(_onLocalityChanged);
    _localityCtrl.text = label;
    _localityCtrl.selection =
        TextSelection.collapsed(offset: label.length);
    _localityCtrl.addListener(_onLocalityChanged);

    setState(() {
      _sugg     = [];
      _noResult = false;
      _f        = _f.copyWith(locality: label);
    });
    _localityFocus.unfocus();
  }

  // ── Clear locality field ─────────────────────────────────────────────────
  void _clearLocality() {
    _localityCtrl.clear();
    setState(() {
      _sugg     = [];
      _noResult = false;
      _f        = _f.copyWith(locality: '');
    });
  }

  // ── Live result count ────────────────────────────────────────────────────
  int get _liveCount =>
      _applyStandardFilters(List<dynamic>.from(widget.allProperties), _f).length;

  // ── Toggle helper ────────────────────────────────────────────────────────
  List<String> _toggle(List<String> list, String val) {
    final c = List<String>.from(list);
    c.contains(val) ? c.remove(val) : c.add(val);
    return c;
  }

  // ── Reset (standard filters only, preserve premium) ─────────────────────
  void _reset() {
    _localityCtrl.clear();
    setState(() {
      _f = ApartmentFilterModel(city: _f.city).copyWith(
        amenities:    _f.amenities,
        nearby:       _f.nearby,
        restrictions: _f.restrictions,
        premiumSort:  _f.premiumSort,
        areaMin:      _f.areaMin,
        areaMax:      _f.areaMax,
        propertyAges: _f.propertyAges,
        showOnly:     _f.showOnly,
        removeSeen:   _f.removeSeen,
        bathroom:     _f.bathroom,
        floors:       _f.floors,
      );
      _rentRange = const RangeValues(0, 500000);
      _sugg      = [];
      _noResult  = false;
    });
  }

  // ── Apply ────────────────────────────────────────────────────────────────
  void _apply() => widget.onApply(
        _f.copyWith(
          rentMin: _rentRange.start,
          rentMax: _rentRange.end >= 500000 ? 1000000 : _rentRange.end,
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── 1. City ──────────────────────────────────────────────
                  _sectionLabel('Select City'),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value:     _f.city.isEmpty ? null : _f.city,
                    hint:      'Select City',
                    items:     _kCities,
                    onChanged: (v) {
                      // Clear locality when city changes
                      _localityCtrl.clear();
                      setState(() {
                        _f        = _f.copyWith(city: v ?? '', locality: '');
                        _sugg     = [];
                        _noResult = false;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── 2. Locality / Landmark search (below city) ───────────
                  _sectionLabel('Search Locality / Landmark'),
                  const SizedBox(height: 10),
                  _localitySearchBlock(),
                  const SizedBox(height: 24),

                  // ── 3. BHK Type ──────────────────────────────────────────
                  _sectionLabel('BHK Type'),
                  const SizedBox(height: 12),
                  _buildChips(
                    items:    _kBhkTypes,
                    selected: _f.bhkTypes,
                    onTap: (v) => setState(
                        () => _f = _f.copyWith(bhkTypes: _toggle(_f.bhkTypes, v))),
                  ),
                  const SizedBox(height: 24),

                  // ── 4. Rent Range ────────────────────────────────────────
                  _sectionLabel(
                    'Rent Range:  ₹${_fmt(_rentRange.start.toInt())}  –  '
                    '${_rentRange.end >= 500000 ? '₹5L+' : '₹${_fmt(_rentRange.end.toInt())}'}',
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor:   _kDark,
                      inactiveTrackColor: _kBorder,
                      thumbColor:         _kDark,
                      overlayColor:       _kDark.withOpacity(0.12),
                      rangeThumbShape:
                          const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                      trackHeight: 4,
                    ),
                    child: RangeSlider(
                      values:    _rentRange,
                      min:       0,
                      max:       500000,
                      divisions: 100,
                      onChanged: (v) => setState(() => _rentRange = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹0',   style: _rangeStyle),
                      Text('₹5L+', style: _rangeStyle),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _divider,

                  // ── 5. Preferred Tenant ──────────────────────────────────
                  _sectionLabel('Preferred Tenant'),
                  const SizedBox(height: 10),
                  _buildCheckGrid(
                    items:    _kTenants,
                    selected: _f.preferredTenant.isEmpty ? [] : [_f.preferredTenant],
                    onToggle: (v) => setState(() => _f = _f.copyWith(
                        preferredTenant: _f.preferredTenant == v ? '' : v)),
                    columns: 2,
                  ),
                  const SizedBox(height: 24),

                  // ── 6. Furnishing ────────────────────────────────────────
                  _sectionLabel('Furnishing'),
                  const SizedBox(height: 10),
                  _buildCheckGrid(
                    items:    _kFurnishing,
                    selected: _f.furnishing.isEmpty ? [] : [_f.furnishing],
                    onToggle: (v) => setState(() => _f = _f.copyWith(
                        furnishing: _f.furnishing == v ? '' : v)),
                    columns: 3,
                  ),
                  const SizedBox(height: 24),
                  _divider,

                  // ── 7. Availability ──────────────────────────────────────
                  _sectionLabel('Availability'),
                  const SizedBox(height: 10),
                  _buildRadioGrid(_kAvailability),
                  const SizedBox(height: 24),
                  _divider,

                  // ── 8. Parking ───────────────────────────────────────────
                  _sectionLabel('Parking'),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Yes', 'No'].map((opt) {
                      final sel = _f.parking == opt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _f = _f.copyWith(parking: sel ? '' : opt)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding:  const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color:        sel ? _kDark : Colors.white,
                              border:       Border.all(
                                  color: sel ? _kDark : _kBorder, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Parking $opt',
                              style: TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color:      sel ? Colors.white : _kText2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_f.parking == 'Yes') ...[
                    const SizedBox(height: 12),
                    _buildCheckGrid(
                      items:    _kParkingTypes,
                      selected: _f.parkingTypes,
                      onToggle: (v) => setState(() => _f = _f.copyWith(
                          parkingTypes: _toggle(_f.parkingTypes, v))),
                      columns: 2,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _divider,

                  // ── 9. Extra toggles ─────────────────────────────────────
                  _buildSwitchTile(
                    title:    'Owner Hosting a Visit',
                    subtitle: 'Properties with visits scheduled within next 2 days',
                    badge:    'New',
                    value:    _f.ownerHosting,
                    onChanged: (v) =>
                        setState(() => _f = _f.copyWith(ownerHosting: v)),
                  ),
                  const SizedBox(height: 10),
                  _buildSwitchTile(
                    title:    'Show Only Lease Properties',
                    value:    _f.leaseOnly,
                    onChanged: (v) =>
                        setState(() => _f = _f.copyWith(leaseOnly: v)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildApplyBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCALITY SEARCH BLOCK  (Google-style autocomplete)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _localitySearchBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search TextField ───────────────────────────────────────────
        Container(
          height:  52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _localityFocus.hasFocus
                  ? _kDark
                  : _kBorder,
              width: _localityFocus.hasFocus ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: _localityCtrl,
                  focusNode:  _localityFocus,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF202124)),
                  decoration: const InputDecoration(
                    border:         InputBorder.none,
                    isDense:        true,
                    contentPadding: EdgeInsets.zero,
                    hintText:       'Search locality or landmark',
                    hintStyle:      TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),

              if (_loading)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kDark),
                )
              else if (_localityCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearLocality,
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
            ],
          ),
        ),

        // ── Suggestions List ───────────────────────────────────────────
        if (_sugg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset:     const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_sugg.length, (index) {
                  final p      = _sugg[index];
                  final isLast = index == _sugg.length - 1;

                  return InkWell(
                    onTap: () => _pickSuggestion(p),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Color(0xFF9AA0A6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.mainText,
                                      maxLines:  1,
                                      overflow:  TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize:   14,
                                        fontWeight: FontWeight.w600,
                                        color:      Color(0xFF202124),
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
                                          color:    Color(0xFF5F6368),
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
                            height:    1,
                            thickness: 0.6,
                            indent:    44,
                            color:     Color(0xFFF1F3F4),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

        // ── No Results ─────────────────────────────────────────────────
        if (_noResult)
          Container(
            margin:  const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _kBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_off_rounded, size: 18, color: Color(0xFF9AA0A6)),
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

  // ── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor:  Colors.white,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon:      const Icon(Icons.close, color: _kText, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Filters',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kText),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset',
                style: TextStyle(
                    color: _kText2, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child:         Divider(height: 1, color: _kBorder),
        ),
      );

  // ── Apply bar ─────────────────────────────────────────────────────────────
  Widget _buildApplyBar() => Container(
        decoration: const BoxDecoration(
          color:  Colors.white,
          border: Border(top: BorderSide(color: _kBorder)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        child: SizedBox(
          width:  double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDark,
              shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'APPLY FILTERS',
                  style: TextStyle(
                    fontSize:      14,
                    fontWeight:    FontWeight.w800,
                    color:         Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_liveCount RESULTS',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Dropdown ─────────────────────────────────────────────────────────────
  Widget _buildDropdown({
    required String?               value,
    required String                hint,
    required List<String>          items,
    required ValueChanged<String?> onChanged,
  }) =>
      Container(
        height:     52,
        padding:    const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          border:       Border.all(color: _kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:         value,
            isExpanded:    true,
            hint:          Text(hint, style: const TextStyle(color: _kText3, fontSize: 13)),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kText3, size: 20),
            dropdownColor: Colors.white,
            borderRadius:  BorderRadius.circular(14),
            style:         const TextStyle(fontSize: 14, color: _kText),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );

  // ── Chip row ──────────────────────────────────────────────────────────────
  Widget _buildChips({
    required List<String>          items,
    required List<String>          selected,
    required void Function(String) onTap,
  }) =>
      Wrap(
        spacing:    10,
        runSpacing: 10,
        children: items.map((item) {
          final sel = selected.contains(item);
          return GestureDetector(
            onTap: () => onTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color:        sel ? _kDark : Colors.white,
                border:       Border.all(color: sel ? _kDark : _kBorder, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      sel ? Colors.white : _kText2,
                ),
              ),
            ),
          );
        }).toList(),
      );

  // ── Availability radio grid ───────────────────────────────────────────────
  Widget _buildRadioGrid(List<String> items) {
    final w = (MediaQuery.of(context).size.width - 32) / 2;
    return Wrap(
      children: items.map((item) {
        final sel = _f.availability == item;
        return SizedBox(
          width: w,
          child: RadioListTile<String>(
            value:          item,
            groupValue:     _f.availability,
            activeColor:    _kDark,
            dense:          true,
            contentPadding: EdgeInsets.zero,
            title: Text(item,
                style: const TextStyle(fontSize: 13, color: _kText2)),
            onChanged: (v) => setState(
                () => _f = _f.copyWith(availability: sel ? '' : (v ?? ''))),
          ),
        );
      }).toList(),
    );
  }

  // ── Checkbox grid ─────────────────────────────────────────────────────────
  Widget _buildCheckGrid({
    required List<String>          items,
    required List<String>          selected,
    required void Function(String) onToggle,
    int                            columns = 2,
  }) {
    final w = (MediaQuery.of(context).size.width - 32) / columns;
    return Wrap(
      children: items.map((item) {
        final sel = selected.contains(item);
        return SizedBox(
          width: w,
          child: CheckboxListTile(
            value:           sel,
            activeColor:     _kDark,
            dense:           true,
            contentPadding:  EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item,
                style: const TextStyle(fontSize: 13, color: _kText2)),
            onChanged: (_) => onToggle(item),
          ),
        );
      }).toList(),
    );
  }

  // ── Switch tile ───────────────────────────────────────────────────────────
  Widget _buildSwitchTile({
    required String             title,
    String?                     subtitle,
    String?                     badge,
    required bool               value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        _kBg,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color:      _kText)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color:        _kRed,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(badge,
                              style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 11, color: _kText3)),
                  ],
                ],
              ),
            ),
            Switch(
              value:            value,
              onChanged:        onChanged,
              activeColor:      _kDark,
              activeTrackColor: _kDark.withOpacity(0.3),
            ),
          ],
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: _kText));

  Widget get _divider => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child:   Divider(height: 1, color: _kBg, thickness: 2),
      );

  TextStyle get _rangeStyle =>
      const TextStyle(fontSize: 11, color: _kText3);

  String _fmt(int v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STANDARD FILTER LOGIC  (used only for live count inside this screen)
// ─────────────────────────────────────────────────────────────────────────────

List<dynamic> _applyStandardFilters(
    List<dynamic> raw, ApartmentFilterModel f) {
  List<dynamic> list = List.from(raw);

  if (f.city.isNotEmpty) {
    list = list.where((p) =>
        (p as Map)['city']?.toString().toLowerCase().trim() ==
        f.city.toLowerCase().trim()).toList();
  }

  if (f.locality.isNotEmpty) {
    final q = f.locality.toLowerCase();
    list = list.where((p) {
      final m = p as Map;
      return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['landmark']?.toString().toLowerCase().contains(q)    ?? false) ||
          (m['street']?.toString().toLowerCase().contains(q)      ?? false);
    }).toList();
  } else if (f.search.isNotEmpty) {
    final q = f.search.toLowerCase();
    list = list.where((p) {
      final m = p as Map;
      return (m['locality']?.toString().toLowerCase().contains(q) ?? false) ||
          (m['bhkType']?.toString().toLowerCase().contains(q)     ?? false) ||
          (m['city']?.toString().toLowerCase().contains(q)        ?? false);
    }).toList();
  }

  if (f.bhkTypes.isNotEmpty) {
    list = list.where((p) {
      final bhk = (p as Map)['bhkType']?.toString().toLowerCase().trim() ?? '';
      return f.bhkTypes.any((s) =>
          bhk.contains(s.toLowerCase().trim()) ||
          s.toLowerCase().trim().contains(bhk));
    }).toList();
  }

  if (f.preferredTenant.isNotEmpty) {
    final want = f.preferredTenant.toLowerCase().trim();
    list = list.where((p) {
      final raw     = (p as Map)['preferredTenant'];
      final tenants = (raw is List ? raw : (raw != null ? [raw] : []))
          .whereType<String>()
          .map((e) => e.toLowerCase().trim())
          .toList();
      if (tenants.isEmpty) return false;
      return tenants.contains(want) ||
          tenants.contains('anyone') ||
          tenants.contains('any');
    }).toList();
  }

  if (f.furnishing.isNotEmpty) {
    final want = f.furnishing.toLowerCase().trim();
    list = list.where((p) {
      final furn =
          (p as Map)['furnishing']?.toString().toLowerCase().trim() ?? '';
      return furn.contains(want);
    }).toList();
  }

  if (f.availability.isNotEmpty) {
    final now = DateTime.now();
    list = list.where((p) {
      final avFrom = (p as Map)['availableFrom']?.toString();
      if (avFrom == null || avFrom.isEmpty) return true;
      final dt = DateTime.tryParse(avFrom);
      if (dt == null) return true;
      if (f.availability == 'Immediately')    return !dt.isAfter(now);
      if (f.availability == 'Within 15 days') return !dt.isAfter(now.add(const Duration(days: 15)));
      if (f.availability == 'Within 30 days') return !dt.isAfter(now.add(const Duration(days: 30)));
      return true;
    }).toList();
  }

  if (f.parking.isNotEmpty) {
    list = list.where((p) {
      final pk =
          (p as Map)['parking']?.toString().toLowerCase().trim() ?? '';
      final hasParking = pk.isNotEmpty && pk != 'none';
      final noParking  = pk.isEmpty    || pk == 'none';
      if (f.parking.toLowerCase() == 'yes') return hasParking;
      if (f.parking.toLowerCase() == 'no')  return noParking;
      return true;
    }).toList();
  }

  if (f.rentMin > 0 || (f.rentMax > 0 && f.rentMax < 1000000)) {
    list = list.where((p) {
      final rentRaw = (p as Map)['expectedRent'];
      if (rentRaw == null) return true;
      final rent = double.tryParse(rentRaw.toString()) ?? 0;
      if (rent <= 0) return true;
      final minOk = f.rentMin <= 0 || rent >= f.rentMin;
      final maxOk = f.rentMax <= 0 || f.rentMax >= 1000000 || rent <= f.rentMax;
      return minOk && maxOk;
    }).toList();
  }

  return list;
}
