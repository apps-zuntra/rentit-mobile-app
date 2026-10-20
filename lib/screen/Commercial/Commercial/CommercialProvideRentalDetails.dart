// CommercialProvideRentalDetails.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/model/model/commercial_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Design Tokens (Reference Image: Light / White theme) ------------------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50); // dark navy � CTA button
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kChipSelected = Color(0xFF2C3E50);
const Color kChipText = Colors.white;
const Color kCurrencyIcon = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);

// -- API --------------------------------------------------------------------
class CommercialProvideRentalDetails extends ConsumerStatefulWidget {
  const CommercialProvideRentalDetails({super.key});

  @override
  ConsumerState<CommercialProvideRentalDetails> createState() =>
      _CommercialProvideRentalDetailsState();
}

class _CommercialProvideRentalDetailsState
    extends ConsumerState<CommercialProvideRentalDetails> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  bool loading = false;
  bool dataLoading = true;

  // -- Controllers ------------------------------------------------------------
  late TextEditingController expectedRentCtrl;
  late TextEditingController depositCtrl;
  late TextEditingController maintenanceCtrl;
  late TextEditingController otherTagsCtrl;

  // -- Form State -------------------------------------------------------------
  final Map<String, dynamic> form = {
    "expectedRent": "",
    "deposit": "",
    "rentNegotiable": false,
    "depositNegotiable": false,
    "maintenanceExtra": false,
    "maintenanceAmount": "",
    "leaseDuration": "",
    "lockinPeriod": "",
    "availableFrom": "",
    "idealFor": <String>[],
    "addOthertags": "",
  };

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    expectedRentCtrl = TextEditingController();
    depositCtrl = TextEditingController();
    maintenanceCtrl = TextEditingController();
    otherTagsCtrl = TextEditingController();
    loadExistingData();
  }

  @override
  void dispose() {
    expectedRentCtrl.dispose();
    depositCtrl.dispose();
    maintenanceCtrl.dispose();
    otherTagsCtrl.dispose();
    super.dispose();
  }

  // -- Load Existing Data -----------------------------------------------------
  Future<void> loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final propertyId = prefs.getInt("commercialId");
      final token = prefs.getString("token");

      if (propertyId == null || token == null) {
        if (mounted) setState(() => dataLoading = false);
        return;
      }

      final res = await http.get(
        Uri.parse("$API_BASE/commercial/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("?? RENTAL RESPONSE => ${res.body}");

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => dataLoading = false);
        return;
      }

      final data = jsonDecode(res.body);

      setState(() {
        form["expectedRent"] = data["expectedRent"]?.toString() ?? "";
        form["deposit"] = data["deposit"]?.toString() ?? "";
        form["maintenanceAmount"] = data["maintenanceAmount"]?.toString() ?? "";

        expectedRentCtrl.text = form["expectedRent"];
        depositCtrl.text = form["deposit"];
        maintenanceCtrl.text = form["maintenanceAmount"];

        form["rentNegotiable"] = data["rentNegotiable"] ?? false;
        form["depositNegotiable"] = data["depositNegotiable"] ?? false;
        form["maintenanceExtra"] = data["maintenanceExtra"] ?? false;

        form["leaseDuration"] = data["leaseDuration"]?.toString() ?? "";
        form["lockinPeriod"] = data["lockinPeriod"]?.toString() ?? "";

        final rawDate = data["availableFrom"]?.toString() ?? "";
        form["availableFrom"] = rawDate.length >= 10
            ? rawDate.substring(0, 10)
            : rawDate;

        if (data["idealFor"] is Map && data["idealFor"]["types"] is List) {
          form["idealFor"] = List<String>.from(data["idealFor"]["types"]);
        } else if (data["idealFor"] is List) {
          form["idealFor"] = List<String>.from(data["idealFor"]);
        } else {
          form["idealFor"] = <String>[];
        }

        form["addOthertags"] = data["addOthertags"]?.toString() ?? "";
        otherTagsCtrl.text = form["addOthertags"];

        dataLoading = false;
      });

      final provider = ref.read(commercialDraftProvider);

      provider.update(() {
        provider.draft.expectedRent = data["expectedRent"];

        provider.draft.deposit = data["deposit"];

        provider.draft.maintenanceAmount = data["maintenanceAmount"];

        provider.draft.rentNegotiable = data["rentNegotiable"] ?? false;

        provider.draft.depositNegotiable = data["depositNegotiable"] ?? false;

        provider.draft.maintenanceExtra = data["maintenanceExtra"] ?? false;

        provider.draft.leaseDuration = data["leaseDuration"]?.toString();

        provider.draft.lockinPeriod = data["lockinPeriod"]?.toString();

        provider.draft.availableFrom = data["availableFrom"] != null
            ? DateTime.tryParse(data["availableFrom"])
            : null;

        provider.draft.idealFor = data["idealFor"] is List
            ? List<String>.from(data["idealFor"])
            : [];

        provider.draft.addOthertags = data["addOthertags"]?.toString();
      });
    } catch (e) {
      debugPrint("? Rental load error => $e");
      if (mounted) setState(() => dataLoading = false);
    }
  }

  // -- Helpers ----------------------------------------------------------------
  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: kAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void update(String key, dynamic value) => setState(() => form[key] = value);

  void toggleIdeal(String value) {
    setState(() {
      final List<String> current = List<String>.from(form["idealFor"]);
      current.contains(value) ? current.remove(value) : current.add(value);
      form["idealFor"] = current;
    });
  }

  // -- Submit -----------------------------------------------------------------
  Future<void> handleSubmit() async {
    if (form["expectedRent"].toString().trim().isEmpty) {
      showSnack("Please enter Expected Rent");
      return;
    }

    if (form["deposit"].toString().trim().isEmpty) {
      showSnack("Please enter Expected Deposit");
      return;
    }

    if (form["availableFrom"].toString().trim().isEmpty) {
      showSnack("Please select Available From");
      return;
    }

    if (form["maintenanceExtra"] == true &&
        form["maintenanceAmount"].toString().trim().isEmpty) {
      showSnack("Please enter Monthly Maintenance Amount");
      return;
    }

    final provider = ref.read(commercialDraftProvider);
    provider.update(() {
      provider.draft.expectedRent = int.tryParse(
        form["expectedRent"].toString(),
      );
      provider.draft.deposit = int.tryParse(form["deposit"].toString());
      provider.draft.maintenanceAmount = int.tryParse(
        form["maintenanceAmount"].toString(),
      );
      provider.draft.rentNegotiable = form["rentNegotiable"] ?? false;
      provider.draft.depositNegotiable = form["depositNegotiable"] ?? false;
      provider.draft.maintenanceExtra = form["maintenanceExtra"] ?? false;
      provider.draft.leaseDuration = form["leaseDuration"]?.toString();
      provider.draft.lockinPeriod = form["lockinPeriod"]?.toString();
      provider.draft.availableFrom = DateTime.tryParse(
        form["availableFrom"].toString(),
      );
      provider.draft.idealFor = List<String>.from(form["idealFor"]);
      provider.draft.addOthertags = form["addOthertags"]?.toString();
    });

    if (!mounted) return;
    Navigator.pushNamed(context, "/commercialAmenities");
  }
  // ---------------------------------------------------------------------------
  // UI HELPERS � matching reference image
  // ---------------------------------------------------------------------------

  /// Card wrapper used for every section
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

  /// Section label above fields
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

  InputDecoration _inputDec({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,

      prefixIcon: prefix,
      suffixIcon: suffix,

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1D2F45), width: 1.5),
      ),
    );
  }

  /// Currency prefix icon
  Widget get _rupeePrefix => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(
      "?",
      style: TextStyle(
        color: kCurrencyIcon,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  /// /Month suffix tag
  Widget get _monthSuffix => Container(
    margin: const EdgeInsets.all(6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: kDivider,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      "/Month",
      style: TextStyle(
        color: kSecondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  /// Number input field with currency icon
  Widget _numberField(
    String label,
    String key,
    TextEditingController ctrl, {
    bool showMonthSuffix = false,
    bool required = false,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: kPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDec(
              hint: "Enter Amount",
              prefix: _rupeePrefix,
              suffix: showMonthSuffix ? _monthSuffix : null,
            ),
            onChanged: (v) => update(key, v),
          ),
        ],
      ),
    );
  }

  /// Dropdown field
  Widget _dropdown(
    String label,
    String key,
    List<String> items, {
    bool required = false,
    String hint = "Select",
  }) {
    final currentValue = items.contains(form[key]) ? form[key] as String : null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          DropdownButtonFormField<String>(
            value: currentValue,
            hint: Text(
              hint,
              style: const TextStyle(color: kSecondaryText, fontSize: 14),
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
            decoration: _inputDec(hint: "Select"),
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
            onChanged: (value) => update(key, value ?? ""),
          ),
        ],
      ),
    );
  }

  /// Maintenance dropdown (Select / Maintenance Included / Maintenance Extra)
  Widget _maintenanceSection() {
    final items = ["Maintenance Included", "Maintenance Extra"];

    String? currentValue;

    if (form["maintenanceExtra"] == true) {
      currentValue = "Maintenance Extra";
    } else if (form["maintenanceExtra"] == false &&
        form["maintenanceAmount"].toString().isNotEmpty) {
      currentValue = "Maintenance Included";
    }

    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Monthly Maintenance"),
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
                decoration: _inputDec(hint: "Select"),
                items: items.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    form["maintenanceExtra"] = value == "Maintenance Extra";

                    // Maintenance Included select pannumbothu amount clear
                    if (value != "Maintenance Extra") {
                      form["maintenanceAmount"] = "";
                      maintenanceCtrl.clear();
                    }
                  });
                },
              ),
            ],
          ),
        ),

        if (form["maintenanceExtra"] == true)
          _numberField(
            "Monthly Maintenance Amount",
            "maintenanceAmount",
            maintenanceCtrl,
            required: true,
          ),
      ],
    );
  }

  /// Date picker field
  Widget _datePicker(String label, String key, {bool required = false}) {
    final displayText = (form[key] != null && form[key] != "")
        ? form[key] as String
        : null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          GestureDetector(
            onTap: () async {
              final currentDate = displayText != null
                  ? DateTime.tryParse(displayText) ?? DateTime.now()
                  : DateTime.now();

              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime(2035),
                initialDate: currentDate,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: kAccentBlue,
                        onPrimary: Colors.white,
                        surface: kCardBg,
                        onSurface: kPrimaryText,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                final formatted =
                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                update(key, formatted);
              }
            },
            child: AbsorbPointer(
              child: TextField(
                readOnly: true,
                style: TextStyle(
                  color: displayText != null ? kPrimaryText : kSecondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _inputDec(
                  hint: "dd/mm/yyyy",
                  suffix: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kSecondaryText,
                  ),
                ),
                controller: TextEditingController(text: displayText ?? ""),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Negotiable checkbox row (compact, matches reference)
  Widget _negotiableRow(String label, String key) {
    return GestureDetector(
      onTap: () => update(key, !(form[key] as bool)),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: form[key] == true,
              onChanged: (v) => update(key, v ?? false),
              activeColor: kAccentBlue,
              side: const BorderSide(color: kBorderColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: kSecondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Preferred Tenants / Ideal For multi-select checkboxes
  Widget _idealForSection() {
    final options = ["Bank", "Service Center", "Show Room", "ATM", "Retail"];

    // Split into rows of 2
    final List<List<String>> rows = [];
    for (int i = 0; i < options.length; i += 2) {
      rows.add(
        options.sublist(i, i + 2 > options.length ? options.length : i + 2),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Ideal For"),
          const SizedBox(height: 4),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: row.map((item) {
                  final selected = List<String>.from(
                    form["idealFor"],
                  ).contains(item);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => toggleIdeal(item),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: selected,
                              onChanged: (_) => toggleIdeal(item),
                              activeColor: kAccentBlue,
                              side: const BorderSide(
                                color: kBorderColor,
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
                              item,
                              style: const TextStyle(
                                color: kPrimaryText,
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
        ],
      ),
    );
  }

  /// Property description / other tags text area
  Widget _descriptionField() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Property Description / Other Tags"),
          TextField(
            controller: otherTagsCtrl,
            maxLines: 4,
            style: const TextStyle(
              color: kPrimaryText,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _inputDec(
              hint:
                  "Write a few lines about your property which makes it special. Please do not mention your contact details in any format.",
            ),
            onChanged: (v) => update("addOthertags", v),
          ),
        ],
      ),
    );
  }

  // -- Progress bar (4/7) -----------------------------------------------------
  Widget _progressBar() {
    const total = 7;
    const current = 4;
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

  // -- Build ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
          "Rent Details",
          style: TextStyle(
            color: kPrimaryText,
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
      body: dataLoading
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -- Expected Rent -----------------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Expected Rent", required: true),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: expectedRentCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: kPrimaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _inputDec(
                                    hint: "Enter Amount",
                                    prefix: _rupeePrefix,
                                    suffix: _monthSuffix,
                                  ),
                                  onChanged: (v) => update("expectedRent", v),
                                ),
                                const SizedBox(height: 12),
                                _negotiableRow("Negotiable", "rentNegotiable"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // -- Expected Deposit --------------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Expected Deposit", required: true),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: depositCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: kPrimaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _inputDec(
                                    hint: "Enter Amount",
                                    prefix: _rupeePrefix,
                                  ),
                                  onChanged: (v) => update("deposit", v),
                                ),
                                const SizedBox(height: 12),
                                _negotiableRow(
                                  "Negotiable",
                                  "depositNegotiable",
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // -- Monthly Maintenance -----------------------
                          _maintenanceSection(),

                          const SizedBox(height: 12),

                          // -- Available From ----------------------------
                          _datePicker(
                            "Available From",
                            "availableFrom",
                            required: true,
                          ),

                          const SizedBox(height: 12),

                          // -- Lease Duration ----------------------------
                          _dropdown(
                            "Lease Duration",
                            "leaseDuration",
                            ["1 year", "2 years", "3 years"],
                            hint: "Select lease duration",
                          ),

                          const SizedBox(height: 12),

                          // -- Lock-in Period ----------------------------
                          _dropdown(
                            "Lock-in Period",
                            "lockinPeriod",
                            ["6 months", "1 year"],
                            hint: "Select lock-in period",
                          ),

                          const SizedBox(height: 12),

                          // -- Ideal For ---------------------------------
                          _idealForSection(),

                          const SizedBox(height: 12),

                          // -- Property Description ----------------------
                          _descriptionField(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ), // -- Sticky Save & Continue Button -------------------------
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
