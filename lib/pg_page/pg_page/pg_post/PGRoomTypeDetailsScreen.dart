// PGRoomTypeDetailsScreen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/pg_page/pg_page/pg_post/PGPropertyDetailsScreen.dart';
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

class PGRoomTypeDetailsScreen extends ConsumerStatefulWidget {
  final String selectedCity;

  const PGRoomTypeDetailsScreen({super.key, required this.selectedCity});

  @override
  ConsumerState<PGRoomTypeDetailsScreen> createState() =>
      _PGRoomTypeDetailsScreenState();
}

class _PGRoomTypeDetailsScreenState
    extends ConsumerState<PGRoomTypeDetailsScreen> {
  final String API_BASE = "https://rentit-backend-yti9.onrender.com";

  // -- State ----------------------------------------------------------------
  List<Map<String, dynamic>> rooms = [];
  bool loading = false;
  int currentStep = 1;
  final Map<int, TextEditingController> rentControllers = {};
  final Map<int, TextEditingController> depositControllers = {};

  static Map<String, dynamic> _emptyRoom() => {
    "sharing": "",
    "rent": null,
    "deposit": null,
    "amenities": <String>[],
  };

  final List<String> sharingOptions = [
    "Single room",
    "Double sharing",
    "Three sharing",
    "Four sharing",
  ];

  final List<Map<String, dynamic>> steps = [
    {"label": "Basic"},
    {"label": "Property details"},
    {"label": "Amenities"},
    {"label": "Price details"},
    {"label": "Photos"},
    {"label": "Contact"},
    {"label": "Verify"},
  ];

  final List<Map<String, dynamic>> amenitiesList = [
    {"label": "Cupboard", "icon": Icons.door_sliding_outlined},
    {"label": "AC", "icon": Icons.ac_unit},
    {"label": "Attached\nBathroom", "icon": Icons.bathroom_outlined},
    {"label": "Bedding", "icon": Icons.bed_outlined},
    {"label": "TV", "icon": Icons.tv_outlined},
  ];

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  @override
  void dispose() {
    for (final c in rentControllers.values) c.dispose();
    for (final c in depositControllers.values) c.dispose();
    super.dispose();
  }

  // -- Helpers ----------------------------------------------------------------
  void _initControllers(List<Map<String, dynamic>> roomList) {
    for (final c in rentControllers.values) c.dispose();
    for (final c in depositControllers.values) c.dispose();
    rentControllers.clear();
    depositControllers.clear();

    for (int i = 0; i < roomList.length; i++) {
      rentControllers[i] = TextEditingController(
        text: roomList[i]["rent"]?.toString() ?? "",
      );
      depositControllers[i] = TextEditingController(
        text: roomList[i]["deposit"]?.toString() ?? "",
      );
    }
  }

  void _addEmptyRoomControllers(int index) {
    rentControllers[index] = TextEditingController();
    depositControllers[index] = TextEditingController();
  }

  void _removeRoomControllers(int index) {
    rentControllers[index]?.dispose();
    depositControllers[index]?.dispose();
    rentControllers.remove(index);
    depositControllers.remove(index);

    final Map<int, TextEditingController> newRent = {};
    final Map<int, TextEditingController> newDeposit = {};
    for (int i = 0; i < rooms.length; i++) {
      newRent[i] =
          rentControllers[i > index ? i + 1 : i] ??
          TextEditingController(text: rooms[i]["rent"]?.toString() ?? "");
      newDeposit[i] =
          depositControllers[i > index ? i + 1 : i] ??
          TextEditingController(text: rooms[i]["deposit"]?.toString() ?? "");
    }
    rentControllers
      ..clear()
      ..addAll(newRent);
    depositControllers
      ..clear()
      ..addAll(newDeposit);
  }

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

  // -- API: Load --------------------------------------------------------------
  Future<void> loadExistingData() async {
    final draftRooms = ref.read(pgDraftProvider).draft.roomType;

    if (draftRooms.isNotEmpty) {
      rooms = List<Map<String, dynamic>>.from(draftRooms);
    } else {
      rooms = [_emptyRoom()];
    }

    _initControllers(rooms);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> handleNext() async {
    // Validation
    for (int i = 0; i < rooms.length; i++) {
      if ((rooms[i]["sharing"] ?? "").toString().isEmpty) {
        _showSnack("Please select Room Type for Room ${i + 1}");
        return;
      }

      if (rooms[i]["rent"] == null || rooms[i]["rent"].toString().isEmpty) {
        _showSnack("Please enter Rent for Room ${i + 1}");
        return;
      }

      if (rooms[i]["deposit"] == null ||
          rooms[i]["deposit"].toString().isEmpty) {
        _showSnack("Please enter Deposit for Room ${i + 1}");
        return;
      }
    }

    // Save to Draft Provider
    ref.read(pgDraftProvider).update(() {
      ref.read(pgDraftProvider).draft.roomType =
          List<Map<String, dynamic>>.from(rooms);
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PGPropertyDetailsScreen(selectedCity: widget.selectedCity),
      ),
    );
  }

  // -- Available sharing options ----------------------------------------------
  List<String> getAvailableOptions(int currentIndex) {
    return sharingOptions.where((option) {
      for (int i = 0; i < rooms.length; i++) {
        if (i != currentIndex && rooms[i]["sharing"] == option) return false;
      }
      return true;
    }).toList();
  }

  // -- Toggle amenity ---------------------------------------------------------
  void toggleAmenity(int index, String amenity) {
    final list = rooms[index]["amenities"] as List<String>;
    setState(() {
      if (list.contains(amenity))
        list.remove(amenity);
      else
        list.add(amenity);
    });
  }

  // -- Sharing icon -----------------------------------------------------------
  IconData _sharingIcon(String type) {
    switch (type) {
      case "Single room":
        return Icons.bed_outlined;
      case "Double sharing":
        return Icons.people_outline;
      case "Three sharing":
        return Icons.group_outlined;
      case "Four sharing":
        return Icons.groups_outlined;
      default:
        return Icons.bed_outlined;
    }
  }

  String _sharingShortLabel(String type) {
    switch (type) {
      case "Single room":
        return "Single\nRoom";
      case "Double sharing":
        return "Double\nSharing";
      case "Three sharing":
        return "Three\nSharing";
      case "Four sharing":
        return "Four+\nSharing";
      default:
        return type;
    }
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  /// Segmented progress bar � 2/8 filled
  Widget _progressBar() {
    const total = 8;
    const current = 2;
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(16),
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

  /// Uppercase label
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

  /// ? prefix text field
  Widget _moneyField({
    required String hint,
    required ValueChanged<String> onChanged,
    TextEditingController? controller,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: kInputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4F8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
              border: Border(right: BorderSide(color: kBorderColor)),
            ),
            alignment: Alignment.center,
            child: const Text(
              "?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kAccentBlue,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              cursorColor: kAccentBlue,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kPrimaryText,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kSecondaryText, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Room Card --------------------------------------------------------------
  Widget _roomCard(int index) {
    final room = rooms[index];
    final availableOptions = getAvailableOptions(index);
    final String selectedSharing = room["sharing"] as String? ?? "";
    final String rentLabel = selectedSharing.isEmpty
        ? "RENT FOR ROOM"
        : "RENT FOR ${selectedSharing.toUpperCase()}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Header: "Room N" + Delete --------------------------------------
        if (index != 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Room ${index + 1}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kPrimaryText,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      rooms.removeAt(index);
                      _removeRoomControllers(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Delete",
                      style: TextStyle(
                        color: Color(0xFFCC3333),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // -- Sharing type selector ------------------------------------------
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Room Type *"),
              Row(
                children: availableOptions.map((type) {
                  final selected = room["sharing"] == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          room["sharing"] = type;
                          for (int i = index + 1; i < rooms.length; i++) {
                            if (!getAvailableOptions(
                              i,
                            ).contains(rooms[i]["sharing"])) {
                              rooms[i]["sharing"] = "";
                            }
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(
                          right: type == availableOptions.last ? 0 : 8,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? kAccentBlue : kInputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? kAccentBlue : kBorderColor,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sharingIcon(type),
                              size: 22,
                              color: selected ? Colors.white : kSecondaryText,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _sharingShortLabel(type),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: selected ? Colors.white : kPrimaryText,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // -- Rent -----------------------------------------------------------
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("$rentLabel *"),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _moneyField(
                      hint: "0",
                      controller: rentControllers[index],
                      onChanged: (v) {
                        room["rent"] = v.isEmpty ? null : double.tryParse(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorderColor),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "/ Month",
                        style: TextStyle(
                          fontSize: 14,
                          color: kAccentBlue,
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

        // -- Deposit --------------------------------------------------------
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Expected Deposit *"),
              _moneyField(
                hint: "0",
                controller: depositControllers[index],
                onChanged: (v) {
                  room["deposit"] = v.isEmpty ? null : double.tryParse(v);
                },
              ),
            ],
          ),
        ),

        // -- Room Amenities -------------------------------------------------
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Room Amenities"),
              ...amenitiesList.asMap().entries.map((entry) {
                final amenity = entry.value;
                final label = amenity["label"] as String;
                final displayLabel = label.replaceAll("\n", " ");
                final icon = amenity["icon"] as IconData;
                final selected = (room["amenities"] as List<String>).contains(
                  label,
                );

                return GestureDetector(
                  onTap: () => toggleAmenity(index, label),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: selected ? kAccentBlue : kInputBg,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: selected ? kAccentBlue : kBorderColor,
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 13,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Icon(icon, size: 20, color: kSecondaryText),
                            const SizedBox(width: 10),
                            Text(
                              displayLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected ? kPrimaryText : kSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.key < amenitiesList.length - 1)
                        Divider(height: 1, color: kBorderColor),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        const SizedBox(height: 4),
      ],
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

        // Boxed chevron � matches CommercialContact exactly
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
          "Room Type Details",
          style: TextStyle(
            color: kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        // "2 / 8" step counter
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "2 / 8",
                style: TextStyle(
                  color: kSecondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        // Segmented progress bar � 2/7 filled
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
          // -- Scrollable content --------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- All room cards --------------------------------------
                  ...List.generate(rooms.length, (i) => _roomCard(i)),

                  // -- Add Room button -------------------------------------
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: rooms.length >= 4
                          ? null
                          : () {
                              setState(() {
                                final newIndex = rooms.length;
                                rooms.add(_emptyRoom());
                                _addEmptyRoomControllers(newIndex);
                              });
                            },
                      icon: Icon(
                        Icons.add,
                        size: 18,
                        color: rooms.length >= 4 ? kSecondaryText : kAccentBlue,
                      ),
                      label: Text(
                        rooms.length >= 4
                            ? "Max 4 rooms added"
                            : "+ Add Another Room Type",
                        style: TextStyle(
                          color: rooms.length >= 4
                              ? kSecondaryText
                              : kAccentBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: rooms.length >= 4 ? kBorderColor : kAccentBlue,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: rooms.length >= 4
                            ? kInputBg
                            : kAccentBlue.withOpacity(0.04),
                      ),
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
