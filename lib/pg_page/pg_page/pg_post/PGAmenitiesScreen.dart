import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/pg_page/pg_page/pg_post/PGPhotos.dart';
import 'package:rentit/providers/pg_draft_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Design Tokens (consistent with CommercialContact) ----------------------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);

class PGAmenitiesScreen extends ConsumerStatefulWidget {
  const PGAmenitiesScreen({super.key});

  @override
  ConsumerState<PGAmenitiesScreen> createState() => _PGAmenitiesScreenState();
}

class _PGAmenitiesScreenState extends ConsumerState<PGAmenitiesScreen> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  // -- State ----------------------------------------------------------------
  String parking = "";
  bool foodIncluded = false;

  Map<String, bool> foodType = {
    "breakfast": false,
    "lunch": false,
    "dinner": false,
  };

  Map<String, bool> restrictions = {
    "smoking": false,
    "drinking": false,
    "nonVegAllowed": false,
    "girlsEntry": false,
    "loudMusic": false,
  };

  Map<String, bool> amenities = {
    "laundry": false,
    "roomCleaning": false,
    "wifi": false,
    "commonTV": false,
    "lift": false,
    "powerBackup": false,
    "refrigerator": false,
    "mess": false,
  };

  final Map<String, IconData> amenityIcons = {
    "laundry": Icons.local_laundry_service_outlined,
    "roomCleaning": Icons.cleaning_services_outlined,
    "wifi": Icons.wifi,
    "commonTV": Icons.tv_outlined,
    "lift": Icons.elevator_outlined,
    "powerBackup": Icons.bolt_outlined,
    "refrigerator": Icons.kitchen_outlined,
    "mess": Icons.restaurant_outlined,
  };

  final Map<String, String> amenityLabels = {
    "laundry": "Laundry",
    "roomCleaning": "Room Cleaning",
    "wifi": "Wifi",
    "commonTV": "Common TV",
    "lift": "Lift",
    "powerBackup": "Power Backup",
    "refrigerator": "Refrigerator",
    "mess": "Mess",
  };

  final TextEditingController propertyDescriptionController =
      TextEditingController();
  bool loading = false;

  // -- Steps ------------------------------------------------------------------
  final int currentStep = 5; // 5/8 ? index 4

  final List<Map<String, dynamic>> steps1 = [
    {"label": "Basic", "index": 0},
    {"label": "Property details", "index": 1},
    {"label": "Amenities", "index": 2},
    {"label": "Price details", "index": 3},
    {"label": "Photos", "index": 4},
    {"label": "Contact", "index": 5},
    {"label": "Verify", "index": 6},
  ];

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  @override
  void dispose() {
    propertyDescriptionController.dispose();
    super.dispose();
  }

  // -- API: Load existing data ------------------------------------------------
  Future<void> loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null || token == null) {
      debugPrint("? propertyId or token missing");
      return;
    }

    try {
      final res = await http.get(
        Uri.parse("$API_BASE/property/$propertyId"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("?? AMENITIES RESPONSE: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          parking = data["parking"] ?? "";
          foodIncluded = data["foodIncluded"] ?? false;

          if (data["foodType"] != null) {
            foodType["breakfast"] = data["foodType"]["breakfast"] ?? false;
            foodType["lunch"] = data["foodType"]["lunch"] ?? false;
            foodType["dinner"] = data["foodType"]["dinner"] ?? false;
          }

          if (data["pgAmenities"] != null) {
            amenities.forEach((key, _) {
              amenities[key] = data["pgAmenities"][key] ?? false;
            });
          }

          if (data["restrictions"] != null) {
            restrictions["smoking"] = data["restrictions"]["smoking"] ?? false;
            restrictions["drinking"] =
                data["restrictions"]["drinking"] ?? false;
            restrictions["nonVegAllowed"] =
                data["restrictions"]["nonVeg"] ?? false;
            restrictions["girlsEntry"] =
                data["restrictions"]["girlsEntry"] ?? false;
            restrictions["loudMusic"] =
                data["restrictions"]["loudMusic"] ?? false;
          }

          propertyDescriptionController.text =
              data["propertyDescription"] ?? "";
        });
      } else {
        debugPrint("? Load failed: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("? amenities load error: $e");
    }
  }

  // -- API: Save & Navigate ---------------------------------------------------
  Future<void> handleNext() async {
    final draftProvider = ref.read(pgDraftProvider);

    draftProvider.update(() {
      draftProvider.draft.foodIncluded = foodIncluded;

      draftProvider.draft.foodType = {
        "breakfast": foodType["breakfast"] ?? false,
        "lunch": foodType["lunch"] ?? false,
        "dinner": foodType["dinner"] ?? false,
      };

      draftProvider.draft.pgAmenities = {
        "laundry": amenities["laundry"] ?? false,
        "roomCleaning": amenities["roomCleaning"] ?? false,
        "wifi": amenities["wifi"] ?? false,
        "commonTV": amenities["commonTV"] ?? false,
        "lift": amenities["lift"] ?? false,
        "powerBackup": amenities["powerBackup"] ?? false,
        "refrigerator": amenities["refrigerator"] ?? false,
        "mess": amenities["mess"] ?? false,
      };

      draftProvider.draft.restrictions = {
        "smoking": restrictions["smoking"] ?? false,
        "drinking": restrictions["drinking"] ?? false,
        "nonVegAllowed": restrictions["nonVegAllowed"] ?? false,
        "girlsEntry": restrictions["girlsEntry"] ?? false,
        "loudMusic": restrictions["loudMusic"] ?? false,
      };

      draftProvider.draft.parking = parking;

      draftProvider.draft.propertyDescription = propertyDescriptionController
          .text
          .trim();
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PGPhotosScreen()),
    );
  }

  // -- Helpers ---------------------------------------------------------------
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: kAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  /// Segmented progress bar � 5/8 filled
  Widget _progressBar() {
    const total = 8;
    const current = 5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Row(
        children: List.generate(total, (i) {
          final active = i < current;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? kAccentBlue : kBorderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Card wrapper
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Uppercase section label
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kLabelText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Checkbox row item � styled to match design tokens
  Widget _checkItem(String label, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: value ? kAccentBlue : kBorderColor,
                width: 1.5,
              ),
              color: value ? kAccentBlue : kInputBg,
            ),
            child: value
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: value ? kPrimaryText : kSecondaryText,
              fontWeight: value ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// Parking Dropdown � restyled to match design tokens
  Widget _parkingDropdown() {
    final items = ["Bike", "Car", "Both", "None"];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField2<String>(
        value: parking.isEmpty ? null : parking,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: "Select parking type",
          hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
          filled: true,
          fillColor: kInputBg,
          prefixIcon: const Icon(
            Icons.local_parking_outlined,
            size: 20,
            color: kSecondaryText,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAccentBlue, width: 1.5),
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.expand_more_rounded),
          iconSize: 22,
          iconEnabledColor: kSecondaryText,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: kCardBg,
          ),
          elevation: 4,
        ),
        menuItemStyleData: const MenuItemStyleData(padding: EdgeInsets.zero),
        selectedItemBuilder: (context) {
          return items.map((item) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 15,
                  color: kPrimaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList();
        },
        items: items.map((item) {
          final isSelected = item == parking;
          return DropdownMenuItem<String>(
            value: item,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected
                    ? kAccentBlue.withOpacity(0.08)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    item == "Bike"
                        ? Icons.two_wheeler_outlined
                        : item == "Car"
                        ? Icons.directions_car_outlined
                        : item == "Both"
                        ? Icons.directions
                        : Icons.block,
                    size: 18,
                    color: isSelected ? kAccentBlue : kSecondaryText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? kPrimaryText : kSecondaryText,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: kAccentBlue,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => parking = value);
        },
      ),
    );
  }

  /// Amenity Icon Tile � restyled to match design tokens
  Widget _amenityTile(String key) {
    final selected = amenities[key]!;
    final label = amenityLabels[key]!;
    final icon = amenityIcons[key]!;

    return GestureDetector(
      onTap: () => setState(() => amenities[key] = !selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? kAccentBlue : kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kAccentBlue : kBorderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? Colors.white : kSecondaryText,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white : kPrimaryText,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Build ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldBg,

      // -- AppBar -----------------------------------------------------------
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,

        // Boxed chevron back button � matches CommercialContact exactly
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kInputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderColor),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: kPrimaryText,
              size: 22,
            ),
          ),
        ),

        title: const Text(
          "Amenities & Services",
          style: TextStyle(
            color: kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        // Step counter � "5 / 8"
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "5 / 8",
                style: TextStyle(
                  color: kSecondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        // Segmented progress bar � 5/8 filled
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _progressBar(),
          ),
        ),
      ),

      body: Column(
        children: [
          // -- Scrollable Form -----------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Parking -------------------------------------------
                  _label("Parking"),
                  _parkingDropdown(),

                  // -- Food Included -------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Food Included"),
                        Row(
                          children: [
                            _checkItem("No", !foodIncluded, (v) {
                              setState(() {
                                foodIncluded = false;
                                foodType.updateAll((k, val) => false);
                              });
                            }),
                            const SizedBox(width: 28),
                            _checkItem("Yes", foodIncluded, (v) {
                              setState(() => foodIncluded = true);
                            }),
                          ],
                        ),
                        if (foodIncluded) ...[
                          const SizedBox(height: 14),
                          const Text(
                            "FOOD TYPE",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kLabelText,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 24,
                            runSpacing: 10,
                            children: [
                              _checkItem(
                                "Breakfast",
                                foodType["breakfast"]!,
                                (v) =>
                                    setState(() => foodType["breakfast"] = v),
                              ),
                              _checkItem(
                                "Lunch",
                                foodType["lunch"]!,
                                (v) => setState(() => foodType["lunch"] = v),
                              ),
                              _checkItem(
                                "Dinner",
                                foodType["dinner"]!,
                                (v) => setState(() => foodType["dinner"] = v),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // -- Restrictions --------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Restrictions"),
                        Wrap(
                          spacing: 24,
                          runSpacing: 14,
                          children: [
                            _checkItem(
                              "Smoking",
                              restrictions["smoking"]!,
                              (v) =>
                                  setState(() => restrictions["smoking"] = v),
                            ),
                            _checkItem(
                              "Alcohol",
                              restrictions["drinking"]!,
                              (v) =>
                                  setState(() => restrictions["drinking"] = v),
                            ),
                            _checkItem(
                              "Loud Music",
                              restrictions["loudMusic"]!,
                              (v) =>
                                  setState(() => restrictions["loudMusic"] = v),
                            ),
                            _checkItem(
                              "Non-Veg",
                              restrictions["nonVegAllowed"]!,
                              (v) => setState(
                                () => restrictions["nonVegAllowed"] = v,
                              ),
                            ),
                            _checkItem(
                              "Girl's Entry",
                              restrictions["girlsEntry"]!,
                              (v) => setState(
                                () => restrictions["girlsEntry"] = v,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // -- Description ---------------------------------------
                  _card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: _label("Description"),
                        ),
                        TextField(
                          controller: propertyDescriptionController,
                          maxLines: 4,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kPrimaryText,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                "Write a few lines about your property...",
                            hintStyle: const TextStyle(
                              color: kSecondaryText,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -- Common Amenities ----------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Common Amenities"),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                          children: amenityLabels.keys
                              .map((key) => _amenityTile(key))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // -- Sticky Save & Continue Button -----------------------------
          Container(
            color: kCardBg,
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
                  backgroundColor: kAccentBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kAccentBlue.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: loading ? null : handleNext,
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
