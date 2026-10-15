// lib/screen/Flatmate/FlatmateAmenities.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/providers/FlatmateDraftProvider.dart';
import 'package:rentit/screen/Flatmate/Flatmate/FlatmatePhotos.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------
// API Config  � UNCHANGED
// ---------------------------------------------
class _ApiConfig {
  static const String baseUrl = "https://rentit-backend-yti9.onrender.com";
  static const String flatmate = '$baseUrl/flatmate';
}

// ---------------------------------------------
// Model  � UNCHANGED
// ---------------------------------------------
class _FlatmateAmenitiesModel {
  final bool? attachedBathroom;
  final String? bathroomType;
  final bool? acRoom;
  final bool? balcony;
  final bool? nonVegAllowed;
  final bool? smokingAllowed;
  final bool? drinkingAllowed;
  final bool? gym;
  final bool? gatedSecurity;
  final String? whoShowsProperty;
  final String? secondaryNumber;
  final String? waterSupply;
  final String? directionsTip;
  final bool? liftSelected;
  final bool? swimmingPoolSelected;
  final bool? clubHouseSelected;
  final bool? powerBackupSelected;
  final bool? parkSelected;

  const _FlatmateAmenitiesModel({
    this.attachedBathroom,
    this.bathroomType,
    this.acRoom,
    this.balcony,
    this.nonVegAllowed,
    this.smokingAllowed,
    this.drinkingAllowed,
    this.gym,
    this.gatedSecurity,
    this.whoShowsProperty,
    this.secondaryNumber,
    this.waterSupply,
    this.directionsTip,
    this.liftSelected,
    this.swimmingPoolSelected,
    this.clubHouseSelected,
    this.powerBackupSelected,
    this.parkSelected,
  });

  Map<String, dynamic> toJson() => {
    'attachedBathroom': attachedBathroom,
    'bathroomType': bathroomType,
    'acRoom': acRoom,
    'balcony': balcony,
    'nonVegAllowed': nonVegAllowed,
    'smokingAllowed': smokingAllowed,
    'drinkingAllowed': drinkingAllowed,
    'gym': gym,
    'gatedSecurity': gatedSecurity,
    'whoShowsProperty': whoShowsProperty,
    'secondaryNumber': secondaryNumber,
    'waterSupply': waterSupply,
    'directionsTip': directionsTip,
    'liftSelected': liftSelected,
    'swimmingPoolSelected': swimmingPoolSelected,
    'clubHouseSelected': clubHouseSelected,
    'powerBackupSelected': powerBackupSelected,
    'parkSelected': parkSelected,
  };
}

// ---------------------------------------------
// Service  � UNCHANGED
// ---------------------------------------------
class _FlatmateService {
  Future<bool> updateAmenities({
    required int flatmateId,
    required _FlatmateAmenitiesModel data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Login token missing');
      }

      final response = await http.patch(
        Uri.parse('${_ApiConfig.flatmate}/$flatmateId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data.toJson()),
      );

      debugPrint('AMENITIES STATUS ?? ${response.statusCode}');
      debugPrint('AMENITIES RESPONSE ?? ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('updateAmenities error ?? $e');
      throw Exception(e.toString());
    }
  }
}

// ---------------------------------------------
// Screen
// ---------------------------------------------
class FlatmateAmenitiesScreen extends ConsumerStatefulWidget {
  const FlatmateAmenitiesScreen({super.key});

  @override
  ConsumerState<FlatmateAmenitiesScreen> createState() =>
      _FlatmateAmenitiesScreenState();
}

class _FlatmateAmenitiesScreenState
    extends ConsumerState<FlatmateAmenitiesScreen> {
  // -- Service -- UNCHANGED
  final _FlatmateService _service = _FlatmateService();

  // -- Room Details -- UNCHANGED
  bool? attachedBathroom;
  String bathroomType = 'Private Bathroom';
  bool? acRoom;
  bool? balcony;

  // -- Flatmate Preference -- UNCHANGED
  bool? nonVegAllowed;
  bool? smokingAllowed;
  bool? drinkingAllowed;

  // -- Other Details -- UNCHANGED
  bool? gym;
  bool? gatedSecurity;
  String? whoShowsProperty;
  final TextEditingController _secondaryNumberController =
      TextEditingController();
  String waterSupply = 'Both';
  final TextEditingController _directionsTipController =
      TextEditingController();

  // -- Amenities -- UNCHANGED
  bool liftSelected = false;
  bool swimmingPoolSelected = false;
  bool clubHouseSelected = false;
  bool powerBackupSelected = false;
  bool parkSelected = false;

  bool _showDirectionsTipPoster = true;

  // -------------------------------------------
  // DESIGN TOKENS � exact match to image
  // -------------------------------------------
  static const Color _pageBg = Color(0xFFF2F2F7);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFE5E5EA);
  static const Color _sectionLabel = Color(0xFF1D2F45);
  static const Color _rowLabel = Color(0xFF3C3C43);
  static const Color _iconColor = Color(0xFF8E8E93);
  static const Color _hintColor = Color(0xFFC7C7CC);
  static const Color _primaryDark = Color(0xFF1D2F45);
  static const Color _pillBorder = Color(0xFFD1D1D6);
  static const Color _tipBg = Color(0xFFEAF4FF);
  static const Color _tipBorder = Color(0xFF90CAF9);
  static const Color _tipText = Color(0xFF1565C0);
  static const Color _newBadge = Color(0xFFE8453C);
  static const Color _divider = Color(0xFFF2F2F7);

  // ---------------------------------------------
  // Lifecycle  � UNCHANGED
  // ---------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(flatmateDraftProvider).draft;
      setState(() {
        attachedBathroom = draft.attachedBathroom;
        bathroomType = draft.bathroomType ?? 'Private Bathroom';
        acRoom = draft.acRoom;
        balcony = draft.balcony;
        nonVegAllowed = draft.nonVegAllowed;
        smokingAllowed = draft.smokingAllowed;
        drinkingAllowed = draft.drinkingAllowed;
        gym = draft.gym;
        gatedSecurity = draft.gatedSecurity;
        liftSelected = draft.liftSelected;
        swimmingPoolSelected = draft.swimmingPoolSelected;
        clubHouseSelected = draft.clubHouseSelected;
        powerBackupSelected = draft.powerBackupSelected;
        parkSelected = draft.parkSelected;
        whoShowsProperty = draft.whoShowsProperty;
        waterSupply = draft.waterSupply ?? 'Both';
        _secondaryNumberController.text = draft.secondaryNumber ?? '';
        _directionsTipController.text = draft.directionsTip ?? '';
      });
    });
  }

  @override
  void dispose() {
    _secondaryNumberController.dispose();
    _directionsTipController.dispose();
    super.dispose();
  }

  // ---------------------------------------------
  // Load Existing Amenities Data  � UNCHANGED
  // ---------------------------------------------
  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flatmateId = prefs.getInt('flatmateId');
      final token = prefs.getString('token');

      debugPrint('LOAD flatmateId ?? $flatmateId');
      debugPrint('LOAD token ?? $token');

      if (flatmateId == null) return;
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${_ApiConfig.flatmate}/$flatmateId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('LOAD STATUS ?? ${response.statusCode}');
      debugPrint('LOAD BODY ?? ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          attachedBathroom = data['attachedBathroom'] ?? attachedBathroom;
          acRoom = data['acRoom'] ?? acRoom;
          balcony = data['balcony'] ?? balcony;
          nonVegAllowed = data['nonVegAllowed'] ?? nonVegAllowed;
          smokingAllowed = data['smokingAllowed'] ?? smokingAllowed;
          drinkingAllowed = data['drinkingAllowed'] ?? drinkingAllowed;
          gym = data['gym'] ?? gym;
          gatedSecurity = data['gatedSecurity'] ?? gatedSecurity;
          liftSelected = data['liftSelected'] ?? liftSelected;
          swimmingPoolSelected =
              data['swimmingPoolSelected'] ?? swimmingPoolSelected;
          clubHouseSelected = data['clubHouseSelected'] ?? clubHouseSelected;
          powerBackupSelected =
              data['powerBackupSelected'] ?? powerBackupSelected;
          parkSelected = data['parkSelected'] ?? parkSelected;
          if (data['bathroomType'] != null)
            bathroomType = data['bathroomType'].toString();
          if (data['whoShowsProperty'] != null)
            whoShowsProperty = data['whoShowsProperty'].toString();
          if (data['waterSupply'] != null)
            waterSupply = data['waterSupply'].toString();
          _secondaryNumberController.text =
              data['secondaryNumber']?.toString() ?? '';
          _directionsTipController.text =
              data['directionsTip']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('_loadExistingData error ?? $e');
    }
  }

  // ---------------------------------------------
  // Save & Continue  � UNCHANGED
  // ---------------------------------------------
  void _onSaveAndContinue() {
    if (attachedBathroom == null) {
      _showSnackBar('Select Attached Bathroom');
      return;
    }
    if (acRoom == null) {
      _showSnackBar('Select AC Room');
      return;
    }
    if (nonVegAllowed == null) {
      _showSnackBar('Select Non-veg Allowed');
      return;
    }
    if (gatedSecurity == null) {
      _showSnackBar('Select Gated Security');
      return;
    }
    if (gym == null) {
      _showSnackBar('Select Gym');
      return;
    }
    if (whoShowsProperty == null || whoShowsProperty!.isEmpty) {
      _showSnackBar('Select Who Will Show This Property');
      return;
    }

    ref.read(flatmateDraftProvider).update(() {
      final draft = ref.read(flatmateDraftProvider).draft;
      draft.attachedBathroom = attachedBathroom;
      draft.bathroomType = bathroomType;
      draft.acRoom = acRoom;
      draft.balcony = balcony;
      draft.nonVegAllowed = nonVegAllowed;
      draft.smokingAllowed = smokingAllowed;
      draft.drinkingAllowed = drinkingAllowed;
      draft.gym = gym;
      draft.gatedSecurity = gatedSecurity;
      draft.liftSelected = liftSelected;
      draft.swimmingPoolSelected = swimmingPoolSelected;
      draft.clubHouseSelected = clubHouseSelected;
      draft.powerBackupSelected = powerBackupSelected;
      draft.parkSelected = parkSelected;
      draft.whoShowsProperty = whoShowsProperty;
      draft.waterSupply = waterSupply;
      draft.secondaryNumber = _secondaryNumberController.text.trim();
      draft.directionsTip = _directionsTipController.text.trim();
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FlatmatePhotosScreen()),
    );
  }

  // ---------------------------------------------
  // Snack Bar  � UNCHANGED
  // ---------------------------------------------
  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF2E7D32)
            : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  UI COMPONENT LIBRARY
  // ---------------------------------------------------------------------------

  // -- AppBar ------------------------------------------------------------------
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
        'Amenities Details',
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
              '5/7',
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

  // -- 7-step progress strip ---------------------------------------------------
  Widget _buildProgressBar() {
    const int total = 7;
    const int completed = 5;
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

  // -- Outer section card ------------------------------------------------------
  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: child,
    );
  }

  // -- Bold UPPERCASE section title --------------------------------------------
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _sectionLabel,
      ),
    );
  }

  // -- Thin divider between rows -----------------------------------------------
  Widget _rowDivider() {
    return const Divider(height: 1, thickness: 1, color: _divider);
  }

  // -- No / Yes pill toggle ----------------------------------------------------
  Widget _noYesToggle({
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          label: 'No',
          selected: value == false,
          isYes: false,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 6),
        _pill(
          label: 'Yes',
          selected: value == true,
          isYes: true,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required bool isYes,
    required VoidCallback onTap,
  }) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (selected) {
      if (isYes) {
        bgColor = const Color(0xFFE5F7F3);
        borderColor = const Color(0xFF12AA8C);
        textColor = const Color(0xFF12AA8C);
      } else {
        bgColor = const Color(0xFFF0F2F5);
        borderColor = const Color(0xFFD0D5DD);
        textColor = const Color(0xFF1A2332);
      }
    } else {
      bgColor = _cardBg;
      borderColor = _pillBorder;
      textColor = _rowLabel;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 46,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // -- Icon + label + No/Yes toggle row ---------------------------------------
  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _rowLabel,
              ),
            ),
          ),
          _noYesToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // -- Dropdown card (standalone card with label) ------------------------------
  Widget _dropdownCard({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.65,
              color: _iconColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: (value == null || value == 'Select') ? null : value,
                hint: Row(
                  children: [
                    if (prefixIcon != null) ...[
                      Icon(prefixIcon, size: 17, color: _hintColor),
                      const SizedBox(width: 8),
                    ],
                    const Text(
                      'Select',
                      style: TextStyle(color: _hintColor, fontSize: 15),
                    ),
                  ],
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _iconColor,
                  size: 20,
                ),
                dropdownColor: _cardBg,
                borderRadius: BorderRadius.circular(13),
                style: const TextStyle(color: _rowLabel, fontSize: 15),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Amenity checkbox row ----------------------------------------------------
  Widget _amenityRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: _primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: _pillBorder, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: _iconColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _rowLabel,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  SECTION BUILDERS
  // ---------------------------------------------------------------------------

  // -- 1. ROOM DETAILS ---------------------------------------------------------
  // Added: Bathroom type chips (Private Bathroom / Shared Bathroom)
  Widget _buildRoomDetailsSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('ROOM DETAILS*'),
          const SizedBox(height: 4),
          _rowDivider(),

          // Attached Bathroom
          _toggleRow(
            icon: Icons.person_outline,
            label: 'Attached Bathroom*',
            value: attachedBathroom,
            onChanged: (v) => setState(() => attachedBathroom = v),
          ),

          // Bathroom type chips � shown regardless (matches product spec)
          if (attachedBathroom == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: ['Private Bathroom', 'Shared Bathroom'].map((type) {
                  final selected = bathroomType == type;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => bathroomType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? _primaryDark : _cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? _primaryDark : _pillBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : _rowLabel,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          _rowDivider(),

          // Balcony
          _toggleRow(
            icon: Icons.door_sliding_outlined,
            label: 'Balcony',
            value: balcony,
            onChanged: (v) => setState(() => balcony = v),
          ),
          _rowDivider(),

          // AC Room
          _toggleRow(
            icon: Icons.ac_unit_outlined,
            label: 'AC Room*',
            value: acRoom,
            onChanged: (v) => setState(() => acRoom = v),
          ),
        ],
      ),
    );
  }

  // -- 2. FLATMATE PREFERENCE --------------------------------------------------
  Widget _buildFlatmatePreferenceSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('FLATMATE PREFERENCE'),
          const SizedBox(height: 4),
          _rowDivider(),

          _toggleRow(
            icon: Icons.person_outline,
            label: 'Non-veg allowed*',
            value: nonVegAllowed,
            onChanged: (v) => setState(() => nonVegAllowed = v),
          ),
          _rowDivider(),

          _toggleRow(
            icon: Icons.people_outline,
            label: 'Smoking Allowed',
            value: smokingAllowed,
            onChanged: (v) => setState(() => smokingAllowed = v),
          ),
          _rowDivider(),

          _toggleRow(
            icon: Icons.local_bar_outlined,
            label: 'Drinking Allowed',
            value: drinkingAllowed,
            onChanged: (v) => setState(() => drinkingAllowed = v),
          ),
        ],
      ),
    );
  }

  // -- 3. OTHER DETAILS FOR BETTER VISIBILITY ---------------------------------
  Widget _buildOtherDetailsSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('OTHER DETAILS FOR BETTER VISIBILITY'),
          const SizedBox(height: 4),
          _rowDivider(),

          _toggleRow(
            icon: Icons.verified_user_outlined,
            label: 'Gated Security*',
            value: gatedSecurity,
            onChanged: (v) => setState(() => gatedSecurity = v),
          ),
          _rowDivider(),

          _toggleRow(
            icon: Icons.person_outline,
            label: 'Gym*',
            value: gym,
            onChanged: (v) => setState(() => gym = v),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoShowsCard() {
    return _dropdownCard(
      label: 'WHO WILL SHOW THIS PROPERTY?*',
      value: whoShowsProperty,
      items: const [
        'Need help',
        'I will show',
        'Neighbours',
        'Friends/Relatives',
        'Security',
        'Tenants',
        'Others',
      ],
      onChanged: (v) => setState(() => whoShowsProperty = v!),
    );
  }

  // -- 5. SECONDARY NUMBER -----------------------------------------------------
  Widget _buildSecondaryNumberCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SECONDARY NUMBER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.65,
              color: _iconColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: _iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _secondaryNumberController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: _sectionLabel,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    cursorColor: _primaryDark,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      hintText: 'Enter secondary number',
                      hintStyle: TextStyle(
                        color: _hintColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- 6. ADD DIRECTIONS TIP ---------------------------------------------------
  Widget _buildDirectionsTipCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + NEW badge
          Row(
            children: [
              const Text(
                'ADD DIRECTIONS TIP FOR YOUR TENANTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: _iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _newBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Blue tip banner
          if (_showDirectionsTipPoster)
            Container(
              decoration: BoxDecoration(
                color: _tipBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _tipBorder, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: _tipText,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Don't want calls asking location?",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _tipText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Add directions to reach using landmarks',
                          style: TextStyle(
                            fontSize: 12,
                            color: _tipText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showDirectionsTipPoster = false;
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _tipBorder, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: _tipText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Directions text field with left accent bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            padding: const EdgeInsets.only(left: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: _pillBorder,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _directionsTipController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, color: _rowLabel),
                      cursorColor: _primaryDark,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        hintText:
                            'Eg. Take the road opposite to Amrita College, '
                            'take right after 300m, last house in the lane.',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: _hintColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- 7. WATER SUPPLY ---------------------------------------------------------
  // NOTE: Current Situation of Property removed as requested
  Widget _buildWaterSupplyCard() {
    return _dropdownCard(
      label: 'WATER SUPPLY',
      value: waterSupply,
      items: const ['Both', 'Corporation', 'Borewell'],
      prefixIcon: Icons.water_drop_outlined,
      onChanged: (v) => setState(() => waterSupply = v!),
    );
  }

  // -- 8. OTHER AMENITIES ------------------------------------------------------
  Widget _buildAmenitiesSection() {
    final List<_AmenityItem> allAmenities = [
      _AmenityItem(
        icon: Icons.home_work_outlined,
        label: 'Club',
        getter: () => clubHouseSelected,
        setter: (v) => setState(() => clubHouseSelected = v),
      ),
      _AmenityItem(
        icon: Icons.local_fire_department_outlined,
        label: 'Gas',
        getter: () => false,
        setter: (_) {},
      ),
      _AmenityItem(
        icon: Icons.water_outlined,
        label: 'Sewage',
        getter: () => false,
        setter: (_) {},
      ),
      _AmenityItem(
        icon: Icons.power_outlined,
        label: 'Power Backup',
        getter: () => powerBackupSelected,
        setter: (v) => setState(() => powerBackupSelected = v),
      ),
      _AmenityItem(
        icon: Icons.elevator_outlined,
        label: 'Lift',
        getter: () => liftSelected,
        setter: (v) => setState(() => liftSelected = v),
      ),
      _AmenityItem(
        icon: Icons.star_border_rounded,
        label: 'Fire-Alarm',
        getter: () => false,
        setter: (_) {},
      ),
      _AmenityItem(
        icon: Icons.person_outline,
        label: 'House-Keeper',
        getter: () => false,
        setter: (_) {},
      ),
      _AmenityItem(
        icon: Icons.park_outlined,
        label: 'Park',
        getter: () => parkSelected,
        setter: (v) => setState(() => parkSelected = v),
      ),
      _AmenityItem(
        icon: Icons.store_outlined,
        label: 'Shopping Center',
        getter: () => false,
        setter: (_) {},
      ),
      _AmenityItem(
        icon: Icons.pool_outlined,
        label: 'Swimming Pool',
        getter: () => swimmingPoolSelected,
        setter: (v) => setState(() => swimmingPoolSelected = v),
      ),
      _AmenityItem(
        icon: Icons.video_camera_front_outlined,
        label: 'Intercom',
        getter: () => false,
        setter: (_) {},
      ),
      _AmenityItem(
        icon: Icons.local_parking_outlined,
        label: 'Visitor Parking',
        getter: () => false,
        setter: (_) {},
      ),
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('OTHER AMENITIES'),
          const SizedBox(height: 4),
          _rowDivider(),
          const SizedBox(height: 4),
          ...allAmenities.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _amenityRow(
                  icon: item.icon,
                  label: item.label,
                  value: item.getter(),
                  onChanged: (v) => item.setter(v ?? false),
                ),
                if (idx < allAmenities.length - 1) _rowDivider(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // -- Sticky Save & Continue button -------------------------------------------
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
          onPressed: _onSaveAndContinue,
          child: const Text(
            'Save & Continue',
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
          // Progress strip
          _buildProgressBar(),

          // Scrollable form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRoomDetailsSection(), // Room Details + bathroom type chips
                  const SizedBox(height: 12),
                  _buildFlatmatePreferenceSection(), // Flatmate Preference
                  const SizedBox(height: 12),
                  _buildOtherDetailsSection(), // Other Details
                  const SizedBox(height: 12),
                  _buildWhoShowsCard(), // Who shows property
                  const SizedBox(height: 12),
                  _buildSecondaryNumberCard(), // ? NEW: Secondary Number
                  const SizedBox(height: 12),
                  _buildDirectionsTipCard(), // Directions tip
                  const SizedBox(height: 12),
                  // Current Situation of Property � REMOVED as requested
                  _buildWaterSupplyCard(), // Water Supply
                  const SizedBox(height: 12),
                  _buildAmenitiesSection(), // Other Amenities
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Sticky save button
          _buildSaveButton(),
        ],
      ),
    );
  }
}

// ---------------------------------------------
// Helper data class for amenity list rows
// ---------------------------------------------
class _AmenityItem {
  final IconData icon;
  final String label;
  final bool Function() getter;
  final void Function(bool) setter;

  const _AmenityItem({
    required this.icon,
    required this.label,
    required this.getter,
    required this.setter,
  });
}
