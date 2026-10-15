// ApartmentPricedetails.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// -- Design tokens � reference image ----------------------------------------
const Color _kScaffold = Color(0xFFFFFFFF);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE8ECF0);
const Color _kInputBg = Color(0xFFF8FAFC);
const Color _kInputBorder = Color(0xFFE4E9F0);
const Color _kLabelColor = Color(0xFF8A97A8);
const Color _kHintColor = Color(0xFFB0BAC5);
const Color _kPrimaryText = Color(0xFF1A2332);
const Color _kAccent = Color(0xFF2C3E50); // dark navy
const Color _kProgressFg = Color(0xFF2C3E50);
const Color _kProgressBg = Color(0xFFE4E9F0);
const Color _kRupeeBox = Color(0xFFF0F3F6);
const Color _kMonthTag = Color(0xFFF0F3F6);

class ApartmentRentalDetailsScreen extends ConsumerStatefulWidget {
  final int apartmentId;

  const ApartmentRentalDetailsScreen({super.key, required this.apartmentId});

  @override
  ConsumerState<ApartmentRentalDetailsScreen> createState() =>
      _ApartmentRentalDetailsScreenState();
}

class _ApartmentRentalDetailsScreenState
    extends ConsumerState<ApartmentRentalDetailsScreen> {
  // -- ALL EXISTING STATE � UNTOUCHED ------------------------------------------
  final String API_BASE = "https://rentit-backend-yti9.onrender.com";

  static const Color kPrimary = Color(0xff2F3E4D);
  static const Color kPrimaryLight = Color(0xff3d5166);
  static const Color kBackground = Color(0xfff0f2f5);
  static const Color kBorder = Color(0xffcccccc);
  static const Color kHint = Color(0xffaaaaaa);
  static const Color kLabel = Color(0xff444444);

  String rentType = "rent";
  String expectedRent = "";
  String deposit = "";
  String maintenanceAmount = "";
  String maintenance = "";
  String availableFrom = "";
  bool rentNegotiable = false;
  List<String> preferredTenant = [];
  String furnishing = "";
  String parking = "";
  String description = "";
  bool saving = false;

  final TextEditingController _rentCtrl = TextEditingController();
  final TextEditingController _depositCtrl = TextEditingController();
  final TextEditingController _maintenanceAmountCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();

  final List<String> tenants = [
    "Anyone",
    "Family",
    "Bachelor Male",
    "Bachelor Female",
    "Company",
  ];

  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    _maintenanceAmountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // -- ALL EXISTING LOGIC � UNTOUCHED ------------------------------------------
  void toggleTenant(String val) {
    setState(() {
      // Anyone clicked
      if (val == "Anyone") {
        if (preferredTenant.contains("Anyone")) {
          preferredTenant.clear(); // unselect all
        } else {
          preferredTenant = List.from(tenants); // select all
        }
        return;
      }

      // Other tenant clicked
      if (preferredTenant.contains(val)) {
        preferredTenant.remove(val);
      } else {
        preferredTenant.add(val);
      }

      // Remove Anyone if individual option changed
      preferredTenant.remove("Anyone");

      // If all individual tenants selected, auto select Anyone
      final otherTenants = tenants.where((e) => e != "Anyone").toList();

      if (otherTenants.every((e) => preferredTenant.contains(e))) {
        preferredTenant = List.from(tenants);
      }
    });
  }

  Future<void> handleSubmit() async {
    if (expectedRent.trim().isEmpty) {
      showSnack("Please enter Expected Rent");
      return;
    }

    if (deposit.trim().isEmpty) {
      showSnack("Please enter Expected Deposit");
      return;
    }

    if (maintenance == "Maintenance Extra" &&
        maintenanceAmount.trim().isEmpty) {
      showSnack("Please enter Maintenance Amount");
      return;
    }

    if (availableFrom.trim().isEmpty) {
      showSnack("Please select Available From date");
      return;
    }

    if (furnishing.trim().isEmpty) {
      showSnack("Please select Furnishing");
      return;
    }

    if (parking.trim().isEmpty) {
      showSnack("Please select Parking");
      return;
    }

    if (preferredTenant.isEmpty) {
      showSnack("Please select Preferred Tenant");
      return;
    }
    try {
      setState(() => saving = true);

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
        "rentType": rentType,
        if (expectedRent.trim().isNotEmpty)
          "expectedRent": int.tryParse(expectedRent),
        if (deposit.trim().isNotEmpty) "deposit": int.tryParse(deposit),
        if (maintenance == "Maintenance Extra" &&
            maintenanceAmount.trim().isNotEmpty)
          "maintenanceAmount": int.tryParse(maintenanceAmount),
        if (maintenance.trim().isNotEmpty) "maintenance": maintenance.trim(),
        "rentNegotiable": rentNegotiable,
        if (availableFrom.trim().isNotEmpty)
          "availableFrom": availableFrom.trim(),
        if (preferredTenant.isNotEmpty) "preferredTenant": preferredTenant,
        if (furnishing.trim().isNotEmpty) "furnishing": furnishing.trim(),
        if (parking.trim().isNotEmpty) "parking": parking.trim(),
        if (description.trim().isNotEmpty) "description": description.trim(),
      };

      print("?? APARTMENT ID => $apartmentId");
      print("?? TOKEN => $token");
      print("?? PAYLOAD => ${jsonEncode(payload)}");

      final res = await http.put(
        Uri.parse("$API_BASE/apartment/$apartmentId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      print("?? STATUS => ${res.statusCode}");
      print("?? BODY => ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        showSnack("Saved Successfully ??");
        if (mounted) {
          Navigator.pushNamed(
            context,
            "/apartmentAmenities",
            arguments: {"apartmentId": widget.apartmentId},
          );
        }
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        showSnack(
          "Unauthorized. This apartment does not belong to the logged-in user.",
        );
      } else {
        final data = jsonDecode(res.body);
        showSnack(data["message"]?.toString() ?? "Failed to save property");
      }
    } catch (e) {
      print("ERROR ?? $e");
      showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => saving = false);
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

      if (token == null || token.isEmpty) {
        showSnack("Please login again");
        return;
      }

      print("?? apartmentId: $apartmentId");
      print("?? token: $token");

      final response = await http.get(
        Uri.parse("$API_BASE/apartment/$apartmentId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("?? STATUS: ${response.statusCode}");
      print("?? BODY: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          rentType = data["rentType"]?.toString() ?? "rent";
          expectedRent = data["expectedRent"]?.toString() ?? "";
          deposit = data["deposit"]?.toString() ?? "";
          maintenance = data["maintenance"]?.toString() ?? "";
          maintenanceAmount = data["maintenanceAmount"]?.toString() ?? "";
          availableFrom = data["availableFrom"]?.toString() ?? "";
          rentNegotiable = data["rentNegotiable"] == true;
          preferredTenant = data["preferredTenant"] != null
              ? List<String>.from(data["preferredTenant"])
              : [];
          furnishing = data["furnishing"]?.toString() ?? "";
          parking = data["parking"]?.toString() ?? "";
          description = data["description"]?.toString() ?? "";

          _rentCtrl.text = expectedRent;
          _depositCtrl.text = deposit;
          _maintenanceAmountCtrl.text = maintenanceAmount;
          _descriptionCtrl.text = description;
        });

        print("? Apartment price details loaded successfully");
      } else if (response.statusCode == 401) {
        debugPrint("? Unauthorized");
        showSnack("Unauthorized. Please login again.");
      } else {
        debugPrint("? Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("? loadExistingData() error: $e");
    }
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

  // ----------------------------------------------------------------------------
  // UI HELPERS � redesigned to match reference image
  // ----------------------------------------------------------------------------

  /// Segmented progress bar � 4 of 7 filled
  Widget _progressBar() {
    const total = 7;
    const current = 4;
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

  /// Card wrapper
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

  /// Input decoration � light fill, rounded, subtle border
  InputDecoration _inputDec({String? hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHintColor, fontSize: 14),
      filled: true,
      fillColor: _kInputBg,
      prefixIcon: prefix,
      prefixIconConstraints: prefix != null
          ? const BoxConstraints(minWidth: 40)
          : null,
      suffixIcon: suffix,
      suffixIconConstraints: suffix != null
          ? const BoxConstraints(minHeight: 48)
          : null,
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

  /// Rupee prefix box � matches reference SVG (rupee with divider)
  Widget get _rupeePrefix {
    return Container(
      width: 44,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "?",
            style: TextStyle(
              color: _kLabelColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 18, color: _kInputBorder),
        ],
      ),
    );
  }

  /// /Month suffix tag � matches reference SVG (filled background flush right)
  Widget get _monthSuffix {
    return Container(
      width: 70,
      decoration: const BoxDecoration(
        color: _kMonthTag,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        "/Month",
        style: TextStyle(
          color: _kLabelColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Dropdown styled to match reference
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

  /// Date picker field styled as dropdown � matches reference
  Widget _datePicker() {
    final displayText = availableFrom.isNotEmpty
        ? availableFrom.split("T").first
        : null;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 730)),
          builder: (ctx, child) => Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: const ColorScheme.light(primary: _kAccent)),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            availableFrom =
                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          });
        }
      },
      child: AbsorbPointer(
        child: TextField(
          readOnly: true,
          style: TextStyle(
            color: displayText != null ? _kPrimaryText : _kHintColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDec(
            hint: "dd/mm/yyyy",
            suffix: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _kLabelColor,
            ),
          ),
          controller: TextEditingController(text: displayText ?? ""),
        ),
      ),
    );
  }

  /// Preferred tenants � 2-column checkbox grid matching reference
  Widget _preferredTenantsGrid() {
    // Build rows of 2
    final List<List<String>> rows = [];
    for (int i = 0; i < tenants.length; i += 2) {
      rows.add(
        tenants.sublist(i, (i + 2) > tenants.length ? tenants.length : i + 2),
      );
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: row.map((t) {
              final selected = preferredTenant.contains(t);
              return Expanded(
                child: GestureDetector(
                  onTap: () => toggleTenant(t),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: selected,
                          onChanged: (_) => toggleTenant(t),
                          activeColor: _kAccent,
                          side: const BorderSide(
                            color: _kCardBorder,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          t,
                          style: const TextStyle(
                            color: _kPrimaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
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
          "Rent Details",
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
                "4 / 7",
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
          // -- Scrollable form ---------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Rent Type (hidden in reference but kept for logic) --
                  // Shown as a compact inline row, not a full card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: "rent",
                          groupValue: rentType,
                          activeColor: _kAccent,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setState(() => rentType = v!),
                        ),
                        const Text(
                          "Only Rent",
                          style: TextStyle(
                            fontSize: 14,
                            color: _kPrimaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Radio<String>(
                          value: "lease",
                          groupValue: rentType,
                          activeColor: _kAccent,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setState(() => rentType = v!),
                        ),
                        const Text(
                          "Only Lease",
                          style: TextStyle(
                            fontSize: 14,
                            color: _kPrimaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -- Expected Rent card (with Negotiable checkbox) --------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Expected Rent", required: true),
                        TextField(
                          keyboardType: TextInputType.number,
                          controller: _rentCtrl,
                          style: const TextStyle(
                            color: _kPrimaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDec(
                            hint: "Enter Amount",
                            prefix: _rupeePrefix,
                            suffix: _monthSuffix,
                          ),
                          onChanged: (v) => expectedRent = v,
                        ),
                        const SizedBox(height: 12),
                        // Negotiable checkbox inline
                        GestureDetector(
                          onTap: () =>
                              setState(() => rentNegotiable = !rentNegotiable),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: rentNegotiable,
                                  onChanged: (v) => setState(
                                    () => rentNegotiable = v ?? false,
                                  ),
                                  activeColor: _kAccent,
                                  side: const BorderSide(
                                    color: _kCardBorder,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Negotiable",
                                style: TextStyle(
                                  color: _kPrimaryText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -- Expected Deposit card --------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Expected Deposit", required: true),
                        TextField(
                          keyboardType: TextInputType.number,
                          controller: _depositCtrl,
                          style: const TextStyle(
                            color: _kPrimaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDec(
                            hint: "Enter Amount",
                            prefix: _rupeePrefix,
                          ),
                          onChanged: (v) => deposit = v,
                        ),
                      ],
                    ),
                  ),

                  // -- Monthly Maintenance card -----------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Monthly Maintenance"),
                        _styledDropdown(
                          value: maintenance,
                          items: const [
                            "Maintenance Included",
                            "Maintenance Extra",
                          ],
                          hint: "Select",
                          onChanged: (v) {
                            setState(() {
                              maintenance = v;
                              if (v != "Maintenance Extra") {
                                maintenanceAmount = "";
                              }
                            });
                          },
                        ),
                        // Maintenance Amount � appears inline when Extra
                        if (maintenance == "Maintenance Extra") ...[
                          const SizedBox(height: 14),
                          _label("Maintenance Amount", required: true),
                          TextField(
                            keyboardType: TextInputType.number,
                            controller: _maintenanceAmountCtrl,
                            style: const TextStyle(
                              color: _kPrimaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDec(
                              hint: "Enter Amount",
                              prefix: _rupeePrefix,
                            ),
                            onChanged: (v) => maintenanceAmount = v,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // -- Available From card ----------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Available From", required: true),
                        _datePicker(),
                      ],
                    ),
                  ),

                  // -- Furnishing card --------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Furnishing", required: true),
                        _styledDropdown(
                          value: furnishing,
                          items: const [
                            "Fully furnished",
                            "Semi-furnished",
                            "Unfurnished",
                          ],
                          hint: "Select furnishing type",
                          onChanged: (v) => setState(() => furnishing = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Parking card -----------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Parking", required: true),
                        _styledDropdown(
                          value: parking,
                          items: const ["Bike", "Car", "Both", "None"],
                          hint: "Select parking type",
                          onChanged: (v) => setState(() => parking = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Preferred Tenants card (2-column checkbox grid) ------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Preferred Tenants", required: true),
                        const SizedBox(height: 2),
                        _preferredTenantsGrid(),
                      ],
                    ),
                  ),

                  // -- Property Description card ----------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Property Description"),
                        TextField(
                          maxLines: 4,
                          controller: _descriptionCtrl,
                          style: const TextStyle(
                            color: _kPrimaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: _inputDec(
                            hint:
                                "Write a few lines about your property which makes it special. Please do not mention your contact details in any format.",
                          ),
                          onChanged: (v) => description = v,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // -- Sticky Save & Continue button ------------------------------
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
                onPressed: saving ? null : handleSubmit,
                child: saving
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
