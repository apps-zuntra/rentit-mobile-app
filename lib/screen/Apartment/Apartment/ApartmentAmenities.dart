// ApartmentAmenities.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// -- Design tokens ------------------------------------------------------------
const Color _kScaffold = Color(0xFFFFFFFF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE8ECF0);
const Color _kInputBg = Color(0xFFF8FAFC);
const Color _kInputBorder = Color(0xFFE4E9F0);
const Color _kLabelColor = Color(0xFF8A97A8);
const Color _kHintColor = Color(0xFFB0BAC5);
const Color _kPrimaryText = Color(0xFF1A2332);
const Color _kAccent = Color(0xFF2C3E50); // dark navy � button
const Color _kTeal = Color(0xFF0D9E8A); // teal � Yes / active states
const Color _kProgressFg = Color(0xFF2C3E50);
const Color _kProgressBg = Color(0xFFE4E9F0);

class ApartmentAmenitiesScreen extends StatefulWidget {
  final int apartmentId;

  const ApartmentAmenitiesScreen({super.key, required this.apartmentId});

  @override
  State<ApartmentAmenitiesScreen> createState() =>
      _ApartmentAmenitiesScreenState();
}

class _ApartmentAmenitiesScreenState extends State<ApartmentAmenitiesScreen> {
  // -- ALL EXISTING STATE � UNTOUCHED ------------------------------------------
  final String apiBase = "https://rentit-backend-yti9.onrender.com";

  final TextEditingController secondaryNumberController =
      TextEditingController();
  final TextEditingController directionsController = TextEditingController();

  @override
  void dispose() {
    secondaryNumberController.dispose();
    directionsController.dispose();
    super.dispose();
  }

  int bathroom = 0;
  int balcony = 0;

  String waterSupply = "";
  bool? petAllowed;
  bool? gymAllowed;
  bool? nonVegAllowed;
  bool? gateSecurity;
  String shownBy = "";
  String propertyCondition = "";
  String secondaryNumber = "";
  bool similarUnits = false;
  String directions = "";
  List<String> amenities = [];
  bool loading = false;
  bool _showDirectionsTipPoster = true;

  final List<String> amenityList = [
    "Lift",
    "Internet Services",
    "Air Conditioner",
    "Club House",
    "Intercom",
    "Swimming Pool",
    "Children Play Area",
    "Fire Safety",
    "Servant Room",
    "Shopping Center",
    "Gas Pipeline",
    "Park",
    "Rain Water Harvesting",
    "Sewage Treatment Plant",
    "House Keeping",
    "Power Backup",
    "Visitor Parking",
  ];

  // -- Display labels for amenities (matching reference image names) -----------
  String _amenityDisplayName(String item) {
    const Map<String, String> labels = {
      "Air Conditioner": "Air-Conditioner",
      "Club House": "Club",
      "Children Play Area": "Playground",
      "Gas Pipeline": "Gas",
      "Rain Water Harvesting": "Rain Water Harvesting",
      "Sewage Treatment Plant": "Sewage",
      "House Keeping": "House-Keeper",
      "Fire Safety": "Fire-Alarm",
    };
    return labels[item] ?? item;
  }

  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  // -- ALL EXISTING LOGIC � UNTOUCHED ------------------------------------------
  void toggleAmenity(String item) {
    setState(() {
      amenities.contains(item) ? amenities.remove(item) : amenities.add(item);
    });
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: _kAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> handleSubmit() async {
    if (bathroom <= 0) {
      showSnack("Please select Bathroom count");
      return;
    }

    if (shownBy.trim().isEmpty) {
      showSnack("Please select Who Will Show This Property");
      return;
    }

    if (nonVegAllowed == null) {
      showSnack("Please select Non-Veg Allowed");
      return;
    }

    if (gateSecurity == null) {
      showSnack("Please select Gated Security");
      return;
    }

    if (gymAllowed == null) {
      showSnack("Please select Gym");
      return;
    }

    if (petAllowed == null) {
      showSnack("Please select Pet Allowed");
      return;
    }
    try {
      setState(() => loading = true);

      final prefs = await SharedPreferences.getInstance();
      final int apartmentId = widget.apartmentId;
      final String? token =
          prefs.getString("accessToken") ??
          prefs.getString("access_token") ??
          prefs.getString("token");

      if (token == null || token.isEmpty) {
        showSnack("Please login again");
        return;
      }

      final payload = {
        "bathroom": bathroom,
        "noOfBalcony": balcony,
        if (waterSupply.isNotEmpty) "waterSupply": {"type": waterSupply},
        "petAllowed": petAllowed,
        "gymAllowed": gymAllowed,
        "nonVegAllowed": nonVegAllowed,
        "gateSecurity": gateSecurity,
        if (shownBy.isNotEmpty) "shownBy": shownBy,
        if (propertyCondition.isNotEmpty)
          "propertyCondition": {"type": propertyCondition},
        if (secondaryNumber.isNotEmpty) "secondaryNumber": secondaryNumber,
        "unitsPropertiesAvailable": similarUnits,
        if (directions.isNotEmpty) "directions": directions,
        if (amenities.isNotEmpty) "amenities": amenities,
      };

      print("?? apartmentId => $apartmentId");
      print("?? token => $token");
      print("?? payload => ${jsonEncode(payload)}");

      final response = await http.put(
        Uri.parse("$apiBase/apartment/$apartmentId/additional-details"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      print("?? STATUS => ${response.statusCode}");
      print("?? BODY => ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnack("Saved Successfully ??");
        if (mounted) {
          Navigator.pushNamed(
            context,
            "/apartmentphotos",
            arguments: {"apartmentId": widget.apartmentId},
          );
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data["message"]?.toString() ?? "Failed to save data");
      }
    } catch (e) {
      print("? handleSubmit() error => $e");
      showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int apartmentId = widget.apartmentId;
      final String? token =
          prefs.getString("accessToken") ??
          prefs.getString("access_token") ??
          prefs.getString("token");

      print("?? apartmentId: $apartmentId");
      print("?? token: $token");

      if (token == null || token.isEmpty) {
        showSnack("Please login again");
        return;
      }

      final response = await http.get(
        Uri.parse("$apiBase/apartment/$apartmentId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("?? STATUS: ${response.statusCode}");
      print("?? BODY: ${response.body}");

      if (response.statusCode != 200) {
        showSnack("Failed to load existing data");
        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        bathroom = (data["bathroom"] ?? 0) as int;
        balcony = (data["noOfBalcony"] ?? 0) as int;

        final waterSupplyData = data["waterSupply"];
        if (waterSupplyData is Map<String, dynamic>) {
          waterSupply = waterSupplyData["type"]?.toString() ?? "";
        } else {
          waterSupply = waterSupplyData?.toString() ?? "";
        }

        petAllowed = data["petAllowed"] == true;
        gymAllowed = data["gymAllowed"] == true;
        nonVegAllowed = data["nonVegAllowed"] == true;
        gateSecurity = data["gateSecurity"] == true;
        similarUnits = data["unitsPropertiesAvailable"] == true;
        shownBy = data["shownBy"]?.toString() ?? "";

        final propertyConditionData = data["propertyCondition"];
        if (propertyConditionData is Map<String, dynamic>) {
          propertyCondition = propertyConditionData["type"]?.toString() ?? "";
        } else {
          propertyCondition = propertyConditionData?.toString() ?? "";
        }

        secondaryNumber = data["secondaryNumber"]?.toString() ?? "";
        directions = data["directions"]?.toString() ?? "";

        secondaryNumberController.text = secondaryNumber;
        directionsController.text = directions;

        final rawAmenities = data["amenities"];
        if (rawAmenities is List) {
          amenities = rawAmenities
              .map((e) {
                if (e is Map<String, dynamic>) {
                  return e["name"]?.toString() ?? "";
                }
                return e.toString();
              })
              .where((e) => e.isNotEmpty)
              .toList();
        } else {
          amenities = [];
        }
      });

      print("? Apartment amenities loaded successfully");
      print("? Selected amenities: $amenities");
    } catch (e) {
      debugPrint("? loadExistingData() error: $e");
      showSnack("Error loading data: $e");
    }
  }

  // ----------------------------------------------------------------------------
  // UI HELPERS � redesigned to match reference image
  // ----------------------------------------------------------------------------

  /// Segmented progress bar � 5 of 7
  Widget _progressBar() {
    const total = 7;
    const current = 5;
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
            height: 3.5,
            decoration: BoxDecoration(
              color: active ? _kProgressFg : _kProgressBg,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  /// White card wrapper with border + shadow
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Uppercase label with optional asterisk
  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: _kLabelColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          if (required)
            const Text(
              " *",
              style: TextStyle(
                color: _kLabelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  /// Input decoration
  InputDecoration _inputDec({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHintColor, fontSize: 14),
      filled: true,
      fillColor: _kInputBg,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kAccent, width: 1.5),
      ),
    );
  }

  /// Styled dropdown
  Widget _styledDropdown({
    required String value,
    required List<String> items,
    required void Function(String) onChanged,
    String hint = "Select",
  }) {
    final String? safeValue = (value.isNotEmpty && items.contains(value))
        ? value
        : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kLabelColor),
      dropdownColor: _kCardBg,
      style: const TextStyle(
        color: _kPrimaryText,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDec(),
      hint: Text(
        hint,
        style: const TextStyle(color: _kHintColor, fontSize: 14),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  color: _kPrimaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }

  /// Counter widget � matches reference: rounded-square - / number / + buttons
  Widget _counter({
    required String labelText,
    required bool required,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              labelText.toUpperCase(),
              style: const TextStyle(
                color: _kLabelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
            if (required)
              const Text(
                " *",
                style: TextStyle(
                  color: _kLabelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Minus button
            GestureDetector(
              onTap: onMinus,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kCardBorder),
                ),
                child: const Icon(Icons.remove, size: 18, color: _kPrimaryText),
              ),
            ),
            // Value
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                "$value",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kPrimaryText,
                ),
              ),
            ),
            // Plus button
            GestureDetector(
              onTap: onPlus,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kCardBorder),
                ),
                child: const Icon(Icons.add, size: 18, color: _kPrimaryText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// No / Yes toggle row � matches reference exactly
  Widget _toggleRow(
    String title, {
    required bool value,
    required void Function(bool) onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _kPrimaryText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // No button
          GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: !value ? const Color(0xFFF0F3F6) : _kCardBg,
                border: Border.all(color: !value ? _kLabelColor : _kCardBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "No",
                style: TextStyle(
                  color: !value ? _kPrimaryText : _kHintColor,
                  fontSize: 13,
                  fontWeight: !value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Yes button
          GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: value ? const Color(0xFFE5F7F3) : _kCardBg,
                border: Border.all(
                  color: value ? const Color(0xFF12AA8C) : _kCardBorder,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Yes",
                style: TextStyle(
                  color: value ? const Color(0xFF12AA8C) : _kHintColor,
                  fontSize: 13,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Directions card with "NEW" badge and teal info banner
  Widget _directionsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with NEW badge
          Row(
            children: [
              Text(
                "ADD DIRECTIONS TIP FOR YOUR TENANTS",
                style: const TextStyle(
                  color: _kLabelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8453C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Teal info banner
          // Info Banner
          if (_showDirectionsTipPoster)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Don't want calls asking location?",
                          style: TextStyle(
                            color: Color(0xFF1F6FB2),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Add directions to reach using landmarks",
                          style: TextStyle(
                            color: Color(0xFF5DA6DD),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showDirectionsTipPoster = false;
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFB7D2EA),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF7FB2D9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Text area
          TextField(
            controller: directionsController,
            maxLines: 3,
            style: const TextStyle(
              color: _kPrimaryText,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _inputDec(
              hint:
                  "Eg: Take the road opposite to Amrita College, take right after 300m, last house in the lane.",
            ),
            onChanged: (v) {
              directions = v;
            },
          ),
        ],
      ),
    );
  }

  /// Secondary Number card � flat input matching reference
  Widget _secondaryNumberCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: secondaryNumberController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(
          color: _kPrimaryText,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: "Enter Secondary Number",
          hintStyle: const TextStyle(color: _kHintColor, fontSize: 14),
          filled: true,
          fillColor: _kCardBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kAccent, width: 1.5),
          ),
        ),
        onChanged: (v) {
          secondaryNumber = v;
        },
      ),
    );
  }

  /// Amenities � vertical checkbox list matching reference
  Widget _amenitiesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Other Amenities"),
          ...amenityList.map((item) {
            final selected = amenities.contains(item);
            return GestureDetector(
              onTap: () => toggleAmenity(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => toggleAmenity(item),
                        activeColor: _kTeal,
                        side: const BorderSide(color: _kCardBorder, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _amenityDisplayName(item),
                      style: TextStyle(
                        color: selected ? _kPrimaryText : _kPrimaryText,
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // -- Build -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kScaffold,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
        title: const Text(
          "Amenities",
          style: TextStyle(
            color: _kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "5 / 7",
                style: TextStyle(
                  color: _kLabelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _progressBar(),
          ),
        ),
      ),
      body: Column(
        children: [
          // -- Scrollable form -------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Bathroom + Balcony counters in one card ------------
                  _card(
                    child: Row(
                      children: [
                        Expanded(
                          child: _counter(
                            labelText: "Bathroom(s)",
                            required: true,
                            value: bathroom,
                            onMinus: () => setState(
                              () => bathroom = (bathroom - 1).clamp(0, 99),
                            ),
                            onPlus: () => setState(() => bathroom++),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _counter(
                            labelText: "Balcony(s)",
                            required: false,
                            value: balcony,
                            onMinus: () => setState(
                              () => balcony = (balcony - 1).clamp(0, 99),
                            ),
                            onPlus: () => setState(() => balcony++),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -- Who Will Show card ---------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Who Will Show This Property?", required: true),
                        _styledDropdown(
                          value: shownBy,
                          items: const [
                            "Need help",
                            "Owner",
                            "Tenants",
                            "Security",
                            "Friends/Relatives",
                            "Others",
                          ],
                          hint: "Select",
                          onChanged: (v) => setState(() => shownBy = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Preferences card (toggles) -------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _toggleRow(
                          "Non-veg allowed *",
                          required: true,
                          value: nonVegAllowed ?? false,
                          onChanged: (v) => setState(() => nonVegAllowed = v),
                        ),
                        Divider(color: _kCardBorder, height: 1),
                        _toggleRow(
                          "Gated Security *",
                          required: true,
                          value: gateSecurity ?? false,
                          onChanged: (v) => setState(() => gateSecurity = v),
                        ),
                        Divider(color: _kCardBorder, height: 1),
                        _toggleRow(
                          "Gym *",
                          required: true,
                          value: gymAllowed ?? false,
                          onChanged: (v) => setState(() => gymAllowed = v),
                        ),
                        Divider(color: _kCardBorder, height: 1),
                        _toggleRow(
                          "Pet Allowed *",
                          required: true,
                          value: petAllowed ?? false,
                          onChanged: (v) => setState(() => petAllowed = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Directions card ------------------------------------
                  _directionsCard(),

                  // -- Current Situation of Property card ----------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Current Situation of Property"),
                        _styledDropdown(
                          value: propertyCondition,
                          items: const [
                            "Vacant",
                            "Tenant on Notice Period",
                            "New Property",
                            "Need Help to Manage",
                          ],
                          hint: "Select",
                          onChanged: (v) =>
                              setState(() => propertyCondition = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Water Supply card ---------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Water Supply"),
                        _styledDropdown(
                          value: waterSupply,
                          items: const ["Corporation", "Borewell", "Both"],
                          hint: "Select",
                          onChanged: (v) => setState(() => waterSupply = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Secondary Number � flat card ----------------------
                  _secondaryNumberCard(),

                  // -- Other Amenities � checkbox list -------------------
                  _amenitiesCard(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // -- Sticky Save & Continue button -----------------------------
          Container(
            color: _kCardBg,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: loading ? null : handleSubmit,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Save & Continue",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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
