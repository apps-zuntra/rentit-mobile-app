// lib/screen/Flatmate/FlatmateSchedule.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rentit/main/rental_home.dart';
import 'package:rentit/providers/FlatmateDraftProvider.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------
// Design Tokens (matches CommercialSchedule)
// ---------------------------------------------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);

// ---------------------------------------------
// API Config
// ---------------------------------------------
class _ApiConfig {
  static const String baseUrl = "https://rentit-backend-omega.vercel.app";
  static const String flatmate = '$baseUrl/flatmate';
}

// ---------------------------------------------
// Screen
// ---------------------------------------------
class FlatmateScheduleForm extends ConsumerStatefulWidget {
  const FlatmateScheduleForm({super.key});

  @override
  ConsumerState<FlatmateScheduleForm> createState() =>
      _FlatmateScheduleFormState();
}

class _FlatmateScheduleFormState extends ConsumerState<FlatmateScheduleForm> {
  // -- State --
  String availability = '';
  String startTime = '';
  String endTime = '';
  bool allDay = false;
  bool isLoading = false;
  bool dataLoading = true;

  // -- Time Options --
  late final List<String> timeOptions;

  // ---------------------------------------------
  // Lifecycle
  // ---------------------------------------------
  @override
  void initState() {
    super.initState();
    timeOptions = _generateTimeOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(flatmateDraftProvider).draft;
      setState(() {
        final days = draft.availabilityDay;
        if (days is List && days.isNotEmpty) {
          availability = days.first.toString();
        } else if (days is String && days.isNotEmpty) {
          availability = days;
        }
        allDay = draft.availableAllDay;
        startTime = draft.startTime != null
            ? _convertTo12(draft.startTime!)
            : '';
        endTime = draft.endTime != null ? _convertTo12(draft.endTime!) : '';
        dataLoading = false;
      });
    });
  }

  // ---------------------------------------------
  // Time Helpers
  // ---------------------------------------------

  /// Generates 30-minute interval time slots: 12:00 AM ? 11:30 PM
  List<String> _generateTimeOptions() {
    final List<String> options = [];
    for (int i = 0; i < 48; i++) {
      final int hour = i ~/ 2;
      final String minutes = i % 2 == 0 ? '00' : '30';
      final String suffix = hour >= 12 ? 'PM' : 'AM';
      final int formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      options.add(
        '${formattedHour.toString().padLeft(2, '0')}:$minutes $suffix',
      );
    }
    return options;
  }

  /// Converts "02:30 PM" ? "14:30"
  String _convertTo24(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(' ');
    final hm = parts[0].split(':');
    int h = int.parse(hm[0]);
    final String m = hm[1];
    final String suffix = parts[1];
    if (suffix == 'PM' && h != 12) h += 12;
    if (suffix == 'AM' && h == 12) h = 0;
    return '${h.toString().padLeft(2, '0')}:$m';
  }

  /// Converts "14:30" ? "02:30 PM"
  String _convertTo12(String time24) {
    if (time24.isEmpty) return '';
    try {
      final parts = time24.split(':');
      int h = int.parse(parts[0]);
      final String m = parts[1].length >= 2
          ? parts[1].substring(0, 2)
          : parts[1];
      final String suffix = h >= 12 ? 'PM' : 'AM';
      final int formattedHour = h % 12 == 0 ? 12 : h % 12;
      return '${formattedHour.toString().padLeft(2, '0')}:$m $suffix';
    } catch (_) {
      return '';
    }
  }

  /// Returns only end-time options that are after the selected start time
  List<String> _getFilteredEndTimes() {
    if (startTime.isEmpty) return timeOptions;
    return timeOptions
        .where((t) => _convertTo24(t).compareTo(_convertTo24(startTime)) > 0)
        .toList();
  }

  bool _isEndGreaterThanStart() {
    if (startTime.isEmpty || endTime.isEmpty) return false;
    return _convertTo24(endTime).compareTo(_convertTo24(startTime)) > 0;
  }

  // ---------------------------------------------
  // Load Existing Data
  // ---------------------------------------------
  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? flatmateId = prefs.getInt('flatmateId');
      final String? token = prefs.getString('token');

      debugPrint('SCHEDULE LOAD ID ?? $flatmateId');

      if (flatmateId == null || token == null || token.isEmpty) {
        if (mounted) setState(() => dataLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${_ApiConfig.flatmate}/$flatmateId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('SCHEDULE STATUS ?? ${response.statusCode}');
      debugPrint('SCHEDULE BODY ?? ${response.body}');

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() => dataLoading = false);
        return;
      }

      final data = jsonDecode(response.body);

      setState(() {
        // Availability
        final days = data['availabilityDay'];
        if (days is List && days.isNotEmpty) {
          availability = days.first.toString();
        }

        // All day
        allDay = data['availableAllDay'] ?? false;

        // Start time
        if (data['startTime'] != null &&
            data['startTime'].toString().isNotEmpty) {
          final converted = _convertTo12(data['startTime'].toString());
          if (timeOptions.contains(converted)) startTime = converted;
        }

        // End time
        if (data['endTime'] != null && data['endTime'].toString().isNotEmpty) {
          final converted = _convertTo12(data['endTime'].toString());
          if (timeOptions.contains(converted)) endTime = converted;
        }

        dataLoading = false;
      });
    } catch (e) {
      debugPrint('_loadExistingData error ?? $e');
      if (mounted) setState(() => dataLoading = false);
    }
  }

  // ---------------------------------------------
  // Save Schedule
  // ---------------------------------------------
  Future<void> _saveSchedule() async {
    if (availability.isEmpty) {
      _showSnackBar('Select availability');
      return;
    }
    if (!allDay) {
      if (startTime.isEmpty || endTime.isEmpty) {
        _showSnackBar('Select start and end time');
        return;
      }
      if (!_isEndGreaterThanStart()) {
        _showSnackBar('End time must be greater than start time');
        return;
      }
    }

    setState(() => isLoading = true);

    // Write schedule fields into draft
    ref.read(flatmateDraftProvider).update(() {
      final draft = ref.read(flatmateDraftProvider).draft;
      draft.availabilityDay = availability.isEmpty ? [] : [availability];
      draft.startTime = allDay ? null : _convertTo24(startTime);
      draft.endTime = allDay ? null : _convertTo24(endTime);
      draft.availableAllDay = allDay;
    });

    try {
      // Single API call � saves everything
      await ref.read(flatmateDraftProvider).saveAll();

      if (!mounted) return;
      setState(() => isLoading = false);

      _showSnackBar('Saved Successfully', success: true);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const PgOwnerNavigationScreen(initialIndex: 1),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('_saveSchedule error ?? $e');
      _showSnackBar(e.toString());
    }
  }

  // ---------------------------------------------
  // Snack Bar
  // ---------------------------------------------
  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: success ? kAccentBlue : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------
  // UI HELPERS
  // ---------------------------------------------

  /// Segmented progress bar
  Widget _progressBar() {
    const int total = 7;
    const int current = 7;
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

  /// White card wrapper
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

  /// Small all-caps section label
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

  /// Shared input decoration for dropdowns
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

  // -- Availability Option Cards ----------------------------------------------
  Widget _availabilityCard({
    required String label,
    required String subtitle,
    required String emoji,
  }) {
    final bool active = availability == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => availability = label),
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

  // -- Time Dropdown ----------------------------------------------------------
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

  // ---------------------------------------------
  // Build
  // ---------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kScaffoldBg,

        // -- AppBar ----------------------------------------------------------
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
                  "7 / 7",
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

        // -- Body ------------------------------------------------------------
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
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -- Visitor Availability Card ------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("When are you available?"),
                                Row(
                                  children: [
                                    _availabilityCard(
                                      label: "Everyday",
                                      subtitle: "All days",
                                      emoji: "??",
                                    ),
                                    const SizedBox(width: 10),
                                    _availabilityCard(
                                      label: "Weekday",
                                      subtitle: "Mon � Fri",
                                      emoji: "??",
                                    ),
                                    const SizedBox(width: 10),
                                    _availabilityCard(
                                      label: "Weekend",
                                      subtitle: "Sat � Sun",
                                      emoji: "???",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // -- Time Schedule Card -------------------------
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label("Available Hours"),

                                // Start & End dropdowns
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _timeDropdown(
                                      label: "Start Time",
                                      value: startTime,
                                      items: timeOptions,
                                      onChanged: allDay
                                          ? null
                                          : (v) => setState(() {
                                              startTime = v ?? '';
                                              endTime = '';
                                            }),
                                    ),
                                    const SizedBox(width: 12),
                                    _timeDropdown(
                                      label: "End Time",
                                      value: endTime,
                                      items: _getFilteredEndTimes(),
                                      onChanged: allDay
                                          ? null
                                          : (v) => setState(
                                              () => endTime = v ?? '',
                                            ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Divider
                                Container(height: 1, color: kDivider),

                                const SizedBox(height: 14),

                                // All Day toggle
                                GestureDetector(
                                  onTap: () => setState(() {
                                    allDay = !allDay;
                                    startTime = '';
                                    endTime = '';
                                  }),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: allDay,
                                          onChanged: (v) => setState(() {
                                            allDay = v ?? false;
                                            startTime = '';
                                            endTime = '';
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

                          // -- Summary chip (shows when both values set) --
                          if ((allDay ||
                                  (startTime.isNotEmpty &&
                                      endTime.isNotEmpty)) &&
                              availability.isNotEmpty)
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
                                          allDay
                                              ? "$availability � All Day (24 hours)"
                                              : "$availability � $startTime � $endTime",
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

                  // -- Sticky Save Button -----------------------------------
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
                        onPressed: isLoading ? null : _saveSchedule,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Save And Continue",
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
