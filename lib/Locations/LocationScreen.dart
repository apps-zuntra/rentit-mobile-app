// LocationScreen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/main/filter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/main/ViewAllpropertys.dart';
import 'package:rentit/main/g_details_model.dart';

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

// --- LocationScreen (Filters) -------------------------------------------------

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: const SafeArea(child: _FiltersWidget()),
    );
  }
}

// --- Filters Widget -----------------------------------------------------------

class _FiltersWidget extends StatefulWidget {
  const _FiltersWidget();
  @override
  State<_FiltersWidget> createState() => _FiltersWidgetState();
}

class _FiltersWidgetState extends State<_FiltersWidget> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _link = LayerLink();

  // -- Filter state -----------------------------------------------------------
  // City selection
  String _city = 'Chennai';

  // Search type toggle
  String _searchType = 'Locality'; // 'Locality' | 'Metro'

  // DB: preferredTenant stores ["Boys"], ["Girls"], ["Anyone"]
  // UI labels ? DB values mapping:
  //   'Boys'  ? 'Boys'
  //   'Girls' ? 'Girls'
  //   'Anyone'? 'Anyone'
  String _pgFor = ''; // '' | 'Boys' | 'Girls' | 'Anyone'

  // DB: roomType[].sharing stores e.g. "Single room", "Double sharing", "3 Sharing", "4+ Sharing"
  // We store exactly the DB sharing value:
  String _roomType =
      ''; // '' | 'Single room' | 'Double sharing' | '3 Sharing' | '4+ Sharing'

  // DB: preferredGuests stores ["Students"], ["Working Professionals"], ["Anyone"]
  String _preferredTenant =
      ''; // '' | 'Students' | 'Working Professionals' | 'Anyone'

  // DB: availableFrom (date field) � we pass human label to filter_model which converts
  String _availability =
      ''; // '' | 'Immediately' | 'Within 15 days' | 'Within 30 days'

  // DB: parking field � values: null | 'Car' | 'Bike' | 'Both' | 'None'
  // UI: 'Yes' means any parking value that is not null/'None', 'No' means null or 'None'
  String _parking = ''; // '' | 'Yes' | 'No'

  // DB: foodIncluded field � boolean true/false
  String _foodIncluded = ''; // '' | 'Yes' | 'No'

  // Rent range � DB: roomType[].rent (numeric)
  RangeValues _rentRange = const RangeValues(0, 100000);
  static const double _maxRent = 100000;

  // -- Locality search state --------------------------------------------------
  List<_Prediction> _sugg = [];
  _PlaceDetails? _place;
  bool _loading = false;
  bool _noResult = false;

  // -- Live count state -------------------------------------------------------
  List<dynamic> _allPgProperties = [];
  bool _fetchingProps = true;

  Timer? _debounce;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
    _city = 'Chennai';
    _focus.addListener(_onFocus);
    _fetchPgProperties();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchPgProperties() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('https://rentit-backend-omega.vercel.appproperty/all'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as List<dynamic>;
        _allPgProperties = raw
            .whereType<Map<String, dynamic>>()
            .where((m) => m['id'] != null)
            .map((m) => PGDetailsModel.fromJson(m))
            .where((p) => p.isPG)
            .map((p) => p.toJson())
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _fetchingProps = false);
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
      _searchType = 'Locality';
      _pgFor = '';
      _roomType = '';
      _preferredTenant = '';
      _availability = '';
      _parking = '';
      _foodIncluded = '';
      _rentRange = const RangeValues(0, _maxRent);
      _sugg = [];
      _place = null;
      _noResult = false;
    });
  }

  // -- Apply filters ? build PgFilterModel with correct DB field values --------
  Future<void> _savePreference(PgFilterModel filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getInt("userId");

      print("?? USER ID ?? $userId");

      if (userId == null) {
        print("? USER NOT LOGGED IN");
        return;
      }

      final res = await http.post(
        Uri.parse("/preferences"),
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
      );

      print("? STATUS ?? ${res.statusCode}");
      print("?? BODY ?? ${res.body}");
    } catch (e) {
      print("? API ERROR ?? $e");
    }
  }

  Future<void> _applyFilters() async {
    if (_isSaving) return; // ?? STOP MULTI CLICK

    _isSaving = true;

    print("?? APPLY CLICKED");

    _dropOverlay();

    bool? foodDb;
    if (_foodIncluded == 'Yes') foodDb = true;
    if (_foodIncluded == 'No') foodDb = false;

    final filter = PgFilterModel(
      city: _city,
      locality: _place?.locality ?? '',
      search: _place == null ? _ctrl.text.trim() : '',
      pgFor: _pgFor,
      sharingTypes: _roomType.isNotEmpty ? [_roomType] : [],
      preferredTenant: _preferredTenant,
      availability: _availability,
      parking: _parking,
      foodIncluded: foodDb,
      rentMin: _rentRange.start.toDouble(),
      rentMax: _rentRange.end >= _maxRent ? 0.0 : _rentRange.end.toDouble(),
    );

    await _savePreference(filter);

    _isSaving = false;

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/properties',
      arguments: filter.toQueryParams(),
    );
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

  // ------------------------------- BUILD ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _topBar(),
        const Divider(height: 1, color: _T.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cityDropdownField(),
                const SizedBox(height: 20),
                _landmarkSearchField(),
                const SizedBox(height: 20),
                _section('Rent Range', _rentRangeSlider()),
                const SizedBox(height: 20),
                // PG For ? filters by preferredTenant (Boys/Girls/Anyone)
                _section('PG For', _pgForChips()),
                const SizedBox(height: 20),
                _section('Room Type (Sharing)', _roomTypeChips()),
                const SizedBox(height: 20),
                // Preferred Tenant ? filters by preferredGuests (Students/Working Professionals/Anyone)
                _section('Preferred Tenant', _preferredTenantChips()),
                const SizedBox(height: 20),
                _section('Availability', _availabilityChips()),
                const SizedBox(height: 20),
                _parkingAndFoodRow(),
              ],
            ),
          ),
        ),
        _applyBar(),
      ],
    );
  }

  // -- Top Bar ----------------------------------------------------------------

  Widget _topBar() => Container(
    height: 56,
    color: _T.bg,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, size: 22, color: _T.text),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Filters',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _T.text,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22, color: _T.text),
          onPressed: _resetAll,
        ),
      ],
    ),
  );

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

  // -- City dropdown field ----------------------------------------------------

  Widget _cityDropdownField() => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: _T.bg,
      border: Border.all(color: _T.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_city_outlined, size: 18, color: _T.muted),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _city.isEmpty ? null : _city,
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
              isExpanded: true,
              onChanged: (v) {
                setState(() {
                  _city = v ?? '';
                  _place = null;
                });
                _clearSearch();
              },
              items: _kCityCentres.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
            ),
          ),
        ),
      ],
    ),
  );

  // -- Search Type toggle -----------------------------------------------------

  // Widget _searchTypeToggle() => Container(
  //   height: 44,
  //   decoration: BoxDecoration(
  //     color: _T.chipBg,
  //     borderRadius: BorderRadius.circular(10),
  //   ),
  //   child: Row(
  //     children: [
  //       _toggleTab(
  //         icon: Icons.location_on_rounded,
  //         label: 'Locality Search',
  //         selected: _searchType == 'Locality',
  //         onTap: () => setState(() => _searchType = 'Locality'),
  //       ),

  //     ],
  //   ),
  // );

  Widget _toggleTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? _T.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? _T.text : _T.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _T.text : _T.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // -- Landmark search field --------------------------------------------------

  Widget _landmarkSearchField() {
    return CompositedTransformTarget(
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
            else ...[
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearch,
                  child: const Icon(Icons.close, size: 16, color: _T.muted),
                )
              else
                const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: _T.muted,
                ),
            ],
          ],
        ),
      ),
    );
  }

  // -- Suggestions dropdown ---------------------------------------------------

  Widget _dropdown() {
    if (_sugg.isEmpty) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.border),
        ),
        child: const Text(
          "No results found",
          style: TextStyle(fontSize: 13, color: _T.muted),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: _sugg.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: _T.border.withOpacity(0.6),
            indent: 50,
            endIndent: 12,
          ),
          itemBuilder: (_, i) {
            final p = _sugg[i];

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pick(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      /// ?? ICON BOX
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _T.primaryBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: _T.accent,
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// ?? TEXTS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.mainText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _T.text,
                              ),
                            ),
                            if (p.secondaryText.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                p.secondaryText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _T.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      /// ? ICON
                      const Icon(
                        Icons.north_west_rounded,
                        size: 14,
                        color: _T.muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // -- Rent Range Slider ------------------------------------------------------

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

  // -- PG For chips -----------------------------------------------------------
  // Maps to DB field: preferredTenant � values: ["Boys"], ["Girls"], ["Anyone"]

  Widget _pgForChips() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Filters by who the PG is listed for (Boys / Girls / Anyone)...',
        style: TextStyle(fontSize: 11, color: _T.muted),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          // UI: 'Boys'   ? DB preferredTenant contains 'Boys'
          // UI: 'Girls'  ? DB preferredTenant contains 'Girls'
          // UI: 'Anyone' ? DB preferredTenant contains 'Anyone'
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

  // -- Room Type chips --------------------------------------------------------
  // Maps to DB field: roomType[].sharing
  // IMPORTANT: values must match DB exactly (case-sensitive)

  Widget _roomTypeChips() {
    // DB sharing values (from your schema screenshots):
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
      {
        'label': 'Three Sharing',
        'db': 'Three Sharing',
        'icon': Icons.group_outlined,
      },
      {'label': '4 Sharing', 'db': '4 Sharing', 'icon': Icons.groups_outlined},
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

  // -- Preferred Tenant chips -------------------------------------------------
  // Maps to DB field: preferredGuests � values: ["Students"], ["Working Professionals"], ["Anyone"]

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

  // -- Availability chips -----------------------------------------------------

  Widget _availabilityChips() => Wrap(
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

  // -- Parking + Food Included ------------------------------------------------
  // DB parking field: 'Car' | 'Bike' | 'Both' | null
  // DB foodIncluded:  true | false (boolean)

  Widget _parkingAndFoodRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parkin..g',
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

  // -- Apply Filters bottom bar -----------------------------------------------
  bool _isSaving = false;

  int get _liveCount {
    if (_fetchingProps) return 0;
    bool? foodDb;
    if (_foodIncluded == 'Yes') foodDb = true;
    if (_foodIncluded == 'No') foodDb = false;

    final filter = PgFilterModel(
      city: _city,
      locality: _place?.locality ?? '',
      search: _place == null ? _ctrl.text.trim() : '',
      pgFor: _pgFor,
      sharingTypes: _roomType.isNotEmpty ? [_roomType] : [],
      preferredTenant: _preferredTenant,
      availability: _availability,
      parking: _parking,
      foodIncluded: foodDb,
      rentMin: _rentRange.start.toDouble(),
      rentMax: _rentRange.end >= _maxRent ? 0.0 : _rentRange.end.toDouble(),
    );
    return applyFilters(_allPgProperties, filter).length;
  }

  Widget _applyBar() => Container(
    color: _T.bg,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _applyFilters, // ? guaranteed click
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _fetchingProps
              ? 'APPLY FILTERS'
              : 'APPLY FILTERS ($_liveCount RESULTS)',
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
