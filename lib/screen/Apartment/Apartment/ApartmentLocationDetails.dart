// ApartmentLocationDetails.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/providers/apartment_draft_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

// -----------------------------------------------------------------------------
// GLOBAL COLOR CONSTANTS
// -----------------------------------------------------------------------------

const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE8ECF0);
const Color _kLabelColor = Color(0xFF8A97A8);
const Color _kPrimaryText = Color(0xFF1A2332);
const Color _kProgressFg = Color(0xFF2C3E50);
const Color _kProgressBg = Color(0xFFE4E9F0);

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
    localityCtrl.clear();
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

      print("STATUS: ${res.statusCode}");
      print("BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

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
          "&locationbias=circle:50000@$latitude,$longitude"
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
              onCameraMove: (pos) {
                latitude = pos.target.latitude;
                longitude = pos.target.longitude;
                if (!mapMoving) {
                  setState(() => mapMoving = true);
                  _pinAnimController.forward();
                }
              },
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
              builder: (_, _) => Transform.translate(
                offset: Offset(0, _pinBounce.value - 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                              color: Colors.black.withValues(alpha: 0.2),
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
                    Icon(
                      Icons.location_pin,
                      size: mapMoving ? 56 : 48,
                      color: const Color(0xffef4444),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
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
                color: Colors.black.withValues(alpha: mapMoving ? 0.15 : 0.25),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),

          // -- TOP: Search Bar + Back Button --------------------------------
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
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
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => Divider(
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
                    color: Colors.black.withValues(alpha: 0.15),
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

class _CircleButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final bool accent;
  final bool loading;

  const _CircleButton({
    super.key,
    this.icon,
    this.onTap,
    this.accent = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent ? const Color(0xff2f4253) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
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

class ApartmentLocationDetailsScreen extends ConsumerStatefulWidget {
  final String selectedCity;
  final int apartmentId;

  const ApartmentLocationDetailsScreen({
    super.key,
    required this.selectedCity,
    required this.apartmentId,
  });

  @override
  ConsumerState<ApartmentLocationDetailsScreen> createState() =>
      _ApartmentLocationDetailsScreenState();
}

class _ApartmentLocationDetailsScreenState
    extends ConsumerState<ApartmentLocationDetailsScreen> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";
  final String MAPS_API_KEY = "AIzaSyBizXLJbKBu9EfDbi6AbAU8yMCQeW6CFyE";

  final TextEditingController localityCtrl = TextEditingController();
  final TextEditingController streetCtrl = TextEditingController();

  // currentStep index for progress bar (0-based, locality = index 2 ? 3 filled)
  static const int _kCurrentStep = 3; // 3 of 7 segments filled
  static const int _kTotalSteps = 7;

  double? latitude;
  double? longitude;
  bool saving = false;
  String selectedAddress = "";
  List<Map<String, dynamic>> _localitySuggestions = [];
  bool _localityLoading = false;
  Timer? _localityDebounce;
  String? topErrorMessage;

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
      final draft = ref.read(apartmentDraftProvider).draft;

      if (draft.locality != null) {
        localityCtrl.text = draft.locality!;
      }

      if (draft.street != null) {
        streetCtrl.text = draft.street!;
      }

      latitude = draft.latitude;
      longitude = draft.longitude;

      if (draft.locality == null) {
        final coords =
            cityCoordinates[widget.selectedCity] ??
            const LatLng(13.0827, 80.2707);

        latitude = coords.latitude;
        longitude = coords.longitude;

        loadExistingData();
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    localityCtrl.dispose();
    streetCtrl.dispose();
    _localityDebounce?.cancel();
    super.dispose();
  }

  // -- Top Progress Bar -------------------------------------------------------
  /// Renders 7 equal segments; the first [_kCurrentStep] are filled dark.
  Widget _topProgressBar() {
    return Row(
      children: List.generate(_kTotalSteps, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < _kTotalSteps - 1 ? 5 : 0),
            height: 3.5,
            decoration: BoxDecoration(
              color: i < _kCurrentStep ? _kProgressFg : _kProgressBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

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

  // -- Load Existing Data ----------------------------------------------------
  Future<void> loadExistingData() async {
    final draft = ref.read(apartmentDraftProvider).draft;

    if (draft.locality != null ||
        draft.street != null ||
        draft.latitude != null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final int apartmentId = widget.apartmentId;

    if (token == null || token.isEmpty) return;

    try {
      final res = await http.get(
        Uri.parse("$API_BASE/apartment/$apartmentId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("?? APARTMENT LOCATION RESPONSE: ${res.body}");

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);

        if (!mounted) return;

        // -- ADD THIS HELPER --
        String clean(String? val) {
          if (val == null) return "";
          final v = val.trim();
          return v.toLowerCase() == "unknown" ? "" : v;
        }

        setState(() {
          localityCtrl.text = clean(data["locality"]?.toString());
          streetCtrl.text = clean(
            data["street"]?.toString().isNotEmpty == true
                ? data["street"]?.toString()
                : data["landmark"]?.toString(),
          );

          if (data["latitude"] != null) {
            latitude = (data["latitude"] as num).toDouble();
          }
          if (data["longitude"] != null) {
            longitude = (data["longitude"] as num).toDouble();
          }

          selectedAddress = clean(
            data["address"]?.toString().isNotEmpty == true
                ? data["address"]?.toString()
                : data["locality"]?.toString(),
          );
        });
      } else if (res.statusCode == 404) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("apartmentId");
        await prefs.remove("propertyId");
        if (mounted) {
          showSnack("Stale draft cleared. Please try again.");
          Navigator.pop(context);
        }
      } else {
        print("? Failed to fetch apartment data: ${res.statusCode}");
        print(res.body);
      }
    } catch (e) {
      debugPrint("? location load error: $e");
    }
  }

  // -- Locality Search -------------------------------------------------------
  Future<void> _searchLocality(String query) async {
    if (query.trim().length < 3) {
      setState(() => _localitySuggestions = []);
      return;
    }
    setState(() => _localityLoading = true);
    try {
      final url =
          "https://maps.googleapis.com/maps/api/place/autocomplete.json"
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
                  widget.selectedCity.toLowerCase(),
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
      if (!description.toLowerCase().contains(
        widget.selectedCity.toLowerCase(),
      )) {
        showSnack("Please select location inside ${widget.selectedCity}");
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
          selectedCity: widget.selectedCity,
        ),
      ),
    );
    if (result != null && mounted) {
      final draftProvider = ref.read(apartmentDraftProvider);

      draftProvider.update(() {
        draftProvider.draft.latitude = result["latitude"];

        draftProvider.draft.longitude = result["longitude"];

        draftProvider.draft.directions = result["address"] ?? "";

        draftProvider.draft.locality = result["locality"] ?? "";

        draftProvider.draft.street = result["street"] ?? "";
      });

      setState(() {
        latitude = result["latitude"];
        longitude = result["longitude"];
        selectedAddress = result["address"] ?? "";

        if ((result["locality"] ?? "").isNotEmpty) {
          localityCtrl.text = result["locality"];
        }

        if ((result["street"] ?? "").isNotEmpty) {
          streetCtrl.text = result["street"];
        }
      });
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

      final cityBound = bounds[widget.selectedCity]!;
      final isInside =
          lat >= cityBound.southwest.latitude &&
          lat <= cityBound.northeast.latitude &&
          lng >= cityBound.southwest.longitude &&
          lng <= cityBound.northeast.longitude;

      if (!isInside) {
        setState(() {
          topErrorMessage =
              "Your location is outside ${widget.selectedCity}. Please select manually.";
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
        GestureDetector(
          onTap: _useCurrentLocation,
          child: const Row(
            children: [
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
        GestureDetector(
          onTap: _openMapPicker,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: AbsorbPointer(
                child: GoogleMap(
                  key: ValueKey("${latitude}_$longitude"),
                  liteModeEnabled: true,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(latitude ?? 13.0827, longitude ?? 80.2707),
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

  // -- Save & Continue -------------------------------------------------------
  Future<void> handleNext() async {
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

    setState(() => saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final propertyId = widget.apartmentId;

      debugPrint("PROPERTY ID USED FOR LOCATION PUT ?? $propertyId");

      if (token == null || token.isEmpty) {
        showSnack("Session expired. Please login again.");
        return;
      }

      final payload = {
        "city": widget.selectedCity,
        "locality": localityCtrl.text.trim(),
        "street": streetCtrl.text.trim(),
        "landmark": streetCtrl.text.trim(),
        "latitude": latitude,
        "longitude": longitude,
      };

      debugPrint("LOCATION PAYLOAD ?? $payload");

      final res = await http.put(
        Uri.parse("$API_BASE/apartment/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      debugPrint("LOCATION PUT STATUS ?? ${res.statusCode}");
      debugPrint("LOCATION PUT BODY ?? ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final draftNotifier = ref.read(apartmentDraftProvider);
        draftNotifier.update(() {
          draftNotifier.draft.city = widget.selectedCity;
          draftNotifier.draft.locality = localityCtrl.text.trim();
          draftNotifier.draft.street = streetCtrl.text.trim();
          draftNotifier.draft.landmark = streetCtrl.text.trim();
          draftNotifier.draft.latitude = latitude;
          draftNotifier.draft.longitude = longitude;
        });

        if (mounted) {
          Navigator.pushNamed(
            context,
            "/apartmentRentalDetails",
            arguments: {"apartmentId": widget.apartmentId},
          );
        }
      } else if (res.statusCode == 404) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("apartmentId");
        await prefs.remove("propertyId");
        if (mounted) {
          showSnack("Stale draft cleared. Please try again.");
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(res.body);
        showSnack(data["message"] ?? "Failed to save location details");
      }
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => saving = false);
    }
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

  // -- Build -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),

      // -- APP BAR ---------------------------------------------------------
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,

        // Back button � rounded square
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kCardBorder),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: _kPrimaryText,
              size: 22,
            ),
          ),
        ),

        centerTitle: true,

        title: const Text(
          "Locality Details",
          style: TextStyle(
            color: _kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        // "3 / 7" step counter
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "3 / 7",
                style: TextStyle(
                  color: _kLabelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        // Thin progress bar below AppBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _topProgressBar(),
          ),
        ),
      ),

      // -- BODY ------------------------------------------------------------
      body: CustomScrollView(
        slivers: [
          // Error banner
          if (topErrorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),

          // -- Form --------------------------------------------------------
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Locality field
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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

                // Locality suggestions dropdown
                if (_localitySuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _localitySuggestions.length,
                      separatorBuilder: (_, _) =>
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

                // Map preview
                _mapPreview(),

                const SizedBox(height: 20),

                // Landmark / Street field
                _sectionLabel("Landmark / Street"),
                TextField(
                  controller: streetCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDec("Enter street"),
                ),

                const SizedBox(height: 28),
              ]),
            ),
          ),
          // -- Save & Continue button removed from slivers ------------------
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
            onPressed: saving ? null : handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2f4253),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
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
