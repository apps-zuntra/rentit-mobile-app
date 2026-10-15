import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/model/model/commercial_provider.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialContact.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF1B2A3B);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);

class CommercialPropertyInfoScreen extends ConsumerStatefulWidget {
  const CommercialPropertyInfoScreen({super.key});

  @override
  ConsumerState<CommercialPropertyInfoScreen> createState() =>
      _CommercialPropertyInfoScreenState();
}

class _CommercialPropertyInfoScreenState
    extends ConsumerState<CommercialPropertyInfoScreen> {
  late TextEditingController descController;
  final String _maxChars = "500";

  @override
  void initState() {
    super.initState();
    final draft = ref.read(commercialDraftProvider).draft;
    descController = TextEditingController(text: draft.description ?? "");
  }

  @override
  void dispose() {
    descController.dispose();
    super.dispose();
  }

  void _handleNext() {
    // Only continue. Validation can be added here if needed.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommercialContactDetailsScreen()),
    );
  }

  // ── UI HELPERS ─────────────────────────────────────────────────────────────

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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kLabelText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  InputDecoration _inputDec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
      filled: true,
      fillColor: kCardBg,
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

  Widget _progressBar() {
    const total = 8;
    const current = 7;
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

  Widget _yesNoButtons({
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: value == true ? kAccentBlue : kInputBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: value == true ? kAccentBlue : kBorderColor,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "Yes",
                style: TextStyle(
                  color: value == true ? Colors.white : kPrimaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: value == false ? kAccentBlue : kInputBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: value == false ? kAccentBlue : kBorderColor,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "No",
                style: TextStyle(
                  color: value == false ? Colors.white : kPrimaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E8FC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "TIP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _tipRow("Complete all sections for maximum visibility."),
          _tipRow("Freshly cleaned properties receive more enquiries."),
          _tipRow("Freshly painted properties attract better tenants."),
          _tipRow("Accurate descriptions increase response rates."),
        ],
      ),
    );
  }

  Widget _tipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: CircleAvatar(
              radius: 2.5,
              backgroundColor: Color(0xFF4A90E2),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF5A6B80),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(commercialDraftProvider).draft;

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
          "Property Info",
          style: TextStyle(
            color: kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "7 / 8",
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Description ─────────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Property Description"),
                        TextField(
                          controller: descController,
                          maxLines: 6,
                          maxLength: 500,
                          style: const TextStyle(
                            color: kPrimaryText,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          decoration: _inputDec(
                            hint:
                                "Spacious 2200 sq.ft. office space on the 4th floor with excellent natural light, modular workstations, 2 cabins, and a conference room...",
                          ).copyWith(
                            counterText: "${descController.text.length}/$_maxChars",
                            counterStyle: const TextStyle(
                              color: kSecondaryText,
                              fontSize: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {});
                            draft.description = val;
                            ref.read(commercialDraftProvider).update(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Previous Occupancy ─────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Previous Occupancy"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: draft.previousOccupancy,
                              hint: const Text(
                                "Select Occupancy",
                                style: TextStyle(
                                  color: kSecondaryText,
                                  fontSize: 14,
                                ),
                              ),
                              items: ["Tenant Occupied", "Owner Occupied", "Vacant"]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        e,
                                        style: const TextStyle(
                                          color: kPrimaryText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                draft.previousOccupancy = val;
                                ref.read(commercialDraftProvider).update(() {});
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Property Cleaning ──────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Property Cleaning"),
                        _yesNoButtons(
                          value: draft.propertyCleaning,
                          onChanged: (val) {
                            draft.propertyCleaning = val;
                            ref.read(commercialDraftProvider).update(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Property Painting ──────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Property Painting"),
                        _yesNoButtons(
                          value: draft.propertyPainting,
                          onChanged: (val) {
                            draft.propertyPainting = val;
                            ref.read(commercialDraftProvider).update(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Who Will Show ──────────────────────
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Who will show the property?"),
                        ...["Owner", "Caretaker", "Broker", "Need Help"]
                            .map((opt) {
                          final isSelected = draft.whoShowsProperty == opt;
                          return GestureDetector(
                            onTap: () {
                              draft.whoShowsProperty = opt;
                              ref.read(commercialDraftProvider).update(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: kInputBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected ? kAccentBlue : kBorderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? kAccentBlue
                                            : Colors.grey.shade400,
                                        width: isSelected ? 5 : 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    opt,
                                    style: TextStyle(
                                      color: isSelected
                                          ? kPrimaryText
                                          : kSecondaryText,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  // ── Tip Box ────────────────────────────
                  _buildTipBox(),
                ],
              ),
            ),
          ),
          
          // ── Bottom Bar ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: kCardBg,
              border: Border(top: BorderSide(color: kBorderColor)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
