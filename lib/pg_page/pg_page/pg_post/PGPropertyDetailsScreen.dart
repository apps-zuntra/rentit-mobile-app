// PGPropertyDetailsScreen.dart
import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/pg_page/pg_page/pg_post/PGLocationDetails.dart';
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

class PGPropertyDetailsScreen extends ConsumerStatefulWidget {
  final String selectedCity;
  const PGPropertyDetailsScreen({super.key, required this.selectedCity});

  @override
  ConsumerState<PGPropertyDetailsScreen> createState() =>
      _PGPropertyDetailsScreenState();
}

class _PGPropertyDetailsScreenState
    extends ConsumerState<PGPropertyDetailsScreen> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  // -- Controllers -------------------------------------------------------------
  final nameController = TextEditingController();
  final noticeController = TextEditingController();
  final landmarkController = TextEditingController();

  // -- State --------------------------------------------------------------------
  String? preferredTenant;
  String? preferredGuest;
  DateTime? availableFrom;
  TimeOfDay? gateClosingTime;
  bool loading = false;

  // -- Steps ------------------------------------------------------------------
  final List<Map<String, dynamic>> steps1 = [
    {"label": "Basic", "index": 0},
    {"label": "Property details", "index": 1},
    {"label": "Amenities", "index": 2},
    {"label": "Price details", "index": 3},
    {"label": "Photos", "index": 4},
    {"label": "Contact", "index": 5},
    {"label": "Verify", "index": 6},
  ];
  final int currentStep = 3;

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  @override
  void dispose() {
    nameController.dispose();
    noticeController.dispose();
    landmarkController.dispose();
    super.dispose();
  }

  // -- Load Existing Data -----------------------------------------------------
  Future<void> loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null || token == null) return;

    try {
      final res = await http.get(
        Uri.parse("$API_BASE/property/$propertyId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          nameController.text = data["propertyName"] ?? "";
          landmarkController.text = data["landmark"] ?? "";
          noticeController.text = data["noticePeriod"]?.toString() ?? "";

          if (data["preferredTenant"] != null &&
              data["preferredTenant"].isNotEmpty) {
            preferredTenant = data["preferredTenant"][0];
          }
          if (data["preferredGuests"] != null &&
              data["preferredGuests"].isNotEmpty) {
            preferredGuest = data["preferredGuests"][0];
          }
          if (data["availableFrom"] != null) {
            availableFrom = DateTime.parse(data["availableFrom"]);
          }
          if (data["gateClosingTime"] != null) {
            try {
              final raw = data["gateClosingTime"];
              if (raw.contains("T")) {
                final dt = DateTime.parse(raw);
                gateClosingTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
              } else {
                final parts = raw.split(":");
                gateClosingTime = TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                );
              }
            } catch (e) {
              debugPrint("? gate time parse error: $e");
            }
          }
        });
      }
    } catch (e) {
      debugPrint("? property load error: $e");
    }
  }

  // -- API Call ---------------------------------------------------------------
  Future<void> handleNext() async {
    if (nameController.text.trim().isEmpty) {
      _showSnack("Please enter Property Name");
      return;
    }

    if (preferredTenant == null || preferredTenant!.isEmpty) {
      _showSnack("Please select Preferred Tenant");
      return;
    }

    if (preferredGuest == null || preferredGuest!.isEmpty) {
      _showSnack("Please select Preferred Guests");
      return;
    }

    if (availableFrom == null) {
      _showSnack("Please select Available From date");
      return;
    }

    if (noticeController.text.trim().isEmpty) {
      _showSnack("Please enter Notice Period");
      return;
    }

    if (gateClosingTime == null) {
      _showSnack("Please select Gate Closing Time");
      return;
    }

    final draftProvider = ref.read(pgDraftProvider);

    draftProvider.update(() {
      draftProvider.draft.propertyName = nameController.text.trim();
      draftProvider.draft.preferredTenant = preferredTenant != null
          ? [preferredTenant!]
          : [];
      draftProvider.draft.preferredGuests = preferredGuest != null
          ? [preferredGuest!]
          : [];
      draftProvider.draft.landmark = landmarkController.text.trim();
      draftProvider.draft.availableFrom = availableFrom;
      draftProvider.draft.noticePeriod = int.tryParse(
        noticeController.text.trim(),
      );
      draftProvider.draft.gateClosingTime =
          "${gateClosingTime!.hour.toString().padLeft(2, '0')}:"
          "${gateClosingTime!.minute.toString().padLeft(2, '0')}";
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PGLocationDetailsPage(selectedCity: widget.selectedCity),
      ),
    );
  }

  // -- Helpers ----------------------------------------------------------------
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

  /// Segmented progress bar � 4/7 filled
  Widget _progressBar() {
    const total = 7;
    const current = 3;
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
  InputDecoration _inputDec({String? hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
      filled: true,
      fillColor: kInputBg,
      prefixIcon: prefix,
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

  /// Preferred Tenant checkbox chip
  Widget _tenantChip(String label) {
    final isSelected = preferredTenant == label;
    return GestureDetector(
      onTap: () => setState(() => preferredTenant = label),
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
                color: isSelected ? kAccentBlue : kBorderColor,
                width: 1.5,
              ),
              color: isSelected ? kAccentBlue : kInputBg,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? kPrimaryText : kSecondaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// Preferred Guests Dropdown � restyled to match design tokens
  Widget _guestsDropdown() {
    final items = ["Students", "Working Professionals", "Anyone"];

    return DropdownButtonFormField2<String>(
      value: (preferredGuest == null || preferredGuest!.isEmpty)
          ? null
          : preferredGuest,
      isExpanded: true,
      decoration: _inputDec(
        hint: "Select preferred guests",
        prefix: const Icon(
          Icons.people_outline,
          size: 20,
          color: kSecondaryText,
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
        final isSelected = item == preferredGuest;
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
                  Icons.person_outline,
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
                  const Icon(Icons.check_rounded, size: 18, color: kAccentBlue),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => preferredGuest = value);
      },
    );
  }

  /// Date Picker Field
  Widget _datePicker() {
    final display = availableFrom != null
        ? "${availableFrom!.day.toString().padLeft(2, '0')}/"
              "${availableFrom!.month.toString().padLeft(2, '0')}/"
              "${availableFrom!.year}"
        : "DD / MM / YYYY";

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
          initialDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: kAccentBlue),
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => availableFrom = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: kInputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                color: availableFrom != null ? kPrimaryText : kSecondaryText,
                fontWeight: availableFrom != null
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: kSecondaryText,
            ),
          ],
        ),
      ),
    );
  }

  /// Notice Period Field
  Widget _noticePeriodField() {
    return Container(
      decoration: BoxDecoration(
        color: kInputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: noticeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              cursorColor: kAccentBlue,
              style: const TextStyle(
                fontSize: 14,
                color: kPrimaryText,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: "e.g. 15",
                hintStyle: TextStyle(color: kSecondaryText, fontSize: 14),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(left: BorderSide(color: kBorderColor)),
            ),
            child: const Center(
              child: Text(
                "Days",
                style: TextStyle(
                  fontSize: 13,
                  color: kAccentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gate Closing Time Field
  Widget _gateTimePicker() {
    final hasValue = gateClosingTime != null;
    final display = hasValue
        ? gateClosingTime!.format(context)
        : "Select closing time";

    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: gateClosingTime ?? const TimeOfDay(hour: 22, minute: 0),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: kAccentBlue),
            ),
            child: child!,
          ),
        );
        if (time != null) setState(() => gateClosingTime = time);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: kInputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue ? kAccentBlue : kBorderColor,
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 20,
              color: kSecondaryText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue ? kPrimaryText : kSecondaryText,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: kSecondaryText),
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

      // -- AppBar -------------------------------------------------------------
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
          "PG Details",
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
                "3 / 8",
                style: TextStyle(
                  color: kSecondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        // Segmented progress bar � 4/8 filled
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
                  // -- Property Name ----------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Property Name *"),
                        TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            color: kPrimaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDec(hint: "e.g. Zuntra PG"),
                        ),
                      ],
                    ),
                  ),

                  // -- Preferred Tenant --------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Preferred Tenant *"),
                        Row(
                          children: [
                            _tenantChip("Boys"),
                            const SizedBox(width: 24),
                            _tenantChip("Girls"),
                            const SizedBox(width: 24),
                            _tenantChip("Anyone"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // -- Preferred Guests --------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Preferred Guests *"),
                        _guestsDropdown(),
                      ],
                    ),
                  ),

                  // -- Available From ----------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_label("Available From *"), _datePicker()],
                    ),
                  ),

                  // -- Notice Period -----------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Notice Period *"),
                        _noticePeriodField(),
                      ],
                    ),
                  ),

                  // -- Gate Closing Time -------------------------------------
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Gate Closing Time *"),
                        _gateTimePicker(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // -- Sticky Save & Continue Button ------------------------------
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
