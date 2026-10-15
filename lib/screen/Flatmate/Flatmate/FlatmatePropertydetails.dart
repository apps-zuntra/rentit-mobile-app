import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/providers/FlatmateDraftProvider.dart';
import 'package:rentit/screen/Flatmate/Flatmate/FlatmateLocationDetails.dart';


class FlatmatePropertyDetailsScreen extends ConsumerStatefulWidget {
  const FlatmatePropertyDetailsScreen({super.key});

  @override
  ConsumerState<FlatmatePropertyDetailsScreen> createState() =>
      _FlatmatePropertyDetailsScreenState();
}

class _FlatmatePropertyDetailsScreenState
    extends ConsumerState<FlatmatePropertyDetailsScreen> {
  // ----------------- FORM VALUES -----------------

  String? apartmentType;
  final TextEditingController apartmentNameController = TextEditingController();
  String? bhkType;
  String? floor;
  String? totalFloor;
  String? roomType;
  String? tenantType;
  String? propertyAge;
  String? facing;
  final TextEditingController builtUpAreaController = TextEditingController();

  // ----------------- DROPDOWN DATA -----------------

  final List<String> apartmentTypes = [
    'Apartment',
    'Independent House/Villa',
    'Gated Community Villa',
  ];

  final List<String> bhkTypes = [
    '1 RK',
    '1 BHK',
    '2 BHK',
    '3 BHK',
    '4 BHK',
    '4+ BHK',
  ];

  final List<String> floors = List.generate(99, (index) => '${index + 1}');

  final List<String> propertyAges = [
    '0-1 Years',
    '1-3 Years',
    '3-5 Years',
    '5+ Years',
  ];

  final List<String> facings = [
    'North',
    'South',
    'East',
    'West',
    'North-East',
    'North-West',
    'South-East',
    'South-West',
  ];

  // ----------------- LIFECYCLE -----------------

  @override
  void initState() {
    super.initState();
    // Pre-fill from draft if user is going back to edit this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(flatmateDraftProvider).draft;
      setState(() {
        apartmentType = draft.apartmentType;
        apartmentNameController.text = draft.apartmentName ?? '';
        bhkType = draft.bhkType;
        floor = draft.floor;
        totalFloor = draft.totalFloor;
        roomType = draft.roomType;
        tenantType = draft.tenantType;
        propertyAge = draft.propertyAge;
        facing = draft.facing;
        builtUpAreaController.text = draft.builtUpArea?.toString() ?? '';
      });
    });
  }

  @override
  void dispose() {
    apartmentNameController.dispose();
    builtUpAreaController.dispose();
    super.dispose();
  }

  // ----------------- VALIDATE & WRITE TO DRAFT -----------------

  void _saveAndContinue() {
    // -- Validation -----------------------------------------------------------
    if (roomType == null) {
      _showMsg("Please select room type");
      return;
    }
    if (tenantType == null) {
      _showMsg("Please select tenant type");
      return;
    }
    if (apartmentType == null) {
      _showMsg("Please select apartment type");
      return;
    }

    if (apartmentType == "Gated Community Villa" &&
        apartmentNameController.text.trim().isEmpty) {
      _showMsg("Please enter apartment name");
      return;
    }

    if (bhkType == null) {
      _showMsg("Please select BHK type");
      return;
    }

    if (builtUpAreaController.text.trim().isEmpty) {
      _showMsg("Please enter property size");
      return;
    }

    if (propertyAge == null) {
      _showMsg("Please select property age");
      return;
    }
    if (floor == null) {
      _showMsg("Please select floor");
      return;
    }
    if (totalFloor == null) {
      _showMsg("Please select total floor");
      return;
    }

    final floorValue = int.tryParse(floor!) ?? 0;
    final totalFloorValue = int.tryParse(totalFloor!) ?? 0;

    if (totalFloorValue <= floorValue) {
      _showMsg("Total Floor must be greater than Floor");
      return;
    }

    // -- Write into draft (no API call) ---------------------------------------
    ref.read(flatmateDraftProvider).update(() {
      final draft = ref.read(flatmateDraftProvider).draft;
      draft.apartmentType = apartmentType;
      draft.apartmentName = apartmentNameController.text.trim().isEmpty
          ? null
          : apartmentNameController.text.trim();
      draft.bhkType = bhkType;
      draft.floor = floor;
      draft.totalFloor = totalFloor;
      draft.roomType = roomType;
      draft.tenantType = tenantType;
      draft.propertyAge = propertyAge;
      draft.facing = facing;
      draft.builtUpArea = double.tryParse(builtUpAreaController.text.trim());
    });

    // -- Navigate to next screen -----------------------------------------------
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FlatmateLocationDetailsScreen()),
    );
  }

  // ----------------- HELPERS -----------------

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  // -------------------------------------------------------------------------
  //  UI DESIGN SYSTEM — matches the reference image exactly
  //
  //  Colors:
  //    • Page bg          : #F2F2F7  (iOS system grouped background)
  //    • Card bg          : #FFFFFF
  //    • Card border      : #E5E5EA
  //    • Label text       : #8E8E93  (uppercase, 11 sp, ls 0.6)
  //    • Value / hint     : #1C1C1E / #C7C7CC
  //    • Chevron / icons  : #8E8E93
  //    • Progress filled  : #1C1C1E
  //    • Save button      : #1C1C1E
  // -------------------------------------------------------------------------

  static const Color _pageBg = Color(0xFFF2F2F7);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFE5E5EA);
  static const Color _labelColor = Color(0xFF8E8E93);
  static const Color _valueColor = Color(0xFF1D2F45);
  static const Color _hintColor = Color(0xFFC7C7CC);
  static const Color _iconColor = Color(0xFF8E8E93);
  static const Color _primaryDark = Color(0xFF1D2F45);

  // -- Card wrapper ----------------------------------------------------------
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: child,
    );
  }

  // -- UPPERCASE section label inside card ----------------------------------
  Widget _cardLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: _labelColor,
        height: 1,
      ),
    );
  }

  // -- Dropdown field row (icon + hint/value + chevron) ---------------------
  //
  // Renders identically to the cards in the image:
  //   [prefix icon]  hint / selected value          [chevron ?]
  //
  Widget _dropdownField({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        hint: _hintRow(hint, prefixIcon),
        selectedItemBuilder: (_) =>
            items.map((e) => _selectedRow(e, prefixIcon)).toList(),
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
            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _hintRow(String hint, IconData? icon) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: _hintColor),
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
    );
  }

  Widget _selectedRow(String value, IconData? icon) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: _iconColor),
          const SizedBox(width: 8),
        ],
        Text(
          value,
          style: const TextStyle(
            color: _valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // -- Full labeled dropdown card --------------------------------------------
  Widget _dropdownCard({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardLabel(label),
          const SizedBox(height: 9),
          _dropdownField(
            hint: hint,
            value: value,
            items: items,
            onChanged: onChanged,
            prefixIcon: prefixIcon,
          ),
        ],
      ),
    );
  }

  // -- Text input card --------------------------------------------------------
  Widget _textInputCard({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardLabel(label),
          const SizedBox(height: 9),
          Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: 17, color: _hintColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    color: _valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  cursorColor: _primaryDark,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: _hintColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- AppBar -----------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _pageBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      // Circular back button
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
        'Property details',
        style: const TextStyle(
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
              '2/7',
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

  // -- 7-step progress strip --------------------------------------------------
  Widget _buildProgressBar() {
    const int totalSteps = 7;
    const int completedStep = 2; // page is step 2
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final bool done = i < completedStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 2 : 0),
              decoration: BoxDecoration(
                color: done ? _primaryDark : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // -- Bottom Save / Update button --------------------------------------------
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
          onPressed: _saveAndContinue,
          child: const Text(
            "Save and Continue",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // -- Progress strip directly below app bar --------------
          _buildProgressBar(),

          // -- Scrollable form ------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- ROOM TYPE ---------------------------------
                  _dropdownCard(
                    label: "ROOM TYPE*",
                    hint: "Select room type",
                    value: roomType,
                    items: const ["Single Room", "Shared Room"],
                    onChanged: (v) => setState(() => roomType = v),
                  ),

                  const SizedBox(height: 12),

                  // -- TENANT TYPE -------------------------------
                  _dropdownCard(
                    label: "TENANT TYPE*",
                    hint: "Select tenant type",
                    value: tenantType,
                    items: const ["Male", "Female", "Any"],
                    onChanged: (v) => setState(() => tenantType = v),
                  ),

                  const SizedBox(height: 12),

                  // -- APARTMENT TYPE ----------------------------
                  _dropdownCard(
                    label: "APARTMENT TYPE*",
                    hint: "Select apartment type",
                    value: apartmentType,
                    items: apartmentTypes,
                    prefixIcon: Icons.home_outlined,
                    onChanged: (value) {
                      setState(() {
                        apartmentType = value;
                        if (value != 'Gated Community Villa') {
                          apartmentNameController.clear();
                        }
                      });
                    },
                  ),

                  // -- APARTMENT NAME (Gated Community Villa only)
                  if (apartmentType == 'Gated Community Villa') ...[
                    const SizedBox(height: 12),
                    _textInputCard(
                      label: "APARTMENT NAME*",
                      hint: "Enter apartment name",
                      controller: apartmentNameController,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // -- BHK TYPE ----------------------------------
                  _dropdownCard(
                    label: "BHK TYPE*",
                    hint: "Select BHK type",
                    value: bhkType,
                    items: bhkTypes,
                    onChanged: (v) => setState(() => bhkType = v),
                  ),

                  const SizedBox(height: 12),

                  // -- PROPERTY SIZE -----------------------------
                  _textInputCard(
                    label: "PROPERTY SIZE*",
                    hint: "Built Up Area(Sq. Ft.)",
                    controller: builtUpAreaController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.description_outlined,
                  ),

                  const SizedBox(height: 12),

                  // -- FACING ------------------------------------
                  _dropdownCard(
                    label: "FACING",
                    hint: "Select",
                    value: facing,
                    items: facings,
                    prefixIcon: Icons.radio_button_unchecked_rounded,
                    onChanged: (v) => setState(() => facing = v),
                  ),

                  const SizedBox(height: 12),

                  // -- PROPERTY AGE ------------------------------
                  _dropdownCard(
                    label: "PROPERTY AGE*",
                    hint: "Select Property Age",
                    value: propertyAge,
                    items: propertyAges,
                    prefixIcon: Icons.star_border_rounded,
                    onChanged: (v) => setState(() => propertyAge = v),
                  ),

                  const SizedBox(height: 12),

                  // -- FLOOR + TOTAL FLOOR (side-by-side) ---------
                  _card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FLOOR
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // icon + label row
                              Row(
                                children: const [
                                  Icon(
                                    Icons.table_rows_outlined,
                                    size: 14,
                                    color: _labelColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "FLOOR*",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                      color: _labelColor,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(color: _cardBorder),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: floor,
                                    hint: const Text(
                                      "Select",
                                      style: TextStyle(
                                        color: _hintColor,
                                        fontSize: 15,
                                      ),
                                    ),
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
                                    ),
                                    items: floors
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() => floor = v),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // TOTAL FLOOR
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // icon + label row
                              Row(
                                children: const [
                                  Icon(
                                    Icons.table_rows_outlined,
                                    size: 14,
                                    color: _labelColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "TOTAL FLOOR*",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                      color: _labelColor,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(color: _cardBorder),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: totalFloor,
                                    hint: const Text(
                                      "Select",
                                      style: TextStyle(
                                        color: _hintColor,
                                        fontSize: 15,
                                      ),
                                    ),
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
                                    ),
                                    items: floors
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => totalFloor = v),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // -- Sticky Save / Update button ------------------------
          _buildSaveButton(),
        ],
      ),
    );
  }
}
