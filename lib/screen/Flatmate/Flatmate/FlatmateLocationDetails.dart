// FlatmateLocationDetails.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/providers/FlatmateDraftProvider.dart';
import 'package:rentit/screen/Flatmate/Flatmate/FlatmatePricedetails.dart';
import 'package:geolocator/geolocator.dart';

// -----------------------------------------------------------------------------
// FULL-SCREEN MAP PICKER MODAL
// -----------------------------------------------------------------------------
class FullScreenMapPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String mapsApiKey;
  final String selectedCity;

  const FullScreenMapPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.mapsApiKey,
    required this.selectedCity,
  });

  @override
  State<FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<FullScreenMapPicker>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Timer? _debounce;

  double? latitude;
  double? longitude;

  bool mapMoving = false;
  bool mapReady = false;
  bool locationLoading = false;
  bool confirming = false;

  String resolvedAddress = "";
  String resolvedLocality = "";
  String resolvedStreet = "";
  final TextEditingController localityCtrl = TextEditingController();
  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _searchDebounce;

  late AnimationController _pinAnimController;
  late Animation<double> _pinBounce;

  @override
  void initState() {
    super.initState();
    latitude = widget.initialLat;
    longitude = widget.initialLng;

    _pinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinBounce = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _pinAnimController, curve: Curves.easeOut),
    );
    localityCtrl.clear(); // ? FORCE EMPTY

    // ? DELETE this line
    // Future.microtask(() => _reverseGeocode(latitude!, longitude!));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _pinAnimController.dispose();
    super.dispose();
  }

  final Map<String, LatLngBounds> cityBounds = {
    "Chennai": LatLngBounds(
      southwest: LatLng(12.8, 80.0),
      northeast: LatLng(13.3, 80.3),
    ),
    "Coimbatore": LatLngBounds(
      southwest: LatLng(10.9, 76.8),
      northeast: LatLng(11.1, 77.1),
    ),
    "Bengaluru": LatLngBounds(
      southwest: LatLng(12.8, 77.4),
      northeast: LatLng(13.1, 77.8),
    ),
    "Hyderabad": LatLngBounds(
      southwest: LatLng(17.2, 78.2),
      northeast: LatLng(17.6, 78.6),
    ),
  };

  // -- Reverse Geocode --------------------------------------------------------
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${widget.mapsApiKey}";

      final res = await http.get(Uri.parse(url));

      /// ? DEBUG HERE
      print("STATUS: ${res.statusCode}");
      print("BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        /// ? CHECK STATUS
        if (data["status"] != "OK") {
          print("GEOCODE ERROR: ${data["status"]}");
          return;
        }

        if (data["results"] != null && data["results"].isNotEmpty) {
          final result = data["results"][0];
          final formattedAddress = result["formatted_address"] ?? "";
          final components = result["address_components"] as List;

          String locality = "";
          String area = "";
          String street = "";

          for (var comp in components) {
            final types = List<String>.from(comp["types"]);

            if (types.contains("sublocality") ||
                types.contains("sublocality_level_1")) {
              area = comp["long_name"];
            }

            if (types.contains("locality")) {
              locality = comp["long_name"];
            }

            if (types.contains("route")) {
              street = comp["long_name"];
            }
          }

          final finalLocality = area.isNotEmpty
              ? area
              : (locality.isNotEmpty
                    ? locality
                    : formattedAddress.split(",").first);

          if (mounted) {
            setState(() {
              resolvedAddress = formattedAddress;
              resolvedLocality = formattedAddress;
              resolvedStreet = street;
              _searchCtrl.text = formattedAddress;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Reverse geocode error: $e");
    }
  }

  // -- Place Autocomplete Search -----------------------------------------------
  Future<void> _searchPlaces(String query) async {
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _searching = true);

    try {
      final url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json"
          "?input=${Uri.encodeComponent(query)}"
          "&key=${widget.mapsApiKey}"
          "&locationbias=circle:50000@${latitude},${longitude}"
          "&types=establishment";

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final predictions = data["predictions"] as List? ?? [];
        setState(() {
          _suggestions = predictions
              .where((p) {
                final desc = (p["description"] as String).toLowerCase();
                return desc.contains("apartment") ||
                    desc.contains("residency") ||
                    desc.contains("tower") ||
                    desc.contains("villa") ||
                    desc.contains("nagar") ||
                    desc.contains("layout");
              })
              .take(5)
              .map<Map<String, dynamic>>(
                (p) => {
                  "place_id": p["place_id"],
                  "description": p["description"],
                  "main": p["structured_formatting"]?["main_text"] ?? "",
                  "secondary":
                      p["structured_formatting"]?["secondary_text"] ?? "",
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Autocomplete error: $e");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // -- Get Place Coordinates --------------------------------------------------
  Future<void> _selectPlace(String placeId, String description) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _searchCtrl.text = description;
    });

    try {
      final url =
          "https://maps.googleapis.com/maps/api/place/details/json"
          "?place_id=$placeId"
          "&fields=geometry"
          "&key=${widget.mapsApiKey}";

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final loc = data["result"]["geometry"]["location"];
        final lat = (loc["lat"] as num).toDouble();
        final lng = (loc["lng"] as num).toDouble();

        latitude = lat;
        longitude = lng;

        await _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(lat, lng), zoom: 16),
          ),
        );
        await _reverseGeocode(lat, lng);
      }
    } catch (e) {
      debugPrint("Place details error: $e");
    }
  }

  // -- Current Location -------------------------------------------------------
  Future<void> _useCurrentLocation() async {
    setState(() => locationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      latitude = pos.latitude;
      longitude = pos.longitude;

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(latitude!, longitude!), zoom: 16),
        ),
      );

      await _reverseGeocode(latitude!, longitude!);
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      if (mounted) setState(() => locationLoading = false);
    }
  }

  bool isInsideBounds(double lat, double lng) {
    final bounds = cityBounds[widget.selectedCity]!;

    return lat >= bounds.southwest.latitude &&
        lat <= bounds.northeast.latitude &&
        lng >= bounds.southwest.longitude &&
        lng <= bounds.northeast.longitude;
  }

  // -- Confirm Selection ------------------------------------------------------
  void _confirmLocation() {
    if (!isInsideBounds(latitude!, longitude!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Select location inside ${widget.selectedCity}"),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      "latitude": latitude,
      "longitude": longitude,
      "address": resolvedAddress,
      "locality": resolvedLocality,
      "street": resolvedStreet,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // -- Full-Screen Map ----------------------------------------------
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.initialLat, widget.initialLng),
                zoom: 15,
              ),

              /// ?? CITY RESTRICTION (MAIN FIX)
              cameraTargetBounds: CameraTargetBounds(
                cityBounds[widget.selectedCity]!,
              ),

              onMapCreated: (ctrl) {
                _mapController = ctrl;
                setState(() => mapReady = true);

                _reverseGeocode(widget.initialLat, widget.initialLng);
              },

              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              buildingsEnabled: true,
              compassEnabled: false,

              /// ?? USER DRAG
              onCameraMove: (pos) {
                latitude = pos.target.latitude;
                longitude = pos.target.longitude;

                if (!mapMoving) {
                  setState(() => mapMoving = true);
                  _pinAnimController.forward();
                }
              },

              /// ?? AFTER DRAG STOP
              onCameraIdle: () {
                setState(() => mapMoving = false);
                _pinAnimController.reverse();
                HapticFeedback.lightImpact();

                if (_debounce?.isActive ?? false) _debounce!.cancel();

                _debounce = Timer(const Duration(milliseconds: 450), () {
                  if (latitude != null && longitude != null) {
                    _reverseGeocode(latitude!, longitude!);
                  }
                });
              },
            ),
          ),

          // -- Map Loading Overlay ------------------------------------------
          if (!mapReady)
            Container(
              color: const Color(0xfff0f2f5),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xff2f4253)),
              ),
            ),

          // -- Animated Center Pin ------------------------------------------
          Center(
            child: AnimatedBuilder(
              animation: _pinBounce,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _pinBounce.value - 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tooltip bubble
                    AnimatedOpacity(
                      opacity: mapMoving ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff2f4253),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          "Release to set location",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Pin icon
                    Icon(
                      Icons.location_pin,
                      size: mapMoving ? 56 : 48,
                      color: const Color(0xffef4444),
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // -- Pin Shadow on ground -----------------------------------------
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 28),
              width: mapMoving ? 10 : 16,
              height: mapMoving ? 4 : 6,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(mapMoving ? 0.15 : 0.25),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),

          // -- TOP: Search Bar + Back Button --------------------------------
          SafeArea(
            child: Column(
              children: [
                // App bar row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Back button
                      _CircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      // Search field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search area, landmark, locality...",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xff2f4253),
                                size: 20,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _suggestions = []);
                                      },
                                    )
                                  : _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xff2f4253),
                                        ),
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (val) {
                              if (_searchDebounce?.isActive ?? false) {
                                _searchDebounce!.cancel();
                              }
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 400),
                                () => _searchPlaces(val),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Suggestions dropdown
                if (_suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey[100],
                          indent: 56,
                        ),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xffe6f7f5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xff2f4253),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              s["main"],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              s["secondary"],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () =>
                                _selectPlace(s["place_id"], s["description"]),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // -- BOTTOM SHEET: Address Preview + Confirm ----------------------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Location row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xffe6f7f5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xff2f4253),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Locality name (bold)
                                resolvedLocality.isNotEmpty
                                    ? Text(
                                        resolvedLocality,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      )
                                    : Container(
                                        height: 18,
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                // Full address
                                resolvedAddress.isNotEmpty
                                    ? Text(
                                        resolvedAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Column(
                                        children: [
                                          Container(
                                            height: 12,
                                            width: double.infinity,
                                            color: Colors.grey[100],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 12,
                                            width: 180,
                                            color: Colors.grey[100],
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: resolvedAddress.isEmpty
                              ? null
                              : _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2f4253),
                            disabledBackgroundColor: Colors.grey[300],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                resolvedAddress.isEmpty
                                    ? "Locating..."
                                    : "Confirm Location",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Reusable Circle Map Button -------------------------------------------------
class _CircleButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final bool accent;
  final bool loading;

  const _CircleButton({
    this.icon,
    this.onTap,
    this.accent = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent ? const Color(0xff2f4253) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Icon(
                icon,
                size: 20,
                color: accent ? Colors.white : Colors.black87,
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN LOCATION DETAILS SCREEN
// -----------------------------------------------------------------------------

class FlatmateLocationDetailsScreen extends ConsumerStatefulWidget {
  const FlatmateLocationDetailsScreen({super.key});
  @override
  ConsumerState<FlatmateLocationDetailsScreen> createState() =>
      _FlatmateLocationDetailsScreenState();
}

class _FlatmateLocationDetailsScreenState
    extends ConsumerState<FlatmateLocationDetailsScreen> {
  static const Color _primaryDark = Color(0xFF1C1C1E);

  Widget _buildProgressBar() {
    const int totalSteps = 7;
    const int completedStep = 3; // 3/7

    return Row(
      children: List.generate(totalSteps, (i) {
        final bool done = i < completedStep;

        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 2 : 0),
            decoration: BoxDecoration(
              color: done ? _primaryDark : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  final String API_BASE = "https://rentit-backend-yti9.onrender.com";
  final String MAPS_API_KEY = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";

  final TextEditingController localityCtrl = TextEditingController();
  final TextEditingController streetCtrl = TextEditingController();
  final int currentStep = 3; // Property details = step 2

  double? latitude;
  double? longitude;

  String selectedAddress = "";
  List<Map<String, dynamic>> _localitySuggestions = [];
  bool _localityLoading = false;
  Timer? _localityDebounce;
  String? topErrorMessage;
  String get _selectedCity =>
      ref.read(flatmateDraftProvider).draft.city ?? "Chennai";

  final List<String> stepLabels = [
    "Room Details",
    "Property details",
    "Locality details",
    "Amenities",
    "Photos",
    "Contact",
    "Verify",
  ];

  final Map<String, LatLng> cityCoordinates = {
    "Chennai": LatLng(13.0827, 80.2707),
    "Coimbatore": LatLng(11.0168, 76.9558),
    "Bengaluru": LatLng(12.9716, 77.5946),
    "Hyderabad": LatLng(17.3850, 78.4867),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(flatmateDraftProvider).draft;
      final coords =
          cityCoordinates[draft.city ?? "Chennai"] ?? LatLng(13.0827, 80.2707);
      setState(() {
        localityCtrl.text = draft.locality ?? '';
        streetCtrl.text = draft.street ?? '';
        latitude = draft.latitude ?? coords.latitude;
        longitude = draft.longitude ?? coords.longitude;
        selectedAddress = draft.landmark ?? draft.locality ?? '';
      });
    });
  }

  @override
  void dispose() {
    localityCtrl.dispose();
    streetCtrl.dispose();
    _localityDebounce?.cancel();
    super.dispose();
  }

  // -- Step Pills ------------------------------------------------------------
  Widget _stepPills() {
    final visibleSteps = [
      "Room Details",
      "Property details",
      "Locality details",
      "Amenities",
      "Photos",
      "Contact",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: visibleSteps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isCurrent = i == currentStep;
          final isCompleted = i < currentStep;

          Color bg;
          Color fg;
          BorderSide border;

          if (isCurrent) {
            bg = const Color(0xff2f4253);
            fg = Colors.white;
            border = BorderSide.none;
          } else if (isCompleted) {
            bg = const Color(0xffe6f4f1);
            fg = const Color(0xff2f4253);
            border = const BorderSide(color: Color(0xff2f4253), width: 1);
          } else {
            bg = Colors.grey.shade100;
            fg = Colors.grey.shade500;
            border = BorderSide(color: Colors.grey.shade300, width: 1);
          }

          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.fromBorderSide(border),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  final List<Map<String, dynamic>> steps1 = [
    {"label": "Basic", "index": 0},
    {"label": "Property details", "index": 1},
    {"label": "Amenities", "index": 2},
    {"label": "Price details", "index": 3},
    {"label": "Photos", "index": 4},
    {"label": "Contact", "index": 5},
    {"label": "Verify", "index": 6},
  ];

  // -- Section Label ---------------------------------------------------------
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Color(0xff2f4253),
      ),
    ),
  );

  // -- Styled Input ----------------------------------------------------------
  InputDecoration _inputDec(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xff2f4253), width: 1.5),
    ),
  );

  // -- Locality Search -------------------------------------------------------
  Future<void> _searchLocality(String query) async {
    if (query.trim().length < 3) {
      setState(() => _localitySuggestions = []);
      return;
    }
    setState(() => _localityLoading = true);
    try {
      final url =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json"
          "?input=${Uri.encodeComponent(query)}"
          "&key=$MAPS_API_KEY"
          "&locationbias=circle:50000@$latitude,$longitude";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final predictions = data["predictions"] as List? ?? [];
        setState(() {
          _localitySuggestions = predictions
              .where(
                (p) => (p["description"] as String).toLowerCase().contains(
                  _selectedCity.toLowerCase(),
                ),
              )
              .take(5)
              .map<Map<String, dynamic>>(
                (p) => {
                  "description": p["description"],
                  "place_id": p["place_id"],
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Locality search error: $e");
    } finally {
      if (mounted) setState(() => _localityLoading = false);
    }
  }

  Future<void> _selectLocalityPlace(String placeId, String description) async {
    try {
      if (!description.toLowerCase().contains(_selectedCity.toLowerCase())) {
        showSnack("Please select location inside $_selectedCity");
        return;
      }
      final url =
          "https://maps.googleapis.com/maps/api/place/details/json"
          "?place_id=$placeId"
          "&fields=geometry"
          "&key=$MAPS_API_KEY";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final loc = data["result"]["geometry"]["location"];
        setState(() {
          latitude = (loc["lat"] as num).toDouble();
          longitude = (loc["lng"] as num).toDouble();
          localityCtrl.text = description;
          selectedAddress = description;
          _localitySuggestions = [];
        });
      }
    } catch (e) {
      debugPrint("Place select error: $e");
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenMapPicker(
          initialLat: latitude!,
          initialLng: longitude!,
          mapsApiKey: MAPS_API_KEY,
          selectedCity: _selectedCity,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        latitude = result["latitude"];
        longitude = result["longitude"];
        selectedAddress = result["address"] ?? "";
        if ((result["locality"] as String? ?? "").isNotEmpty) {
          localityCtrl.text = result["locality"]; // ?? correct
        }
        if ((result["street"] as String? ?? "").isNotEmpty &&
            streetCtrl.text.isEmpty) {
          streetCtrl.text = result["street"];
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = pos.latitude;
      final lng = pos.longitude;

      final bounds = {
        "Chennai": LatLngBounds(
          southwest: LatLng(12.8, 80.0),
          northeast: LatLng(13.3, 80.3),
        ),
        "Coimbatore": LatLngBounds(
          southwest: LatLng(10.9, 76.8),
          northeast: LatLng(11.1, 77.1),
        ),
        "Bengaluru": LatLngBounds(
          southwest: LatLng(12.8, 77.4),
          northeast: LatLng(13.1, 77.8),
        ),
        "Hyderabad": LatLngBounds(
          southwest: LatLng(17.2, 78.2),
          northeast: LatLng(17.6, 78.6),
        ),
      };

      final cityBound = bounds[_selectedCity]!;
      final isInside =
          lat >= cityBound.southwest.latitude &&
          lat <= cityBound.northeast.latitude &&
          lng >= cityBound.southwest.longitude &&
          lng <= cityBound.northeast.longitude;

      if (!isInside) {
        setState(() {
          topErrorMessage =
              "Your location is outside $_selectedCity. Please select manually.";
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => topErrorMessage = null);
        });
        return;
      }

      setState(() {
        latitude = lat;
        longitude = lng;
      });
      await _openMapPicker();
    } catch (e) {
      showSnack("Could not get location: $e");
    }
  }

  // -- Map Preview -----------------------------------------------------------
  Widget _mapPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // use current location
        GestureDetector(
          onTap: _useCurrentLocation,
          child: Row(
            children: const [
              Icon(
                Icons.my_location_rounded,
                color: Color(0xff2f4253),
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                "use current location",
                style: TextStyle(
                  color: Color(0xff2f4253),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Map card
        GestureDetector(
          onTap: _openMapPicker,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: AbsorbPointer(
                    child: GoogleMap(
                      key: ValueKey("${latitude}_$longitude"),
                      liteModeEnabled: true,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          latitude ?? 13.0827,
                          longitude ?? 80.2707,
                        ),
                        zoom: 14,
                      ),
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId("selected"),
                          position: LatLng(
                            latitude ?? 13.0827,
                            longitude ?? 80.2707,
                          ),
                        ),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (selectedAddress.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            selectedAddress,
            style: const TextStyle(fontSize: 12, color: Color(0xff374151)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // -- Save ------------------------------------------------------------------
  void handleNext() {
    if (localityCtrl.text.trim().isEmpty) {
      showSnack("Please enter or select a locality");
      return;
    }
    if (streetCtrl.text.trim().isEmpty) {
      showSnack("Please enter street / area");
      return;
    }
    if (latitude == null || longitude == null) {
      showSnack("Please mark your location on the map");
      return;
    }

    ref.read(flatmateDraftProvider).update(() {
      final draft = ref.read(flatmateDraftProvider).draft;
      draft.locality = localityCtrl.text.trim();
      draft.street = streetCtrl.text.trim();
      draft.landmark = streetCtrl.text.trim();
      draft.latitude = latitude;
      draft.longitude = longitude;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FlatmateRentScreen()),
    );
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      appBar: AppBar(
        backgroundColor: const Color(0xfff3f4f6),
        surfaceTintColor: const Color(0xfff3f4f6),
        elevation: 0,

        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Color(0xFFE5E7EB)),
            ),
            child: const BackButton(color: Colors.black),
          ),
        ),

        centerTitle: true,

        title: const Text(
          "Locality Details",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "3/7",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xfff3f4f6),
            child: Column(
              children: [_buildProgressBar(), const SizedBox(height: 36)],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Error banner
                if (topErrorMessage != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        topErrorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                // -- Form ------------------------------------------------------
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Locality
                      _sectionLabel("Locality"),
                      TextField(
                        controller: localityCtrl,
                        style: const TextStyle(fontSize: 14),
                        onChanged: (val) {
                          _localityDebounce?.cancel();
                          _localityDebounce = Timer(
                            const Duration(milliseconds: 400),
                            () => _searchLocality(val),
                          );
                        },
                        decoration: _inputDec(
                          "Type location",
                          suffix: _localityLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : localityCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    localityCtrl.clear();
                                    setState(() => _localitySuggestions = []);
                                  },
                                )
                              : null,
                        ),
                      ),

                      // Suggestions
                      if (_localitySuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _localitySuggestions.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (_, i) {
                              final item = _localitySuggestions[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xff2f4253),
                                  size: 18,
                                ),
                                title: Text(
                                  item["description"],
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onTap: () => _selectLocalityPlace(
                                  item["place_id"],
                                  item["description"],
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Map
                      _mapPreview(),

                      const SizedBox(height: 20),

                      // Landmark / Street
                      _sectionLabel("Landmark/ Street"),
                      TextField(
                        controller: streetCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDec("Enter street"),
                      ),

                      const SizedBox(height: 28),
                    ]),
                  ),
                ),
                // Next button removed from slivers
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: handleNext,
            child: const Text(
              "Save & Continue",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
