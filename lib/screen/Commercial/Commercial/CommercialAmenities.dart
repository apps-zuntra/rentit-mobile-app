// CommercialAmenities.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/model/model/commercial_provider.dart';
import 'package:rentit/screen/Commercial/Commercial/commercial_form_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Design Tokens (matches CommercialProvideRentalDetails) --------------------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50); // dark navy � CTA & active
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);
// -----------------------------------------------------------------------------

class CommercialAmenities extends ConsumerStatefulWidget {
  const CommercialAmenities({super.key});

  @override
  ConsumerState<CommercialAmenities> createState() =>
      _CommercialAmenitiesState();
}

class _CommercialAmenitiesState extends ConsumerState<CommercialAmenities> {
  static const String _apiBase = "https://rentit-backend-yti9.onrender.com";

  // -- Controllers ------------------------------------------------------------
  late TextEditingController _slotsController;
  late TextEditingController _directionsController;

  // -- Form State -------------------------------------------------------------
  final Map<String, dynamic> _form = {
    "powerBackup": null,
    "lift": null,
    "parking": null,
    "washroom": null,
    "slots": "",
    "waterStorage": null,
    "security": null,
    "propertyCondition": null,
    "business": null,
    "similar": false,
    "directions": "",
  };

  bool _isLoading = false;
  bool _dataLoading = true;

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _slotsController = TextEditingController();
    _directionsController = TextEditingController();
    _loadExistingData();
  }

  @override
  void dispose() {
    _slotsController.dispose();
    _directionsController.dispose();
    super.dispose();
  }

  // -- Helpers ----------------------------------------------------------------
  void _update(String key, dynamic value) => setState(() => _form[key] = value);

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: kAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // -- Load Existing Data (unchanged) -----------------------------------------
  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commercialId = prefs.getInt("commercialId");
      final token = prefs.getString("token");

      if (commercialId == null || token == null) {
        if (mounted) setState(() => _dataLoading = false);
        return;
      }

      final res = await http.get(
        Uri.parse("$_apiBase/commercial/$commercialId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("?? AMENITIES RESPONSE => ${res.body}");

      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() => _dataLoading = false);
        return;
      }

      final data = jsonDecode(res.body);
      final other = (data["otherFeatures"] as Map<String, dynamic>?) ?? {};

      setState(() {
        _form["powerBackup"] = other["powerBackup"];
        _form["lift"] = other["lift"];
        _form["parking"] = other["parking"];
        _form["washroom"] = other["washroom"];
        _form["waterStorage"] = other["waterStorage"];
        _form["security"] = other["security"];
        _form["propertyCondition"] = other["propertyCondition"];
        _form["business"] = other["business"];
        _form["similar"] = other["similarUnitsAvailable"] ?? false;

        _form["slots"] = data["slots"]?.toString() ?? "";
        _form["directions"] = data["addOthertags"]?.toString() ?? "";

        _slotsController.text = _form["slots"];
        _directionsController.text = _form["directions"];

        _dataLoading = false;
      });
    } catch (e) {
      debugPrint("? Amenities load error: $e");
      if (mounted) setState(() => _dataLoading = false);
    }
  }

  // -- Submit (unchanged) -----------------------------------------------------
  Future<void> _handleSubmit() async {
    if (_form["powerBackup"] == null) {
      _showSnack("Please select power backup");
      return;
    }

    if (_form["parking"] == null) {
      _showSnack("Please select parking");
      return;
    }

    if (_form["washroom"] == null) {
      _showSnack("Please provide washroom availability");
      return;
    }

    // Save to form provider
    ref.read(commercialFormProvider.notifier).updateData({
      "otherFeatures": {
        "parking": _form["parking"],
        "powerBackup": _form["powerBackup"],
        "lift": _form["lift"],
        "washroom": _form["washroom"],
        "waterStorage": _form["waterStorage"],
        "security": _form["security"],
        "propertyCondition": _form["propertyCondition"],
        "business": _form["business"],
        "similarUnitsAvailable": _form["similar"],
      },
      "slots": _slotsController.text.trim(),
      "addOthertags": _directionsController.text.trim(),
    });

    // Mirror into main draft
    final provider = ref.read(commercialDraftProvider);
    provider.update(() {
      provider.draft.otherFeatures = {
        "parking": _form["parking"],
        "powerBackup": _form["powerBackup"],
        "lift": _form["lift"],
        "washroom": _form["washroom"],
        "waterStorage": _form["waterStorage"],
        "security": _form["security"],
        "propertyCondition": _form["propertyCondition"],
        "business": _form["business"],
        "similarUnitsAvailable": _form["similar"],
      };
      provider.draft.slots = _slotsController.text.trim();
    });

    if (!mounted) return;
    Navigator.pushNamed(context, "/commercialPhotos");
  }

  /// Progress bar � 5 of 7 segments filled
  Widget _progressBar() {
    const int total = 7;
    const int current = 5;
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

  /// White card with border + soft shadow
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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

  /// Small all-caps section label
  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: kLabelText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          if (required)
            const Text(
              " *",
              style: TextStyle(
                color: Color(0xFF9AA0AC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  /// Shared input decoration
  InputDecoration _inputDec({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
      filled: true,
      fillColor: kInputBg,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  /// Dropdown field
  Widget _buildDropdown(
    String label,
    String key,
    List<String> items, {
    bool required = false,
  }) {
    final currentValue = items.contains(_form[key])
        ? _form[key] as String
        : null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          DropdownButtonFormField<String>(
            value: currentValue,
            hint: const Text(
              "Select",
              style: TextStyle(color: kSecondaryText, fontSize: 14),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kSecondaryText,
            ),
            dropdownColor: kCardBg,
            style: const TextStyle(
              color: kPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDec(),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    color: kPrimaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (v) => _update(key, v),
          ),
        ],
      ),
    );
  }

  /// Text / number input field
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    required String formKey,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    bool required = false,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboard,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              color: kPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDec(hint: hint ?? "Enter $label"),
            onChanged: (v) => _update(formKey, v),
          ),
        ],
      ),
    );
  }

  /// "Similar Units Available?" � Yes / No toggle chips
  Widget _buildSimilarUnits() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Similar Units Available?"),
          Row(
            children: [
              _choiceChip("No", false),
              const SizedBox(width: 10),
              _choiceChip("Yes", true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool chipValue) {
    final selected = _form["similar"] == chipValue;
    return GestureDetector(
      onTap: () => _update("similar", chipValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kAccentBlue : kInputBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? kAccentBlue : kBorderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kPrimaryText,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // -- Build ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kScaffoldBg,

        // -- AppBar ---------------------------------------------------------
        appBar: AppBar(
          backgroundColor: kCardBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
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
            "Amenities",
            style: TextStyle(
              color: kPrimaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "5 / 7",
                  style: TextStyle(
                    color: kSecondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _progressBar(),
            ),
          ),
        ),

        // -- Body -----------------------------------------------------------
        body: _dataLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: kAccentBlue,
                  strokeWidth: 2,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Power Backup
                          _buildDropdown("Power Backup", "powerBackup", const [
                            "None",
                            "Partial Backup",
                            "Full Backup",
                            "DG Backup",
                          ], required: true),

                          // Lift
                          _buildDropdown("Lift", "lift", const [
                            "None",
                            "Personal",
                            "Common",
                          ], required: true),

                          // Parking
                          _buildDropdown("Parking", "parking", const [
                            "None",
                            "Public",
                            "Reserved",
                            "Public And Reserved",
                          ], required: true),

                          // Washroom
                          _buildDropdown("Washroom(s)", "washroom", const [
                            "None",
                            "Shared",
                            "Private",
                          ], required: true),

                          // No. of Available Slots
                          _buildTextField(
                            "No. of Available Slots",
                            _slotsController,
                            formKey: "slots",
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            hint: "e.g. 4",
                          ),

                          // Water Storage
                          _buildDropdown(
                            "Water Storage Facility",
                            "waterStorage",
                            const [
                              "No Storage",
                              "Overhead Tank",
                              "Underground Tank",
                              "24/7 Water Supply",
                            ],
                          ),

                          // Security
                          _buildDropdown("Security", "security", const [
                            "No Security",
                            "Security Guard",
                            "CCTV",
                            "Gated Security",
                            "24/7 Security",
                          ]),

                          // Current Property Condition
                          _buildDropdown(
                            "Current Situation of Property",
                            "propertyCondition",
                            const [
                              "Vacant",
                              "Currently rented/leased",
                              "Own Business",
                              "New Property",
                            ],
                          ),

                          // Current Running Business
                          _buildDropdown(
                            "What Business is Currently Running?",
                            "business",
                            const [
                              "None",
                              "Office",
                              "Restaurant/Cafe",
                              "Store/Showroom",
                              "Cloud Kitchen",
                              "Clinic",
                              "School/Institute",
                              "Industrial Use",
                              "Other Business",
                            ],
                          ),

                          // Similar Units Available
                          _buildSimilarUnits(),

                          // Directions to Property
                          _buildTextField(
                            "Directions to Property",
                            _directionsController,
                            formKey: "directions",
                            maxLines: 4,
                            hint:
                                "Eg: Take the road opposite to Amrita College, take right after 300m...",
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // -- Sticky Save & Continue Button ----------------------
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
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
      ),
    );
  }
}
