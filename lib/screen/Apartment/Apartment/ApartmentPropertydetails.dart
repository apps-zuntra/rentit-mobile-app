// ApartmentPropertydetails.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/providers/FlatmateDraftProvider.dart';
import 'package:rentit/providers/apartment_draft_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Design tokens (reference image) ----------------------------------------
const Color _kScaffold = Color(0xFFFFFFFF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE8ECF0);
const Color _kLabelColor = Color(0xFF8A97A8);
const Color _kHintColor = Color(0xFFB0BAC5);
const Color _kPrimaryText = Color(0xFF1A2332);
const Color _kInputBg = Color(0xFFF8FAFC);
const Color _kInputBorder = Color(0xFFE4E9F0);
const Color _kAccent = Color(0xFF2C3E50); // dark navy
const Color _kProgressFg = Color(0xFF2C3E50);
const Color _kProgressBg = Color(0xFFE4E9F0);

class ApartmentPropertyDetailsScreen extends ConsumerStatefulWidget {
  final int apartmentId;
  const ApartmentPropertyDetailsScreen({super.key, required this.apartmentId});

  @override
  ConsumerState<ApartmentPropertyDetailsScreen> createState() =>
      _ApartmentPropertyDetailsScreenState();
}

class _ApartmentPropertyDetailsScreenState
    extends ConsumerState<ApartmentPropertyDetailsScreen> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  // -- All existing state � untouched ------------------------------------------
  final Map<String, dynamic> formData = {
    "propertyType2": "",
    "apartmentType": "",
    "buildingType": "",
    "furnishing": "",
    "bhkType": "",
    "floor": "",
    "totalFloor": "",
    "builtUpArea": "",
    "propertyAge": "",
    "facing": "",
  };

  List<String> features = [];
  // bool loading = false;

  // -- Lifecycle � untouched ---------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadPropertyDetails();
  }

  // -- API: Load existing property details � untouched -------------------------
  Future<void> loadPropertyDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final propertyId = widget.apartmentId;

      debugPrint("PROPERTY ID ?? $propertyId");
      debugPrint("TOKEN ?? $token");

      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse("$API_BASE/apartment/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("LOAD STATUS ?? ${response.statusCode}");
      debugPrint("LOAD BODY ?? ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          formData["propertyType2"] = data["propertyType2"]?.toString() ?? "";
          formData["apartmentType"] = data["apartmentType"]?.toString() ?? "";
          formData["buildingType"] = data["buildingType"]?.toString() ?? "";
          formData["bhkType"] = data["bhkType"]?.toString() ?? "";
          formData["floor"] = data["floor"]?.toString() == "0"
              ? "Ground"
              : (data["floor"]?.toString() ?? "");
          formData["totalFloor"] = data["totalFloor"]?.toString() == "0"
              ? "Ground Only"
              : (data["totalFloor"]?.toString() ?? "");
          formData["builtUpArea"] = data["builtUpArea"]?.toString() ?? "";
          formData["propertyAge"] = data["propertyAge"]?.toString() ?? "";
          formData["facing"] = data["facing"]?.toString() ?? "";
          formData["furnishing"] = data["furnishing"]?.toString() ?? "";

          if (data["otherFeatures"] is Map &&
              data["otherFeatures"]["features"] is List) {
            features = List<String>.from(data["otherFeatures"]["features"]);
          }
        });
      } else if (response.statusCode == 404) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("apartmentId");
        await prefs.remove("propertyId");
        if (mounted) {
          showSnack("Stale draft cleared. Please try again.");
          Navigator.pop(context);
        }
        return;
      }
    } catch (e) {
      debugPrint("loadPropertyDetails error ?? $e");
    } finally {}
  }

  // -- API: Save & continue � untouched ----------------------------------------
  void handleChange(String key, String value) {
    setState(() => formData[key] = value);
  }

  Future<void> handleNext() async {
    // Validate required fields
    if (formData["apartmentType"] == "") {
      showSnack("Please select apartment type");
      return;
    }
    if (formData["bhkType"] == "") {
      showSnack("Please select BHK type");
      return;
    }
    if (formData["builtUpArea"] == "") {
      showSnack("Please enter built-up area");
      return;
    }

    // Warn if area seems too large for the BHK
    final area = double.tryParse(formData["builtUpArea"] as String) ?? 0;
    final bhk = formData["bhkType"] as String;
    if (area > _getMaxAreaForBhk(bhk)) {
      _showSizeWarningPopup(area, bhk);
      return; // warning dialog calls _saveAndContinue() on confirm
    }

    _saveAndContinue();
  }

  void _saveAndContinue() {
    final provider = ref.read(apartmentDraftProvider);

    provider.update(() {
      provider.draft.propertyType2 = formData["propertyType2"] as String;

      provider.draft.apartmentType = formData["apartmentType"] as String;

      provider.draft.buildingType = formData["buildingType"] as String;

      provider.draft.bhkType = formData["bhkType"] as String;

      provider.draft.furnishing = formData["furnishing"] as String;

      provider.draft.propertyAge = formData["propertyAge"] as String;

      provider.draft.facing = formData["facing"] as String;

      provider.draft.floor = formData["floor"] == "Ground"
          ? 0
          : int.tryParse(formData["floor"]);

      provider.draft.totalFloor = formData["totalFloor"] == "Ground Only"
          ? 0
          : int.tryParse(formData["totalFloor"]);

      provider.draft.builtUpArea = int.tryParse(formData["builtUpArea"]);

      provider.draft.otherFeatures = {"features": features};
    });

    Navigator.pushNamed(
      context,
      "/apartmentlocationdetails",
      arguments: {"apartmentId": widget.apartmentId},
    );
  }

  double _getMaxAreaForBhk(String bhkType) {
    switch (bhkType) {
      case "1 RK":
        return 600;
      case "1 BHK":
        return 1000;
      case "2 BHK":
        return 2000;
      case "3 BHK":
        return 4000;
      case "4 BHK":
        return 7000;
      case "4+ BHK":
        return 20000;
      default:
        return 999999;
    }
  }

  void _showSizeWarningPopup(double area, String bhk) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 80,
                  width: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.home_outlined,
                        size: 70,
                        color: Color(0xFFD4D8E2),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5A523),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            "%",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "${area.toInt()} Sq. Ft. is too big for a $bhk, Do you\nwant to recheck this data?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A2332),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE43B51),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "I want to change it",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _saveAndContinue();
                        },
                        child: const Text(
                          "The data is correct",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final propertyId = widget.apartmentId;

      debugPrint("PROPERTY ID USED FOR PUT ?? $propertyId");
      debugPrint("TOKEN ?? $token");

      if (token == null || token.isEmpty) {
        showSnack("Session expired. Please login again ?");
        return;
      }

      final payload = {
        if (formData["propertyType2"] != "")
          "propertyType2": formData["propertyType2"],
        if (formData["apartmentType"] != "")
          "apartmentType": formData["apartmentType"],
        if (formData["buildingType"] != "")
          "buildingType": formData["buildingType"],
        if (formData["bhkType"] != "") "bhkType": formData["bhkType"],
        if (formData["floor"] != "")
          "floor": formData["floor"] == "Ground"
              ? 0
              : int.tryParse(formData["floor"] as String),
        if (formData["totalFloor"] != "")
          "totalFloor": formData["totalFloor"] == "Ground Only"
              ? 0
              : int.tryParse(formData["totalFloor"] as String),
        if (formData["builtUpArea"] != "")
          "builtUpArea": int.tryParse(formData["builtUpArea"]),
        if (formData["propertyAge"] != "")
          "propertyAge": formData["propertyAge"],
        "facing": formData["facing"],
        if (formData["furnishing"] != "") "furnishing": formData["furnishing"],
        if (features.isNotEmpty) "otherFeatures": {"features": features},
      };

      debugPrint("PAYLOAD ?? $payload");

      final res = await http.put(
        Uri.parse("$API_BASE/apartment/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      debugPrint("PUT STATUS ?? ${res.statusCode}");
      debugPrint("PUT BODY ?? ${res.body}");

      if (res.statusCode == 200) {
        showSnack("Saved ??");
        if (mounted) {
          Navigator.pushNamed(
            context,
            "/apartmentlocationdetails",
            arguments: {"apartmentId": propertyId},
          );
        }
      } else {
        final data = jsonDecode(res.body);
        throw Exception(data["message"] ?? "Unknown error");
      }
    } catch (e) {
      showSnack("Error: $e");
    } finally {}
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

  // ------------------------------------------------------------------------------
  // UI HELPERS � redesigned to match reference image
  // ------------------------------------------------------------------------------

  /// Progress bar � 2 of 7 filled (matches "2 / 7" in AppBar)
  Widget _progressBar() {
    const total = 7;
    const current = 2;
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

  /// Card wrapper � white card with border + subtle shadow
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  /// Uppercase label with optional asterisk � matches reference image exactly
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

  /// Input decoration � matches reference: light fill, rounded, subtle border
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

  /// Text input field � same logic, new look
  Widget _inputField(
    String label,
    String key, {
    String hint = "",
    TextInputType type = TextInputType.text,
    bool required = false,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextField(
            keyboardType: type,
            controller: TextEditingController(text: formData[key] as String)
              ..selection = TextSelection.collapsed(
                offset: (formData[key] as String).length,
              ),
            style: const TextStyle(
              color: _kPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDec(hint: hint.isEmpty ? label : hint),
            onChanged: (val) => handleChange(key, val),
          ),
        ],
      ),
    );
  }

  /// Dropdown field � same logic, new look
  Widget _dropdownField(
    String label,
    String key,
    List<String> items, {
    String hint = "Select",
    bool required = false,
  }) {
    final currentValue = formData[key] == "" ? null : formData[key] as String;
    final safeValue = (currentValue != null && items.contains(currentValue))
        ? currentValue
        : null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          DropdownButtonFormField<String>(
            initialValue: safeValue,
            hint: Text(
              hint,
              style: const TextStyle(color: _kHintColor, fontSize: 14),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kLabelColor,
            ),
            dropdownColor: _kCardBg,
            style: const TextStyle(
              color: _kPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDec(),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(
                        color: _kPrimaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => handleChange(key, val ?? ""),
          ),
        ],
      ),
    );
  }

  /// Two fields side-by-side inside a single card � matches Floor/Total Floor card
  Widget _twoColumnDropdownCard({
    required String leftLabel,
    required String leftKey,
    required String leftHint,
    required List<String> leftItems,
    required String rightLabel,
    required String rightKey,
    required String rightHint,
    required List<String> rightItems,
    bool leftRequired = false,
    bool rightRequired = false,
  }) {
    final leftValue = formData[leftKey] == ""
        ? null
        : formData[leftKey] as String;
    final safeLeftValue = (leftValue != null && leftItems.contains(leftValue))
        ? leftValue
        : null;

    final rightValue = formData[rightKey] == ""
        ? null
        : formData[rightKey] as String;
    final safeRightValue =
        (rightValue != null && rightItems.contains(rightValue))
        ? rightValue
        : null;

    return _card(
      child: Row(
        children: [
          // Left
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(leftLabel, required: leftRequired),
                DropdownButtonFormField<String>(
                  initialValue: safeLeftValue,
                  hint: Text(
                    leftHint,
                    style: const TextStyle(color: _kHintColor, fontSize: 14),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _kLabelColor,
                  ),
                  dropdownColor: _kCardBg,
                  style: const TextStyle(
                    color: _kPrimaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _inputDec(),
                  items: leftItems
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: const TextStyle(
                              color: _kPrimaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => handleChange(leftKey, val ?? ""),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(rightLabel, required: rightRequired),
                DropdownButtonFormField<String>(
                  initialValue: safeRightValue,
                  hint: Text(
                    rightHint,
                    style: const TextStyle(color: _kHintColor, fontSize: 14),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _kLabelColor,
                  ),
                  dropdownColor: _kCardBg,
                  style: const TextStyle(
                    color: _kPrimaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _inputDec(),
                  items: rightItems
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: const TextStyle(
                              color: _kPrimaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => handleChange(rightKey, val ?? ""),
                ),
              ],
            ),
          ),
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
        // Back button � rounded square pill matching reference
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
          "Property Details",
          style: TextStyle(
            color: _kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        // "2 / 7" counter on right � matches reference
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "2 / 7",
                style: TextStyle(
                  color: _kLabelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        // Segmented progress bar below AppBar title
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
          // -- Scrollable form ---------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Apartment Type
                  _dropdownField(
                    "Apartment Type",
                    "apartmentType",
                    [
                      "Apartment",
                      "Independent House/Villa",
                      "Gated Community Villa",
                    ],
                    hint: "Select apartment type",
                    required: true,
                  ),

                  // Apartment Name � hidden for Independent House/Villa
                  if (formData["apartmentType"] != "Independent House/Villa" &&
                      formData["apartmentType"] != "")
                    _inputField(
                      "Apartment Name",
                      "buildingType",
                      hint: "Enter apartment name...",
                    ),

                  // BHK Type
                  _dropdownField(
                    "BHK Type",
                    "bhkType",
                    ["1 RK", "1 BHK", "2 BHK", "3 BHK", "4 BHK", "4+ BHK"],
                    hint: "Select BHK type",
                    required: true,
                  ),

                  // Property Size (Built-up Area)
                  _inputField(
                    "Property Size",
                    "builtUpArea",
                    hint: "Built Up Area (Sq. Ft.)",
                    type: TextInputType.number,
                    required: true,
                  ),

                  // Facing
                  _dropdownField("Facing", "facing", [
                    "North",
                    "South",
                    "East",
                    "West",
                    "North-East",
                    "South-East",
                    "North-West",
                    "South-West",
                    "Don't Know",
                  ], hint: "Select"),

                  // Property Age
                  _dropdownField(
                    "Property Age",
                    "propertyAge",
                    [
                      "Less than a year",
                      "1 to 3 year",
                      "3 to 5 year",
                      "5 to 10 year",
                      "more than 10 year",
                    ],
                    hint: "Select Property Age",
                    required: true,
                  ),

                  // Floor + Total Floor � side by side in one card
                  _twoColumnDropdownCard(
                    leftLabel: "Floor",
                    leftKey: "floor",
                    leftHint: "Select",
                    leftItems: [
                      "Ground",
                      ...List.generate(100, (i) => (i + 1).toString()),
                    ],
                    leftRequired: true,
                    rightLabel: "Total Floor",
                    rightKey: "totalFloor",
                    rightHint: "Select",
                    rightItems: [
                      "Ground Only",
                      ...List.generate(100, (i) => (i + 1).toString()),
                    ],
                    rightRequired: true,
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // -- Sticky "Save and Continue" button � matches reference --
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
                onPressed: handleNext,
                child: const Text(
                  "Save and Continue",
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
