// Search.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/Search/SearchModel.dart';
import 'package:rentit/main/filter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Constants ----------------------------------------------------------------

const String _kGoogleApiKey = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";

const Map<String, Map<String, double>> _kCityCentres = {
  'Chennai': {'lat': 13.0827, 'lng': 80.2707},
};

// --- Apartment static option lists --------------------------------------------

const _kBhkTypes = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4 BHK', '4+ BHK'];
const _kTenants = ['Family', 'Company', 'Bachelor Male', 'Bachelor Female'];
const _kFurnishing = ['Full', 'Semi', 'None'];
const _kAvailability = [
  'Immediately',
  'Within 15 days',
  'Within 30 days',
  'After 30 days',
];
const _kParkingTypes = ['2 Wheeler', '4 Wheeler'];

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
  static const Color sectionBg = Color(0xFFF5F6F8);
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

// --- SearchScreen (entry point) -----------------------------------------------

class SearchScreen extends StatefulWidget {
  final SearchModel initial;
  final List<dynamic> allProperties;
  final void Function(SearchModel filter) onApply;

  const SearchScreen({
    super.key,
    required this.initial,
    required this.allProperties,
    required this.onApply,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    // Build a PgFilterModel from the initial SearchModel so pre-existing
    // filter values are correctly pre-populated in the filter widget.
    final init = PgFilterModel(
      city: widget.initial.city,
      locality: widget.initial.locality,
      search: widget.initial.search,
      pgFor: widget.initial.pgFor,
      sharingTypes: widget.initial.sharingTypes,
      preferredTenant: widget.initial.preferredTenant,
      availability: widget.initial.availability,
      parking: widget.initial.parking,
      foodIncluded: widget.initial.foodIncluded,
      rentMin: widget.initial.rentMin,
      rentMax: widget.initial.rentMax,
    );
    return _FiltersWidget(
      initial: init,
      allProperties: widget.allProperties,
      onApply: (filter) {
        widget.onApply(
          SearchModel(
            city: filter.city,
            locality: filter.locality,
            search: filter.search,
            pgFor: filter.pgFor,
            sharingTypes: filter.sharingTypes,
            preferredTenant: filter.preferredTenant,
            availability: filter.availability,
            parking: filter.parking,
            foodIncluded: filter.foodIncluded,
            rentMin: filter.rentMin,
            rentMax: filter.rentMax,
          ),
        );
      },
    );
  }
}

// --- Filters Widget -----------------------------------------------------------

class _FiltersWidget extends StatefulWidget {
  final PgFilterModel initial;
  final List<dynamic> allProperties;
  final void Function(PgFilterModel) onApply;

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

  // -- Top tab ----------------------------------------------------------------
  String _topTab = 'Rent'; // 'Rent' | 'Commercial'
  String _lookingFor = ''; // 'Full House' | 'PG/Hostel' | 'Flatmates' | ''

  // -- Common -----------------------------------------------------------------
  String _city = '';
  RangeValues _rentRange = const RangeValues(0, 100000);
  static const double _maxRent = 100000;

  // -- PG/Hostel state --------------------------------------------------------
  String _pgFor = '';
  String _roomType = '';
  String _preferredTenant = '';
  String _availability = '';
  String _parking = '';
  String _foodIncluded = '';

  // -- Flatmate state ---------------------------------------------------------
  String _fmTenantType = '';
  String _fmRoomType = '';
  String _fmFurnishing = '';
  String _fmPropertyType = '';
  String _fmParking = '';
  String _fmFloor = '';
  String _fmBathroom = '';
  List<String> _fmShowOnly = [];
  bool _fmRemoveSeen = false;

  // -- Full House / Apartment state -------------------------------------------
  List<String> _apBhkTypes = [];
  String _apPreferredTenant = '';
  String _apFurnishing = '';
  String _apAvailability = '';
  String _apParking = '';
  List<String> _apParkingTypes = [];
  bool _apLeaseOnly = false;
  bool _apOwnerHosting = false;

  // -- Commercial state -------------------------------------------------------
  String _cmPropertyType = '';
  String _cmBuildingType = '';
  String _cmPropertyAge = '';
  String _cmFloorRange = '';
  String _cmFurnishing = '';
  String _cmAvailability = '';
  String _cmParking = '';

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

    // Default selections
    _topTab = 'Rent';
    _lookingFor = 'Full House';
    _city = widget.initial.city.isNotEmpty ? widget.initial.city : 'Chennai';

    _rentRange = RangeValues(
      widget.initial.rentMin.clamp(0.0, _maxRent),
      widget.initial.rentMax >= 1000000.0
          ? _maxRent
          : widget.initial.rentMax.clamp(0.0, _maxRent),
    );
    _pgFor = widget.initial.pgFor;
    if (widget.initial.sharingTypes.isNotEmpty)
      _roomType = widget.initial.sharingTypes.first;
    _preferredTenant = widget.initial.preferredTenant;
    _availability = widget.initial.availability;
    _parking = widget.initial.parking;
    if (widget.initial.foodIncluded == true) _foodIncluded = 'Yes';
    if (widget.initial.foodIncluded == false) _foodIncluded = 'No';

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
      _topTab = 'Rent';
      _lookingFor = '';
      _city = '';
      _rentRange = const RangeValues(0, _maxRent);
      _sugg = [];
      _place = null;
      _noResult = false;
      // PG
      _pgFor = '';
      _roomType = '';
      _preferredTenant = '';
      _availability = '';
      _parking = '';
      _foodIncluded = '';
      // Flatmate
      _fmTenantType = '';
      _fmRoomType = '';
      _fmFurnishing = '';
      _fmPropertyType = '';
      _fmParking = '';
      _fmFloor = '';
      _fmBathroom = '';
      _fmShowOnly = [];
      _fmRemoveSeen = false;
      // Apartment
      _apBhkTypes = [];
      _apPreferredTenant = '';
      _apFurnishing = '';
      _apAvailability = '';
      _apParking = '';
      _apParkingTypes = [];
      _apLeaseOnly = false;
      _apOwnerHosting = false;
      // Commercial
      _cmPropertyType = '';
      _cmBuildingType = '';
      _cmPropertyAge = '';
      _cmFloorRange = '';
      _cmFurnishing = '';
      _cmAvailability = '';
      _cmParking = '';
    });
  }

  // -- Save preference --------------------------------------------------------

  Future<void> _savePreference(PgFilterModel filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId");
      if (userId == null) return;
      await http
          .post(
            Uri.parse("https://rentit-backend-omega.vercel.app/preferences"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "userId": userId,
              "city": filter.city.isNotEmpty ? filter.city : null,
              "locality": filter.locality.isNotEmpty ? filter.locality : null,
              "search": filter.search.isNotEmpty ? filter.search : null,
              "pgFor": filter.pgFor.isNotEmpty ? filter.pgFor : null,
              "sharingTypes": filter.sharingTypes.isNotEmpty
                  ? filter.sharingTypes
                  : null,
              "preferredTenant": filter.preferredTenant.isNotEmpty
                  ? filter.preferredTenant
                  : null,
              "availability": filter.availability.isNotEmpty
                  ? filter.availability
                  : null,
              "parking": filter.parking.isNotEmpty ? filter.parking : null,
              "foodIncluded": filter.foodIncluded,
              "rentMin": filter.rentMin,
              "rentMax": filter.rentMax,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("? API ERROR ?? $e");
    }
  }

  // -- Apply filters ----------------------------------------------------------
  Future<void> _applyFilters() async {
    if (_isSaving) return;
    _isSaving = true;

    // -- Search Text Handling ---------------------------------------------
    final typedText = _ctrl.text.trim();

    // If Google suggestion was selected, use geocoded locality.
    // Otherwise, use the manually typed text as locality.
    final loc = (_place?.locality.isNotEmpty ?? false)
        ? _place!.locality.trim()
        : typedText.split(',').first.trim();

    // Always keep free-text search also.
    final search = typedText;

    // -- Rent Range -------------------------------------------------------
    final rMin = _rentRange.start.toInt().toString();
    final rMax = _rentRange.end >= _maxRent
        ? null
        : _rentRange.end.toInt().toString();

    // -- Full House ? /properties ----------------------------------------
    if (_topTab == 'Rent' && _lookingFor == 'Full House') {
      _isSaving = false;

      // Notify parent (e.g. home screen) via callback so it can navigate.
      widget.onApply(
        PgFilterModel(
          city: _city,
          locality: loc,
          search: search,
          rentMin: _rentRange.start.toDouble(),
          rentMax: _rentRange.end >= _maxRent
              ? 1000000.0
              : _rentRange.end.toDouble(),
          preferredTenant: _apPreferredTenant,
          availability: _apAvailability,
          parking: _apParking,
        ),
      );

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/properties',
        arguments: {
          'city': _city,
          'locality': loc,
          'search': search,
          'rentMin': rMin,
          if (rMax != null) 'rentMax': rMax,
          'bhkTypes': _apBhkTypes.join(','),
          'preferredTenant': _apPreferredTenant,
          'furnishing': _apFurnishing,
          'availability': _apAvailability,
          'parking': _apParking,
          'parkingTypes': _apParkingTypes.join(','),
          'leaseOnly': _apLeaseOnly.toString(),
          'ownerHosting': _apOwnerHosting.toString(),
        },
      );
      return;
    }

    // -- PG/Hostel ? /pg-properties --------------------------------------
    if (_topTab == 'Rent' && _lookingFor == 'PG/Hostel') {
      bool? foodDb;
      if (_foodIncluded == 'Yes') foodDb = true;
      if (_foodIncluded == 'No') foodDb = false;

      final filter = PgFilterModel(
        city: _city,
        locality: loc,
        search: search,
        pgFor: _pgFor,
        sharingTypes: _roomType.isNotEmpty ? [_roomType] : [],
        preferredTenant: _preferredTenant,
        availability: _availability,
        parking: _parking,
        foodIncluded: foodDb,
        rentMin: _rentRange.start.toDouble(),
        rentMax: _rentRange.end >= _maxRent
            ? 1000000.0
            : _rentRange.end.toDouble(),
      );

      _savePreference(filter);

      _isSaving = false;
      if (!mounted) return;

      // Notify parent callback so home screen is aware of the filter applied.
      widget.onApply(filter);

      Navigator.pushNamed(
        context,
        '/pg-properties',
        arguments: filter.toQueryParams(),
      );
      return;
    }

    // -- Flatmates ? /flatmates ------------------------------------------
    if (_topTab == 'Rent' && _lookingFor == 'Flatmates') {
      _isSaving = false;

      widget.onApply(
        PgFilterModel(
          city: _city,
          locality: loc,
          search: search,
          rentMin: _rentRange.start.toDouble(),
          rentMax: _rentRange.end >= _maxRent
              ? 1000000.0
              : _rentRange.end.toDouble(),
        ),
      );

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/flatmates',
        arguments: {
          'city': _city,
          'locality': loc,
          'search': search,
          'rentMin': rMin,
          if (rMax != null) 'rentMax': rMax,
          'tenantType': _fmTenantType,
          'roomType': _fmRoomType,
          'furnishing': _fmFurnishing,
          'propertyType': _fmPropertyType,
          'parking': _fmParking,
          'floor': _fmFloor,
          'bathroom': _fmBathroom,
          'showOnly': _fmShowOnly.join(','),
          'removeSeenProperties': _fmRemoveSeen.toString(),
        },
      );
      return;
    }

    // -- Commercial ? /commercial-properties -----------------------------
    if (_topTab == 'Commercial') {
      _isSaving = false;

      widget.onApply(
        PgFilterModel(
          city: _city,
          locality: loc,
          search: search,
          rentMin: _rentRange.start.toDouble(),
          rentMax: _rentRange.end >= _maxRent
              ? 1000000.0
              : _rentRange.end.toDouble(),
        ),
      );

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/commercial-properties',
        arguments: {
          'city': _city,
          'locality': loc,
          'search': search,
          'rentMin': rMin,
          if (rMax != null) 'rentMax': rMax,
          'commercialPropertyType': _cmPropertyType,
          'buildingType': _cmBuildingType,
          'propertyAge': _cmPropertyAge,
          'floorRange': _cmFloorRange,
          'furnishing': _cmFurnishing,
          'availability': _cmAvailability,
          'parking': _cmParking,
        },
      );
      return;
    }

    // -- Default Fallback ? /properties ----------------------------------
    _isSaving = false;

    widget.onApply(
      PgFilterModel(
        city: _city,
        locality: loc,
        search: search,
        rentMin: _rentRange.start.toDouble(),
        rentMax: _rentRange.end >= _maxRent
            ? 1000000.0
            : _rentRange.end.toDouble(),
      ),
    );

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/properties',
      arguments: {
        'city': _city,
        'locality': loc,
        'search': search,
        'rentMin': rMin,
        if (rMax != null) 'rentMax': rMax,
      },
    );
  }
  // -- Toggle list helper -----------------------------------------------------

  List<String> _toggle(List<String> list, String val) {
    final c = List<String>.from(list);
    c.contains(val) ? c.remove(val) : c.add(val);
    return c;
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
          'RENTIT',
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
                  // -- Rent / Commercial Tabs -----------------------------
                  _topTabBar(),
                  const SizedBox(height: 20),

                  // -- City ----------------------------------------------
                  _cityDropdownField(),
                  const SizedBox(height: 20),

                  // -- Locality Search + inline suggestions ---------------
                  _section(
                    'Search Locality / Landmark',
                    _localitySearchBlock(),
                  ),
                  const SizedBox(height: 20),

                  // -- Looking For (Rent only) ----------------------------
                  if (_topTab == 'Rent') ...[
                    _section('Looking For', _lookingForChips()),
                    const SizedBox(height: 20),
                  ],

                  // -- Rent Range -----------------------------------------
                  _section('Rent Range', _rentRangeSlider()),
                  const SizedBox(height: 20),

                  // ------------------------------------------------------
                  // FULL HOUSE / APARTMENT FILTERS
                  // ------------------------------------------------------
                  if (_topTab == 'Rent' && _lookingFor == 'Full House') ...[
                    _section('BHK Type', _apBhkChips()),
                    const SizedBox(height: 20),

                    _section('Preferred Tenant', _apTenantChips()),
                    const SizedBox(height: 20),

                    _section('Furnishing', _apFurnishingChips()),
                    const SizedBox(height: 20),

                    _section('Availability', _apAvailabilityRadio()),
                    const SizedBox(height: 20),

                    _section('Parking', _apParkingSection()),
                    const SizedBox(height: 20),

                    _apToggleCards(),
                    const SizedBox(height: 20),
                  ],

                  // ------------------------------------------------------
                  // PG/HOSTEL FILTERS
                  // ------------------------------------------------------
                  if (_topTab == 'Rent' && _lookingFor == 'PG/Hostel') ...[
                    _section('PG For', _pgForChips()),
                    const SizedBox(height: 20),

                    _section('Room Type (Sharing)', _pgRoomTypeChips()),
                    const SizedBox(height: 20),

                    _section('Preferred Tenant', _preferredTenantChips()),
                    const SizedBox(height: 20),

                    _section('Availability', _pgAvailabilityChips()),
                    const SizedBox(height: 20),

                    _parkingAndFoodRow(),
                  ],

                  // ------------------------------------------------------
                  // FLATMATE FILTERS
                  // ------------------------------------------------------
                  if (_topTab == 'Rent' && _lookingFor == 'Flatmates') ...[
                    _section('Tenant Type', _fmTenantTypeChips()),
                    const SizedBox(height: 20),

                    _section('Room Type', _fmRoomTypeChips()),
                    const SizedBox(height: 20),

                    _section('Furnishing', _fmFurnishingChips()),
                    const SizedBox(height: 20),

                    _section('Apartment Type', _fmPropertyTypeChips()),
                    const SizedBox(height: 20),

                    _section('Show Only', _fmShowOnlyChips()),
                    const SizedBox(height: 20),

                    _section('Remove Seen Properties', _fmRemoveSeenChip()),
                    const SizedBox(height: 20),

                    _section('Floors', _fmFloorChips()),
                    const SizedBox(height: 20),

                    _section('Parking', _fmParkingChips()),
                    const SizedBox(height: 20),

                    _section('Bathroom', _fmBathroomChips()),
                    const SizedBox(height: 20),
                  ],

                  // ------------------------------------------------------
                  // COMMERCIAL FILTERS
                  // ------------------------------------------------------
                  if (_topTab == 'Commercial') ...[
                    _section('Property Type', _cmPropertyTypeChips()),
                    const SizedBox(height: 20),

                    _section('Building Type', _cmBuildingTypeChips()),
                    const SizedBox(height: 20),

                    _section('Floor', _cmFloorRangeChips()),
                    const SizedBox(height: 20),

                    _section('Furnishing', _cmFurnishingChips()),
                    const SizedBox(height: 20),

                    _section('Availability', _cmAvailabilityChips()),
                    const SizedBox(height: 20),

                    _section('Parking', _cmParkingChips()),
                  ],
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

  // --- Top Tab Bar ----------------------------------------------------------

  Widget _topTabBar() {
    const tabs = ['Rent', 'Commercial'];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _T.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Row(
        children: tabs.map((tab) {
          final sel = _topTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _topTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: sel ? _T.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : _T.muted2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Looking For chips ----------------------------------------------------

  Widget _lookingForChips() {
    final opts = <Map<String, dynamic>>[
      {'label': 'Full House', 'icon': Icons.home_outlined},
      {'label': 'PG/Hostel', 'icon': Icons.apartment_outlined},
      {'label': 'Flatmates', 'icon': Icons.people_outline},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final lbl = o['label'] as String;
        final icon = o['icon'] as IconData;
        final sel = _lookingFor == lbl;
        return GestureDetector(
          onTap: () => setState(() {
            _lookingFor = sel ? '' : lbl;
            if (_lookingFor != 'Full House') {
              _apBhkTypes = [];
              _apPreferredTenant = '';
              _apFurnishing = '';
              _apAvailability = '';
              _apParking = '';
              _apParkingTypes = [];
              _apLeaseOnly = false;
              _apOwnerHosting = false;
            }
            if (_lookingFor != 'PG/Hostel') {
              _pgFor = '';
              _roomType = '';
              _preferredTenant = '';
              _availability = '';
              _parking = '';
              _foodIncluded = '';
            }
            if (_lookingFor != 'Flatmates') {
              _fmTenantType = '';
              _fmRoomType = '';
              _fmFurnishing = '';
              _fmPropertyType = '';
              _fmParking = '';
              _fmFloor = '';
              _fmBathroom = '';
              _fmShowOnly = [];
              _fmRemoveSeen = false;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                Icon(icon, size: 16, color: sel ? Colors.white : _T.muted2),
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
  // This renders the text field and the dropdown list as a single Column
  // inside the scroll view � exactly like the reference screenshot.
  // No overlay, no LayerLink � just plain inline widgets.

  Widget _localitySearchBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- Search input field ------------------------------------------
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

        // -- Inline suggestions list -------------------------------------
        // Shown only when there are suggestions. Renders directly below the
        // field, pushing the rest of the page down � identical to the image.
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

                  // Determine icon: buildings/landmarks get a different icon,
                  // plain localities get the standard location pin � matching
                  // the reference screenshot (location_on vs store / domain).
                  final IconData pinIcon;
                  final secondaryLower = p.secondaryText.toLowerCase();
                  if (secondaryLower.contains('mall') ||
                      secondaryLower.contains('hospital') ||
                      secondaryLower.contains('school') ||
                      secondaryLower.contains('college') ||
                      p.mainText.toLowerCase().contains('square') ||
                      p.mainText.toLowerCase().contains('plaza') ||
                      p.mainText.toLowerCase().contains('complex')) {
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
                              // Pin icon
                              Icon(
                                pinIcon,
                                size: 18,
                                color: const Color(0xFF9AA0A6),
                              ),
                              const SizedBox(width: 12),

                              // Text column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Main place name � bold, dark
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

                                    // Secondary address � grey, smaller
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

                        // Divider between items (not after last)
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

        // -- "No results" hint -------------------------------------------
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
  // COMMERCIAL FILTER WIDGETS
  // --------------------------------------------------------------------------

  Widget _cmPropertyTypeChips() {
    final types = <Map<String, dynamic>>[
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
        final sel = _cmPropertyType == lbl;
        return GestureDetector(
          onTap: () => setState(() => _cmPropertyType = sel ? '' : lbl),
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

  Widget _cmBuildingTypeChips() {
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
        final sel = _cmBuildingType == lbl;
        return _filterChip(
          label: lbl,
          selected: sel,
          onTap: () => setState(() => _cmBuildingType = sel ? '' : lbl),
        );
      }).toList(),
    );
  }

  Widget _cmFloorRangeChips() {
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
        final sel = _cmFloorRange == r;
        return _filterChip(
          label: r,
          selected: sel,
          onTap: () => setState(() => _cmFloorRange = sel ? '' : r),
        );
      }).toList(),
    );
  }

  Widget _cmFurnishingChips() {
    const opts = ['Fully Furnished', 'Semi Furnished', 'Unfurnished'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final sel = _cmFurnishing == o;
        return _filterChip(
          label: o,
          selected: sel,
          onTap: () => setState(() => _cmFurnishing = sel ? '' : o),
        );
      }).toList(),
    );
  }

  Widget _cmAvailabilityChips() {
    const opts = ['Immediately', 'Within 15 days', 'Within 30 days'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final sel = _cmAvailability == o;
        return _filterChip(
          label: o,
          selected: sel,
          onTap: () => setState(() => _cmAvailability = sel ? '' : o),
        );
      }).toList(),
    );
  }

  Widget _cmParkingChips() {
    const opts = ['Public', 'Reserved'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final sel = _cmParking == o;
        return _filterChip(
          label: o,
          selected: sel,
          onTap: () => setState(() => _cmParking = sel ? '' : o),
        );
      }).toList(),
    );
  }

  // --------------------------------------------------------------------------
  // FULL HOUSE / APARTMENT FILTER WIDGETS
  // --------------------------------------------------------------------------

  Widget _apBhkChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: _kBhkTypes.map((bhk) {
      final sel = _apBhkTypes.contains(bhk);
      return GestureDetector(
        onTap: () => setState(() => _apBhkTypes = _toggle(_apBhkTypes, bhk)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _T.primary : _T.chipBg,
            border: Border.all(color: sel ? _T.primary : _T.border, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            bhk,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sel ? Colors.white : _T.muted2,
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _apTenantChips() {
    final w = (MediaQuery.of(context).size.width - 32) / 2;
    return Wrap(
      children: _kTenants.map((item) {
        final sel = _apPreferredTenant == item;
        return SizedBox(
          width: w,
          child: CheckboxListTile(
            value: sel,
            activeColor: _T.primary,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              item,
              style: const TextStyle(fontSize: 13, color: _T.muted2),
            ),
            onChanged: (_) =>
                setState(() => _apPreferredTenant = sel ? '' : item),
          ),
        );
      }).toList(),
    );
  }

  Widget _apFurnishingChips() {
    final w = (MediaQuery.of(context).size.width - 32) / 3;
    return Wrap(
      children: _kFurnishing.map((item) {
        final sel = _apFurnishing == item;
        return SizedBox(
          width: w,
          child: CheckboxListTile(
            value: sel,
            activeColor: _T.primary,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              item,
              style: const TextStyle(fontSize: 13, color: _T.muted2),
            ),
            onChanged: (_) => setState(() => _apFurnishing = sel ? '' : item),
          ),
        );
      }).toList(),
    );
  }

  Widget _apAvailabilityRadio() {
    final w = (MediaQuery.of(context).size.width - 32) / 2;
    return Wrap(
      children: _kAvailability.map((item) {
        final sel = _apAvailability == item;
        return SizedBox(
          width: w,
          child: RadioListTile<String>(
            value: item,
            groupValue: _apAvailability,
            activeColor: _T.primary,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              item,
              style: const TextStyle(fontSize: 13, color: _T.muted2),
            ),
            onChanged: (v) =>
                setState(() => _apAvailability = sel ? '' : (v ?? '')),
          ),
        );
      }).toList(),
    );
  }

  Widget _apParkingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: ['Yes', 'No'].map((opt) {
          final sel = _apParking == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() {
                _apParking = sel ? '' : opt;
                if (opt == 'No') _apParkingTypes = [];
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: sel ? _T.primary : Colors.white,
                  border: Border.all(
                    color: sel ? _T.primary : _T.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Parking $opt',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _T.muted2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      if (_apParking == 'Yes') ...[
        const SizedBox(height: 12),
        _apParkingTypeChips(),
      ],
    ],
  );

  Widget _apParkingTypeChips() {
    final w = (MediaQuery.of(context).size.width - 32) / 2;
    return Wrap(
      children: _kParkingTypes.map((item) {
        final sel = _apParkingTypes.contains(item);
        return SizedBox(
          width: w,
          child: CheckboxListTile(
            value: sel,
            activeColor: _T.primary,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              item,
              style: const TextStyle(fontSize: 13, color: _T.muted2),
            ),
            onChanged: (_) => setState(
              () => _apParkingTypes = _toggle(_apParkingTypes, item),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _apToggleCards() => Column(
    children: [
      _apSwitchCard(
        title: 'Owner Hosting a Visit',
        subtitle: 'Properties with visits scheduled within next 2 days',
        badge: 'New',
        value: _apOwnerHosting,
        onChanged: (v) => setState(() => _apOwnerHosting = v),
      ),
      const SizedBox(height: 10),
      _apSwitchCard(
        title: 'Show Only Lease Properties',
        value: _apLeaseOnly,
        onChanged: (v) => setState(() => _apLeaseOnly = v),
      ),
    ],
  );

  Widget _apSwitchCard({
    required String title,
    String? subtitle,
    String? badge,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _T.sectionBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _T.border),
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
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _T.text,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _T.muted),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _T.primary,
          activeTrackColor: _T.primary.withOpacity(0.3),
        ),
      ],
    ),
  );

  // --------------------------------------------------------------------------
  // PG/HOSTEL FILTER WIDGETS
  // --------------------------------------------------------------------------

  Widget _pgForChips() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Filters by who the PG is listed for (Boys / Girls / Anyone).',
        style: TextStyle(fontSize: 11, color: _T.muted),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _pgForChip('Boys', Icons.male_rounded),
          _pgForChip('Girls', Icons.female_rounded),
          _pgForChip('Anyone', Icons.people_outline),
        ],
      ),
    ],
  );

  Widget _pgForChip(String label, IconData icon) {
    final sel = _pgFor == label;
    return GestureDetector(
      onTap: () => setState(() => _pgFor = sel ? '' : label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _T.primary : _T.chipBg,
          border: Border.all(color: sel ? _T.primary : _T.border, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? Colors.white : _T.muted2),
            const SizedBox(width: 6),
            Text(
              label,
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
  }

  Widget _pgRoomTypeChips() {
    final opts = <Map<String, dynamic>>[
      {
        'label': 'Single room',
        'db': 'Single room',
        'icon': Icons.person_outline,
      },
      {
        'label': 'Double sharing',
        'db': 'Double sharing',
        'icon': Icons.people_outline,
      },
      {'label': '3 Sharing', 'db': '3 Sharing', 'icon': Icons.group_outlined},
      {
        'label': '4+ Sharing',
        'db': '4+ Sharing',
        'icon': Icons.groups_outlined,
      },
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opts.map((o) {
        final dbVal = o['db'] as String;
        final lbl = o['label'] as String;
        final icon = o['icon'] as IconData;
        final sel = _roomType == dbVal;
        return GestureDetector(
          onTap: () => setState(() => _roomType = sel ? '' : dbVal),
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
                Icon(icon, size: 16, color: sel ? Colors.white : _T.muted2),
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

  Widget _preferredTenantChips() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Filters by preferred guests (Students / Working Professionals)',
        style: TextStyle(fontSize: 11, color: _T.muted),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: ['Students', 'Working Professionals', 'Anyone'].map((lbl) {
          final sel = _preferredTenant == lbl;
          return _filterChip(
            label: lbl,
            selected: sel,
            onTap: () => setState(() => _preferredTenant = sel ? '' : lbl),
          );
        }).toList(),
      ),
    ],
  );

  Widget _pgAvailabilityChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Immediately', 'Within 15 days', 'Within 30 days'].map((lbl) {
      final sel = _availability == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _availability = sel ? '' : lbl),
      );
    }).toList(),
  );

  Widget _parkingAndFoodRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parking',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _T.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Car / Bike / Both',
              style: TextStyle(fontSize: 11, color: _T.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Yes', 'No'].map((lbl) {
                final sel = _parking == lbl;
                return _filterChip(
                  label: lbl,
                  selected: sel,
                  onTap: () => setState(() => _parking = sel ? '' : lbl),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Food Included',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _T.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lunch / Dinner / Both',
              style: TextStyle(fontSize: 11, color: _T.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Yes', 'No'].map((lbl) {
                final sel = _foodIncluded == lbl;
                return _filterChip(
                  label: lbl,
                  selected: sel,
                  onTap: () => setState(() => _foodIncluded = sel ? '' : lbl),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ],
  );

  // --------------------------------------------------------------------------
  // FLATMATE FILTER WIDGETS
  // --------------------------------------------------------------------------

  Widget _fmTenantTypeChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _fmIconChip(
        label: 'Male',
        icon: Icons.male_rounded,
        value: _fmTenantType,
        onTap: (v) => setState(() => _fmTenantType = v),
      ),
      _fmIconChip(
        label: 'Female',
        icon: Icons.female_rounded,
        value: _fmTenantType,
        onTap: (v) => setState(() => _fmTenantType = v),
      ),
    ],
  );

  Widget _fmRoomTypeChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _fmIconChip(
        label: 'Single room',
        icon: Icons.person_outline,
        value: _fmRoomType,
        onTap: (v) => setState(() => _fmRoomType = v),
      ),
      _fmIconChip(
        label: 'Shared Room',
        icon: Icons.people_outline,
        value: _fmRoomType,
        onTap: (v) => setState(() => _fmRoomType = v),
      ),
    ],
  );

  Widget _fmFurnishingChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Fully Furnished', 'Semi Furnished', 'Unfurnished'].map((lbl) {
      final sel = _fmFurnishing == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _fmFurnishing = sel ? '' : lbl),
      );
    }).toList(),
  );

  Widget _fmPropertyTypeChips() {
    const types = [
      'Apartment',
      'Independent House/Villa',
      'Gated Community Villa',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((type) {
        final sel = _fmPropertyType == type;
        return _filterChip(
          label: type,
          selected: sel,
          onTap: () => setState(() => _fmPropertyType = sel ? '' : type),
        );
      }).toList(),
    );
  }

  Widget _fmShowOnlyChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Non Veg Allowed', 'With Photos', 'Gym'].map((lbl) {
      final sel = _fmShowOnly.contains(lbl);
      return GestureDetector(
        onTap: () => setState(() {
          sel ? _fmShowOnly.remove(lbl) : _fmShowOnly.add(lbl);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _T.primary : _T.chipBg,
            border: Border.all(color: sel ? _T.primary : _T.border, width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sel) ...[
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
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

  Widget _fmRemoveSeenChip() => GestureDetector(
    onTap: () => setState(() => _fmRemoveSeen = !_fmRemoveSeen),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _fmRemoveSeen ? _T.primary : _T.chipBg,
        border: Border.all(
          color: _fmRemoveSeen ? _T.primary : _T.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _fmRemoveSeen
                ? Icons.visibility_off_rounded
                : Icons.visibility_outlined,
            size: 15,
            color: _fmRemoveSeen ? Colors.white : _T.muted2,
          ),
          const SizedBox(width: 6),
          Text(
            'Remove Seen Properties',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _fmRemoveSeen ? Colors.white : _T.muted2,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _fmFloorChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['Ground', '1 to 3', '4 to 6', '7 to 9', '10 & above'].map((lbl) {
      final sel = _fmFloor == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _fmFloor = sel ? '' : lbl),
      );
    }).toList(),
  );

  Widget _fmParkingChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['2 Wheeler', '4 Wheeler'].map((lbl) {
      final sel = _fmParking == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _fmParking = sel ? '' : lbl),
      );
    }).toList(),
  );

  Widget _fmBathroomChips() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: ['1 or more', '2 or more', '3 or more'].map((lbl) {
      final sel = _fmBathroom == lbl;
      return _filterChip(
        label: lbl,
        selected: sel,
        onTap: () => setState(() => _fmBathroom = sel ? '' : lbl),
      );
    }).toList(),
  );

  Widget _fmIconChip({
    required String label,
    required IconData icon,
    required String value,
    required void Function(String) onTap,
  }) {
    final sel = value == label;
    return GestureDetector(
      onTap: () => onTap(sel ? '' : label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _T.primary : _T.chipBg,
          border: Border.all(color: sel ? _T.primary : _T.border, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? Colors.white : _T.muted2),
            const SizedBox(width: 6),
            Text(
              label,
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
  }

  // --- Generic filter chip --------------------------------------------------

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'SEARCH PROPERTIES',
          style: TextStyle(
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
