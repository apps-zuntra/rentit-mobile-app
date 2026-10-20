// FlatmateRentScreen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rentit/providers/FlatmateDraftProvider.dart';
import 'package:rentit/screen/Flatmate/Flatmate/FlatmateAmenities.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------------------------------------------------------
// void main() / MyApp kept exactly as original � no logic change
// -----------------------------------------------------------------------------
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rent Form',
      theme: ThemeData(primarySwatch: Colors.red, fontFamily: 'Roboto'),
      home: const FlatmateRentScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET
// -----------------------------------------------------------------------------
class FlatmateRentScreen extends ConsumerStatefulWidget {
  const FlatmateRentScreen({super.key});

  @override
  ConsumerState<FlatmateRentScreen> createState() => _FlatmateRentScreenState();
}

class _FlatmateRentScreenState extends ConsumerState<FlatmateRentScreen> {
  // --- BASE URL ---------------------------------------------------------------
  static const String baseUrl = "https://rentit-backend-omega.vercel.app";

  // --- CONTROLLERS ------------------------------------------------------------
  final TextEditingController rentController = TextEditingController();
  final TextEditingController depositController = TextEditingController();
  final TextEditingController maintenanceAmountController =
      TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // --- VARIABLES --------------------------------------------------------------
  bool rentNegotiable = false;
  String maintenanceType = "Maintenance Extra";
  String furnishing = "Select";
  String parking = "Select";
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(flatmateDraftProvider).draft;
      setState(() {
        rentController.text = draft.expectedRent?.toString() ?? '';
        depositController.text = draft.expectedDeposit?.toString() ?? '';
        maintenanceAmountController.text =
            draft.maintenanceAmount?.toString() ?? '';
        descriptionController.text = draft.description ?? '';
        maintenanceType = draft.maintenanceType ?? "Maintenance Extra";
        furnishing = draft.furnishing ?? "Select";
        parking = draft.parking ?? "Select";
        selectedDate = draft.availableFrom;
      });
    });
  }

  // --- DROPDOWN LISTS ---------------------------------------------------------
  final List<String> maintenanceOptions = [
    "Maintenance Extra",
    "Maintenance Included",
  ];

  final List<String> furnishingOptions = [
    "Fully Furnished",
    "Semi Furnished",
    "Unfurnished",
  ];

  final List<String> parkingOptions = ["Bike", "Car", "Both", "None"];

  // --- DATE PICKER ------------------------------------------------------------
  Future<void> pickDate() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  bool _saveAndContinue() {
    if (rentController.text.trim().isEmpty) {
      _showSnack("Please enter expected rent");
      return false;
    }
    if (depositController.text.trim().isEmpty) {
      _showSnack("Please enter expected deposit");
      return false;
    }
    if (maintenanceType == "Maintenance Extra" &&
        maintenanceAmountController.text.trim().isEmpty) {
      _showSnack("Please enter maintenance amount");
      return false;
    }
    if (selectedDate == null) {
      _showSnack("Please select available from date");
      return false;
    }
    if (furnishing == "Select") {
      _showSnack("Please select furnishing");
      return false;
    }
    if (parking == "Select") {
      _showSnack("Please select parking");
      return false;
    }

    ref.read(flatmateDraftProvider).update(() {
      final draft = ref.read(flatmateDraftProvider).draft;
      draft.expectedRent = double.tryParse(rentController.text.trim());
      draft.expectedDeposit = double.tryParse(depositController.text.trim());
      draft.maintenanceType = maintenanceType;
      draft.maintenanceAmount = double.tryParse(
        maintenanceAmountController.text.trim(),
      );
      draft.availableFrom = selectedDate;
      draft.furnishing = furnishing;
      draft.parking = parking;
      draft.description = descriptionController.text.trim();
    });

    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static const Color _pageBg = Color(0xFFF2F2F7);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFE5E5EA);
  static const Color _labelColor = Color(0xFF8E8E93);
  static const Color _valueColor = Color(0xFF1D2F45);
  static const Color _hintColor = Color(0xFFC7C7CC);
  static const Color _iconColor = Color(0xFF8E8E93);
  static const Color _innerBg = Color(0xFFF9F9FB);
  static const Color _primaryDark = Color(0xFF1D2F45);

  // -- Outer section card ------------------------------------------------------
  Widget _outerCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    );
  }

  // -- UPPERCASE label ---------------------------------------------------------
  Widget _cardLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.65,
        color: _labelColor,
        height: 1,
      ),
    );
  }

  // -- Inner rounded field box (used inside each card) -------------------------
  Widget _innerBox({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: _innerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: child,
    );
  }

  // -- Money input inner box  (? prefix  +  optional /Month suffix) ------------
  Widget _moneyInputBox({
    required TextEditingController controller,
    required String hint,
    bool showMonthSuffix = false,
  }) {
    final textFieldBox = TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: _valueColor,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: _primaryDark,
      decoration: InputDecoration(
        filled: true,
        fillColor: _innerBg,
        prefixIcon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                "?",
                style: const TextStyle(
                  color: _iconColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintText: hint,
        hintStyle: const TextStyle(
          color: _hintColor,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cardBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryDark, width: 1),
        ),
      ),
    );

    if (showMonthSuffix) {
      return Row(
        children: [
          Expanded(child: textFieldBox),
          const SizedBox(width: 12),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _innerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder, width: 1),
            ),
            child: const Text(
              "/Month",
              style: TextStyle(
                color: _labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return textFieldBox;
  }

  // -- Dropdown inner box -------------------------------------------------------
  Widget _dropdownBox({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return _innerBox(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: (value == null || value == "Select") ? null : value,
          hint: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: 17, color: _hintColor),
                const SizedBox(width: 8),
              ],
              Text(
                hint,
                style: const TextStyle(
                  color: _hintColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (ctx) => items.map((e) {
            return Row(
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 17, color: _iconColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  e,
                  style: const TextStyle(
                    color: _valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            );
          }).toList(),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _iconColor,
            size: 20,
          ),
          dropdownColor: _cardBg,
          borderRadius: BorderRadius.circular(13),
          style: const TextStyle(
            color: _valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // -- Date inner box -----------------------------------------------------------
  Widget _dateBox() {
    return GestureDetector(
      onTap: pickDate,
      child: _innerBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedDate == null
                      ? "dd/mm/yyyy"
                      : DateFormat('dd/MM/yyyy').format(selectedDate!),
                  style: TextStyle(
                    color: selectedDate == null ? _hintColor : _valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_month_outlined,
                size: 19,
                color: _iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Description multiline inner box -----------------------------------------
  Widget _descriptionBox() {
    return _innerBox(
      child: TextField(
        controller: descriptionController,
        maxLines: 5,
        style: const TextStyle(
          color: _valueColor,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        cursorColor: _primaryDark,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
          hintText:
              "Write a few lines about your property which makes it special. "
              "Please do not mention your contact details in any format.",
          hintStyle: TextStyle(
            color: _hintColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  // -- AppBar -------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _pageBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            decoration: BoxDecoration(
              color: _cardBg,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: _primaryDark,
              size: 24,
            ),
          ),
        ),
      ),
      title: const Text(
        "Rent/Price details",
        style: TextStyle(
          color: _primaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              "4/7",
              style: TextStyle(
                color: _primaryDark.withOpacity(0.45),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -- 7-step progress bar ------------------------------------------------------
  Widget _buildProgressBar() {
    const int total = 7;
    const int completed = 4;
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i < total - 1 ? 2 : 0),
            decoration: BoxDecoration(
              color: i < completed ? _primaryDark : const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // -- Sticky save button -------------------------------------------------------
  Widget _buildSaveButton() {
    return Container(
      color: _cardBg,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          // CHANGE 3 � navigate only when saveData() returns true
          onPressed: () async {
            final success = _saveAndContinue();
            if (!mounted) return;
            if (success) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FlatmateAmenitiesScreen(),
                ),
              );
            }
          },
          child: const Text(
            "Save & Continue",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // -- Progress strip ---------------------------------------------
          _buildProgressBar(),

          // -- Scrollable form --------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- EXPECTED RENT --------------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("EXPECTED RENT*"),
                        const SizedBox(height: 10),
                        _moneyInputBox(
                          controller: rentController,
                          hint: "Enter Amount",
                          showMonthSuffix: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -- EXPECTED DEPOSIT -----------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("EXPECTED DEPOSIT*"),
                        const SizedBox(height: 10),
                        _moneyInputBox(
                          controller: depositController,
                          hint: "Enter Amount",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -- MONTHLY MAINTENANCE --------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("MONTHLY MAINTENANCE"),
                        const SizedBox(height: 10),
                        _dropdownBox(
                          value: maintenanceType,
                          hint: "Select",
                          items: maintenanceOptions,
                          onChanged: (v) {
                            setState(() {
                              maintenanceType = v!;
                              if (maintenanceType == "Maintenance Included") {
                                maintenanceAmountController.clear();
                              }
                            });
                          },
                        ),

                        // -- Maintenance Amount (conditional) ------------
                        if (maintenanceType == "Maintenance Extra") ...[
                          const SizedBox(height: 12),
                          _cardLabel("MAINTENANCE AMOUNT*"),
                          const SizedBox(height: 10),
                          _moneyInputBox(
                            controller: maintenanceAmountController,
                            hint: "Enter Amount",
                            showMonthSuffix: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -- AVAILABLE FROM -------------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("AVAILABLE FROM*"),
                        const SizedBox(height: 10),
                        _dateBox(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -- FURNISHING -----------------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("FURNISHING*"),
                        const SizedBox(height: 10),
                        _dropdownBox(
                          value: furnishing,
                          hint: "Select furnishing type",
                          items: furnishingOptions,
                          prefixIcon: Icons.chair_alt_outlined,
                          onChanged: (v) => setState(() => furnishing = v!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -- PARKING --------------------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("PARKING*"),
                        const SizedBox(height: 10),
                        _dropdownBox(
                          value: parking,
                          hint: "Select parking type",
                          items: parkingOptions,
                          prefixIcon: Icons.directions_car_outlined,
                          onChanged: (v) => setState(() => parking = v!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // -- PROPERTY DESCRIPTION -------------------------------
                  _outerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel("PROPERTY DESCRIPTION"),
                        const SizedBox(height: 10),
                        _descriptionBox(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // -- Sticky Save button -----------------------------------------
          _buildSaveButton(),
        ],
      ),
    );
  }
}
