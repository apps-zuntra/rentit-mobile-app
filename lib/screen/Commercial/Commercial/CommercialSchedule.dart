// CommercialSchedule.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/model/model/commercial_provider.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);

class CommercialSchedule extends ConsumerStatefulWidget {
  const CommercialSchedule({super.key});

  @override
  ConsumerState<CommercialSchedule> createState() => _CommercialScheduleState();
}

class _CommercialScheduleState extends ConsumerState<CommercialSchedule> {
  static const String _apiBase = "https://rentit-backend-yti9.onrender.com";

  String _availability = "";
  String _startTime = "";
  String _endTime = "";
  bool _allDay = false;
  bool _isLoading = false;
  bool _dataLoading = true;

  late final List<String> _timeOptions;

  @override
  void initState() {
    super.initState();
    _timeOptions = _generateTimeOptions();
    _loadExistingData();
  }

  // ── Time Helpers ───────────────────────────────────────────────────────────

  List<String> _generateTimeOptions() {
    final List<String> options = [];
    for (int i = 0; i < 48; i++) {
      final hour = i ~/ 2;
      final minutes = i % 2 == 0 ? "00" : "30";
      final suffix = hour >= 12 ? "PM" : "AM";
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      options.add(
        "${formattedHour.toString().padLeft(2, '0')}:$minutes $suffix",
      );
    }
    return options;
  }

  String _convertTo24(String time) {
    if (time.isEmpty) return "";
    final parts = time.split(" ");
    final hm = parts[0].split(":");
    int h = int.parse(hm[0]);
    final m = hm[1];
    final suffix = parts[1];
    if (suffix == "PM" && h != 12) h += 12;
    if (suffix == "AM" && h == 12) h = 0;
    return "${h.toString().padLeft(2, '0')}:$m";
  }

  String _convertTo12(String time24) {
    if (time24.isEmpty) return "";
    final parts = time24.split(":");
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final suffix = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return "${hour.toString().padLeft(2, '0')}:$minute $suffix";
  }

  bool _isEndGreater(String start, String end) =>
      _convertTo24(end).compareTo(_convertTo24(start)) > 0;

  List<String> _getFilteredEndTimes() {
    if (_startTime.isEmpty) return _timeOptions;
    return _timeOptions
        .where((t) => _convertTo24(t).compareTo(_convertTo24(_startTime)) > 0)
        .toList();
  }

  // ── Load Existing Data ─────────────────────────────────────────────────────

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

      debugPrint("📦 SCHEDULE RESPONSE => ${res.body}");

      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() => _dataLoading = false);
        return;
      }

      final data = jsonDecode(res.body);

      setState(() {
        final days = data["availabilityDay"];
        if (days is List && days.isNotEmpty) {
          _availability = days.first.toString();
        }

        _allDay = data["availableAllDay"] ?? false;

        final rawStart = data["startTime"]?.toString() ?? "";
        final rawEnd = data["endTime"]?.toString() ?? "";

        if (rawStart.isNotEmpty) {
          final converted = _convertTo12(rawStart);
          if (_timeOptions.contains(converted)) _startTime = converted;
        }
        if (rawEnd.isNotEmpty) {
          final converted = _convertTo12(rawEnd);
          if (_timeOptions.contains(converted)) _endTime = converted;
        }

        _dataLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Schedule load error: $e");
      if (mounted) setState(() => _dataLoading = false);
    }
  }

  // ── Save — ONLY place that writes to DB ───────────────────────────────────

  Future<void> _saveSchedule() async {
    if (!_allDay) {
      if (_startTime.isEmpty || _endTime.isEmpty) {
        _showSnack("Please select start and end time.");
        return;
      }
      if (!_isEndGreater(_startTime, _endTime)) {
        _showSnack("End time must be greater than start time.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final commercialId = prefs.getInt("commercialId");
      final token = prefs.getString("token");

      if (commercialId == null) {
        _showSnack("Commercial ID missing.");
        return;
      }
      if (token == null) {
        _showSnack("Session expired. Please login again.");
        return;
      }

      final draft = ref.read(commercialDraftProvider).draft;

      final payload = {
        // ── Property Details ──────────────────────────────
        "commercialPropertyType": draft.commercialPropertyType,
        "buildingType": draft.buildingType,
        "propertyAge": draft.propertyAge,
        "floor": draft.floor,
        "totalFloor": draft.totalFloor,
        "builtUpArea": draft.builtUpArea,
        "furnishing": draft.furnishing,
        "commercialOtherFeatures": draft.commercialOtherFeatures,

        // ── Location ──────────────────────────────────────
        "city": draft.city,
        "locality": draft.locality,
        "street": draft.street,
        "landmark": draft.landmark,
        "latitude": draft.latitude,
        "longitude": draft.longitude,

        // ── Rent Details ──────────────────────────────────
        "expectedRent": draft.expectedRent,
        "deposit": draft.deposit,
        "rentNegotiable": draft.rentNegotiable,
        "depositNegotiable": draft.depositNegotiable,
        "maintenanceExtra": draft.maintenanceExtra,
        "maintenanceAmount": draft.maintenanceAmount,
        "leaseDuration": draft.leaseDuration,
        "lockinPeriod": draft.lockinPeriod,
        "availableFrom": draft.availableFrom?.toIso8601String(),
        "idealFor": draft.idealFor,
        "addOthertags": draft.addOthertags,

        // ── Amenities ─────────────────────────────────────
        "otherFeatures": draft.otherFeatures,
        "slots": draft.slots,

        // ── Property Info ─────────────────────────────────
        "description":
            "${draft.description ?? ''} (Info: ${draft.previousOccupancy ?? 'null'}/${draft.propertyCleaning == true ? 'Y' : 'N'}/${draft.propertyPainting == true ? 'Y' : 'N'}/${draft.whoShowsProperty ?? 'null'})",

        // ── Contact ───────────────────────────────────────
        "contactName": draft.contactName,
        "mobileNo": draft.mobileNo,
        "whatsapp": draft.whatsapp,

        // ── Schedule (this screen) ────────────────────────
        "availabilityDay": _availability.isEmpty ? [] : [_availability],
        "startTime": _allDay ? null : _convertTo24(_startTime),
        "endTime": _allDay ? null : _convertTo24(_endTime),
        "availableAllDay": _allDay,

        // ── Finalization ──────────────────────────────────
        "isDraft": false,
        "currentStep": 7,
      };

      debugPrint("📤 FINAL PAYLOAD => ${jsonEncode(payload)}");

      final res = await http.put(
        Uri.parse("$_apiBase/commercial/$commercialId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      debugPrint("STATUS => ${res.statusCode}");
      debugPrint("BODY   => ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200) {
        ref.read(commercialDraftProvider).clear();
        _showSnack("Saved successfully!");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const PgOwnerNavigationScreen(initialIndex: 1),
          ),
          (route) => false,
        );
      } else {
        final body = jsonDecode(res.body);
        _showSnack(body["message"]?.toString() ?? "Failed to save schedule.");
      }
    } catch (e) {
      debugPrint("❌ Save schedule error: $e");
      if (mounted) _showSnack("Network error. Check your connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────

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

  // ── UI Helpers ─────────────────────────────────────────────────────────────

  Widget _progressBar() {
    const int total = 8;
    const int current = 8;
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

  InputDecoration _inputDec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
      filled: true,
      fillColor: kInputBg,
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

  Widget _availabilityCard({
    required String label,
    required String subtitle,
    required String emoji,
  }) {
    final bool active = _availability == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _availability = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? kAccentBlue : kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? kAccentBlue : kBorderColor,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: kAccentBlue.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : kPrimaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: active
                      ? Colors.white.withOpacity(0.7)
                      : kSecondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: kLabelText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            dropdownColor: kCardBg,
            style: const TextStyle(
              color: kPrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kSecondaryText,
            ),
            decoration: _inputDec(hint: "Select"),
            items: items
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: kSecondaryText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t,
                          style: const TextStyle(
                            color: kPrimaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kScaffoldBg,
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
            "Availability",
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
                  "8 / 8",
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
                          // ── Visitor Availability ───────────────────────
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("When can visitors come?"),
                                Row(
                                  children: [
                                    _availabilityCard(
                                      label: "Everyday",
                                      subtitle: "All days",
                                      emoji: "📅",
                                    ),
                                    const SizedBox(width: 10),
                                    _availabilityCard(
                                      label: "Weekday",
                                      subtitle: "Mon – Fri",
                                      emoji: "💼",
                                    ),
                                    const SizedBox(width: 10),
                                    _availabilityCard(
                                      label: "Weekend",
                                      subtitle: "Sat – Sun",
                                      emoji: "🏖️",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ── Time Schedule ──────────────────────────────
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Visiting Hours"),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _timeDropdown(
                                      label: "Start Time",
                                      value: _startTime,
                                      items: _timeOptions,
                                      onChanged: _allDay
                                          ? null
                                          : (v) => setState(() {
                                              _startTime = v ?? "";
                                              _endTime = "";
                                            }),
                                    ),
                                    const SizedBox(width: 12),
                                    _timeDropdown(
                                      label: "End Time",
                                      value: _endTime,
                                      items: _getFilteredEndTimes(),
                                      onChanged: _allDay
                                          ? null
                                          : (v) => setState(
                                              () => _endTime = v ?? "",
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(height: 1, color: kDivider),
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _allDay = !_allDay;
                                    _startTime = "";
                                    _endTime = "";
                                  }),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: _allDay,
                                          onChanged: (v) => setState(() {
                                            _allDay = v ?? false;
                                            _startTime = "";
                                            _endTime = "";
                                          }),
                                          activeColor: kAccentBlue,
                                          side: const BorderSide(
                                            color: kBorderColor,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        "Available All Day (24 hours)",
                                        style: TextStyle(
                                          color: kPrimaryText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Summary chip ───────────────────────────────
                          if ((_allDay ||
                                  (_startTime.isNotEmpty &&
                                      _endTime.isNotEmpty)) &&
                              _availability.isNotEmpty)
                            _card(
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: kAccentBlue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: kAccentBlue,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Availability set",
                                          style: TextStyle(
                                            color: kPrimaryText,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _allDay
                                              ? "$_availability · All Day (24 hours)"
                                              : "$_availability · $_startTime – $_endTime",
                                          style: const TextStyle(
                                            color: kSecondaryText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Finish Posting Button ──────────────────────────────
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
                        onPressed: _isLoading ? null : _saveSchedule,
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
                                "Finish Posting",
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
