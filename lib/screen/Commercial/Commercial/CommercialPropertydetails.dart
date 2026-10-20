// CommercialPropertyDetails.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/model/model/commercial_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommercialPropertyDetailsScreen extends ConsumerStatefulWidget {
  const CommercialPropertyDetailsScreen({super.key});

  @override
  ConsumerState<CommercialPropertyDetailsScreen> createState() =>
      _CommercialPropertyDetailsScreenState();
}

class _CommercialPropertyDetailsScreenState
    extends ConsumerState<CommercialPropertyDetailsScreen> {
  static const String _apiBase = "https://rentit-backend-omega.vercel.app";

  // Form values
  final Map<String, String> _form = {
    "commercialPropertyType": "",
    "buildingType": "",
    "propertyAge": "",
    "floor": "",
    "totalFloor": "",
    "builtUpArea": "",
    "furnishing": "",
  };

  // Text controllers
  late final TextEditingController _floorController;
  late final TextEditingController _totalFloorController;
  late final TextEditingController _builtUpAreaController;

  // Other features
  final List<String> _otherFeatures = [];

  bool _isLoading = false;

  // Dropdown options
  static const List<String> _commercialPropertyTypes = [
    "Office Space",
    "Co-Working",
    "Shop",
    "Showroom",
    "Godown/Warehouse",
    "Industrial Shed",
    "Industrial Building",
    "Other business",
  ];

  static const List<String> _buildingTypes = [
    "Independent House",
    "Business Park",
    "Mall",
    "Standalone Building",
    "Independent Shop",
  ];

  static const List<String> _propertyAges = [
    "Less than a year",
    "1 to 3 years",
    "3 to 5 years",
    "5 to 10 years",
    "More than 10 years",
  ];

  static const List<String> _furnishingTypes = [
    "Fully Furnished",
    "Semi Furnished",
    "Unfurnished",
  ];

  static const List<String> _featureOptions = [
    "On Main Road",
    "Corner Property",
  ];

  static final List<String> _floorOptions = [
    "Ground",
    ...List.generate(100, (i) => (i + 1).toString()),
  ];

  static final List<String> _totalFloorOptions = [
    "Ground Only",
    ...List.generate(100, (i) => (i + 1).toString()),
  ];

  @override
  void initState() {
    super.initState();
    _floorController = TextEditingController();
    _totalFloorController = TextEditingController();
    _builtUpAreaController = TextEditingController();
    _loadCommercialData();
  }

  @override
  void dispose() {
    _floorController.dispose();
    _totalFloorController.dispose();
    _builtUpAreaController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // LOAD EXISTING DATA FOR EDIT
  // ----------------------------------------------------------
  Future<void> _loadCommercialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commercialId = prefs.getInt("commercialId");
      final token = prefs.getString("token");

      debugPrint("COMMERCIAL ID => $commercialId");
      debugPrint("TOKEN => $token");

      if (commercialId == null) {
        debugPrint("commercialId is null");
        return;
      }

      if (token == null) {
        debugPrint("token is null");
        return;
      }

      setState(() => _isLoading = true);

      final response = await http.get(
        Uri.parse("$_apiBase/commercial/$commercialId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("GET STATUS => ${response.statusCode}");
      debugPrint("GET BODY => ${response.body}");

      if (response.statusCode != 200) {
        _showSnack("Failed to load data");
        return;
      }

      final data = jsonDecode(response.body);

      _form["commercialPropertyType"] =
          data["commercialPropertyType"]?.toString() ?? "";
      _form["buildingType"] = data["buildingType"]?.toString() ?? "";
      _form["propertyAge"] = data["propertyAge"]?.toString() ?? "";

      if (data["furnishing"] is Map) {
        _form["furnishing"] = data["furnishing"]["type"]?.toString() ?? "";
      } else {
        _form["furnishing"] = data["furnishing"]?.toString() ?? "";
      }

      final f = data["floor"]?.toString() ?? "";
      _form["floor"] = f == "0" ? "Ground" : f;

      final tf = data["totalFloor"]?.toString() ?? "";
      _form["totalFloor"] = tf == "0" ? "Ground Only" : tf;

      _form["builtUpArea"] = data["builtUpArea"]?.toString() ?? "";

      _floorController.text = _form["floor"]!;
      _totalFloorController.text = _form["totalFloor"]!;
      _builtUpAreaController.text = _form["builtUpArea"]!;

      _otherFeatures.clear();
      if (data["commercialOtherFeatures"] is List) {
        _otherFeatures.addAll(
          List<String>.from(data["commercialOtherFeatures"]),
        );
      }

      debugPrint("FORM DATA => $_form");
      debugPrint("FEATURES => $_otherFeatures");

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("LOAD ERROR => $e");
      _showSnack("Error loading commercial details");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------
  // SAVE UPDATED DATA
  // ----------------------------------------------------------
  Future<void> _handleSubmit() async {
    if ((_form["commercialPropertyType"] ?? "").isEmpty ||
        (_form["buildingType"] ?? "").isEmpty ||
        (_form["propertyAge"] ?? "").isEmpty ||
        (_form["builtUpArea"] ?? "").isEmpty ||
        (_form["furnishing"] ?? "").isEmpty ||
        (_form["floor"] ?? "").isEmpty ||
        (_form["totalFloor"] ?? "").isEmpty) {
      _showSnack("Please fill all required fields");
      return;
    }

    int getFloorValue(String? val) {
      if (val == "Ground" || val == "Ground Only") return 0;
      return int.tryParse(val ?? "") ?? 0;
    }

    final floorValue = getFloorValue(_form["floor"]);
    final totalFloorValue = getFloorValue(_form["totalFloor"]);

    if (totalFloorValue < floorValue) {
      _showSnack("Total Floor must be greater than or equal to Floor");
      return;
    }

    final provider = ref.read(commercialDraftProvider);
    provider.update(() {
      provider.draft.commercialPropertyType = _form["commercialPropertyType"];
      provider.draft.buildingType = _form["buildingType"];
      provider.draft.propertyAge = _form["propertyAge"];
      provider.draft.floor = floorValue;
      provider.draft.totalFloor = totalFloorValue;
      provider.draft.builtUpArea = int.tryParse(_form["builtUpArea"] ?? "");
      provider.draft.furnishing = {"type": _form["furnishing"]};
      provider.draft.commercialOtherFeatures = {"features": _otherFeatures};
    });

    if (!mounted) return;
    Navigator.pushNamed(context, "/commercialLocationDetails");
  }

  // ----------------------------------------------------------
  // UTILITIES
  // ----------------------------------------------------------
  void _toggleFeature(String feature) {
    setState(() {
      if (_otherFeatures.contains(feature)) {
        _otherFeatures.remove(feature);
      } else {
        _otherFeatures.add(feature);
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  TextEditingController _controllerFor(String key) {
    switch (key) {
      case "floor":
        return _floorController;
      case "totalFloor":
        return _totalFloorController;
      case "builtUpArea":
        return _builtUpAreaController;
      default:
        return TextEditingController(text: _form[key] ?? "");
    }
  }

  // ----------------------------------------------------------
  // THEME CONSTANTS (matching reference image)
  // ----------------------------------------------------------
  static const Color _bgColor = Color(0xFFF5F5F5);
  static const Color _cardColor = Colors.white;
  static const Color _labelColor = Color(0xFF9E9E9E);
  static const Color _hintColor = Color(0xFFBDBDBD);
  static const Color _borderColor = Color(0xFFE0E0E0);
  static const Color _textColor = Color(0xFF212121);
  static const Color _btnColor = Color(0xFF2C3447);
  static const Color _progressActive = Color(0xFF2C3447);
  static const Color _progressInactive = Color(0xFFE0E0E0);
  static const Color _chipSelected = Color(0xFF2C3447);
  static const Color _chipUnselected = Colors.white;

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _btnColor))
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCard(
                          child: _buildDropdown(
                            label: "COMMERCIAL PROPERTY TYPE *",
                            key: "commercialPropertyType",
                            hint: "Select commercial property type",
                            items: _commercialPropertyTypes,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: _buildDropdown(
                            label: "BUILDING TYPE *",
                            key: "buildingType",
                            hint: "Select building type",
                            items: _buildingTypes,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: _buildDropdown(
                            label: "PROPERTY AGE *",
                            key: "propertyAge",
                            hint: "Select property age",
                            items: _propertyAges,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: _buildTextField(
                            label: "PROPERTY SIZE *",
                            key: "builtUpArea",
                            hint: "Built Up Area(Sq. Ft.)",
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: _buildDropdown(
                            label: "FURNISHING *",
                            key: "furnishing",
                            hint: "Select furnishing",
                            items: _furnishingTypes,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  label: "FLOOR *",
                                  key: "floor",
                                  hint: "Select",
                                  items: _floorOptions,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdown(
                                  label: "TOTAL FLOOR *",
                                  key: "totalFloor",
                                  hint: "Select",
                                  items: _totalFloorOptions,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "OTHER FEATURES",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _labelColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: _featureOptions.map((feature) {
                                  final selected = _otherFeatures.contains(
                                    feature,
                                  );
                                  return GestureDetector(
                                    onTap: () => _toggleFeature(feature),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? _chipSelected
                                            : _chipUnselected,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: selected
                                              ? _chipSelected
                                              : _borderColor,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        feature,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: selected
                                              ? Colors.white
                                              : _textColor,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  // ----------------------------------------------------------
  // APP BAR
  // ----------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: const Icon(Icons.chevron_left, color: _textColor, size: 22),
          onPressed: () => Navigator.maybePop(context),
          padding: EdgeInsets.zero,
        ),
      ),
      title: const Text(
        "Property Details",
        style: TextStyle(
          color: _textColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              "2 / 8",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // PROGRESS BAR
  // ----------------------------------------------------------
  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: List.generate(7, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: i < 2 ? _progressActive : _progressInactive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ----------------------------------------------------------
  // CARD WRAPPER
  // ----------------------------------------------------------
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
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

  // ----------------------------------------------------------
  // BOTTOM BUTTON
  // ----------------------------------------------------------
  Widget _buildBottomButton() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _btnColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "Save and Continue",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String key,
    required String hint,
    required List<String> items,
  }) {
    final currentValue = _form[key];

    final isValid =
        currentValue != null &&
        currentValue.isNotEmpty &&
        items.contains(currentValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _labelColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,

          // Important Fix
          value: isValid ? currentValue : null,

          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _hintColor,
            size: 22,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _btnColor, width: 1.5),
            ),
          ),
          hint: Text(
            hint,
            style: const TextStyle(
              color: _hintColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          style: const TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _form[key] = value ?? "";
            });
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // TEXT FIELD
  // ----------------------------------------------------------
  Widget _buildTextField({
    required String label,
    required String key,
    required String hint,
  }) {
    final controller = _controllerFor(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _labelColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _hintColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _btnColor, width: 1.5),
            ),
          ),
          onChanged: (value) {
            _form[key] = value;
          },
        ),
      ],
    );
  }
}
