// lib/screen/Apartment/ApartmentSchedule.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/providers/apartment_draft_provider.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/main/DashboardScreen.dart';

// -- Design Tokens (matches full Commercial flow) ------------------------------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);
// -----------------------------------------------------------------------------

class ApartmentScheduleForm extends ConsumerStatefulWidget {
  const ApartmentScheduleForm({super.key});

  @override
  ConsumerState<ApartmentScheduleForm> createState() =>
      _ApartmentScheduleFormState();
}

class _ApartmentScheduleFormState extends ConsumerState<ApartmentScheduleForm> {
  // -- State ------------------------------------------------------------------
  String selectedAvailability = '';
  String startTime = '';
  String endTime = '';
  bool availableAllDay = false;
  bool isLoading = false;
  bool dataLoading = true;

  // -- Config -----------------------------------------------------------------
  final String apiBase = "https://rentit-backend-omega.vercel.app";

  late final List<String> timeOptions;

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    timeOptions = generateTimeOptions();
    loadExistingData();
  }

  // -- Time Generator ---------------------------------------------------------
  List<String> generateTimeOptions() {
    List<String> options = [];
    for (int i = 0; i < 48; i++) {
      int hour = i ~/ 2;
      String minute = i % 2 == 0 ? '00' : '30';
      String suffix = hour >= 12 ? 'PM' : 'AM';
      int displayHour = hour % 12 == 0 ? 12 : hour % 12;
      options.add('${displayHour.toString().padLeft(2, '0')}:$minute $suffix');
    }
    return options;
  }

  // -- 12H ? 24H --------------------------------------------------------------
  String convertTo24Hour(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(' ');
    final hourMinute = parts[0].split(':');
    int hour = int.parse(hourMinute[0]);
    final minute = hourMinute[1];
    final suffix = parts[1];
    if (suffix == 'PM' && hour != 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  // -- Validation -------------------------------------------------------------
  bool isEndTimeValid() {
    return convertTo24Hour(endTime).compareTo(convertTo24Hour(startTime)) > 0;
  }

  List<String> filteredEndTimes() {
    if (startTime.isEmpty) return timeOptions;
    return timeOptions
        .where(
          (time) =>
              convertTo24Hour(time).compareTo(convertTo24Hour(startTime)) > 0,
        )
        .toList();
  }

  void _saveToDraft() {
    final draft = ref.read(apartmentDraftProvider);
    draft.update(() {
      draft.draft.availabilityDay = selectedAvailability;
      draft.draft.availableAllDay = availableAllDay;
      draft.draft.startTime = availableAllDay
          ? null
          : convertTo24Hour(startTime);
      draft.draft.endTime = availableAllDay ? null : convertTo24Hour(endTime);
    });
  }

  // -- Save API ---------------------------------------------------------------
  Future<void> saveAvailability() async {
    // Validation
    if (selectedAvailability.isEmpty) {
      showSnack('Please select availability');
      return;
    }
    if (!availableAllDay) {
      if (startTime.isEmpty || endTime.isEmpty) {
        showSnack('Please select start and end time');
        return;
      }
      if (!isEndTimeValid()) {
        showSnack('End time must be greater than start time');
        return;
      }
    }

    // Local storage
    final prefs = await SharedPreferences.getInstance();
    final propertyId =
        prefs.getInt('apartmentId') ?? prefs.getInt('propertyId');
    final token = prefs.getString('token');

    if (propertyId == null) {
      showSnack('Property ID missing');
      return;
    }
    if (token == null) {
      showSnack('Token missing');
      return;
    }

    // Payload
    final payload = {
      'availabilityDay': [selectedAvailability],
      'startTime': availableAllDay ? null : convertTo24Hour(startTime),
      'endTime': availableAllDay ? null : convertTo24Hour(endTime),
      'availableAllDay': availableAllDay,
    };

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('$apiBase/apartment/$propertyId/availability'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        showSnack('Availability Saved');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const PgOwnerNavigationScreen(initialIndex: 1),
          ),
          (route) => false,
        );
        return;
      }

      final data = jsonDecode(response.body);
      showSnack(data['message'] ?? 'Something went wrong');
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      showSnack(e.toString());
    }
  }

  // -- Load Existing Data -----------------------------------------------------
  Future<void> loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? apartmentId =
          prefs.getInt("apartmentId") ?? prefs.getInt("propertyId");
      final String? token =
          prefs.getString("accessToken") ??
          prefs.getString("access_token") ??
          prefs.getString("token");

      if (apartmentId == null) {
        debugPrint("? apartmentId not found");
        if (mounted) setState(() => dataLoading = false);
        return;
      }
      if (token == null || token.isEmpty) {
        debugPrint("? token not found");
        if (mounted) setState(() => dataLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse("$apiBase/apartment/$apartmentId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("?? SCHEDULE STATUS: ${response.statusCode}");
      print("?? SCHEDULE BODY: ${response.body}");

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() => dataLoading = false);
        return;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      // Availability Day
      String availability = "";
      if (data["availabilityDay"] is List &&
          (data["availabilityDay"] as List).isNotEmpty) {
        availability = data["availabilityDay"][0].toString();
      }

      // Convert API values to UI labels
      switch (availability.toLowerCase()) {
        case "everyday":
          availability = "Everyday";
          break;
        case "weekday":
          availability = "Weekday";
          break;
        case "weekend":
          availability = "Weekend";
          break;
      }

      // Convert 24-hour time to 12-hour time
      String convertTo12Hour(String? time) {
        if (time == null || time.isEmpty) return "";
        final parts = time.split(":");
        int hour = int.parse(parts[0]);
        String minute = parts[1].substring(0, 2);
        final suffix = hour >= 12 ? "PM" : "AM";
        int displayHour = hour % 12 == 0 ? 12 : hour % 12;
        return "${displayHour.toString().padLeft(2, '0')}:$minute $suffix";
      }

      setState(() {
        selectedAvailability = availability;
        availableAllDay = data["availableAllDay"] == true;
        startTime = availableAllDay
            ? ""
            : convertTo12Hour(data["startTime"]?.toString());
        endTime = availableAllDay
            ? ""
            : convertTo12Hour(data["endTime"]?.toString());
        dataLoading = false;
      });

      print("? Schedule data loaded successfully");
    } catch (e) {
      debugPrint("? loadExistingData() error: $e");
      if (mounted) setState(() => dataLoading = false);
    }
  }

  // -- Snackbar ---------------------------------------------------------------
  void showSnack(String message) {
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

  // --------------------------------------------------------------------------
  //  UI HELPERS
  // --------------------------------------------------------------------------

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
            color: Colors.black.withValues(alpha: 0.04),
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
    final bool active = selectedAvailability == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedAvailability = label),
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
                      color: kAccentBlue.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                      ? Colors.white.withValues(alpha: 0.7)
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
            initialValue: items.contains(value) ? value : null,
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

  // -- Build ------------------------------------------------------------------
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
                                _label("When can visitors come?"),
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
                                _label("Visiting Hours"),

                                // Start & End dropdowns
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _timeDropdown(
                                      label: "Start Time",
                                      value: startTime,
                                      items: timeOptions,
                                      onChanged: availableAllDay
                                          ? null
                                          : (v) => setState(() {
                                              startTime = v!;
                                              endTime = '';
                                            }),
                                    ),
                                    const SizedBox(width: 12),
                                    _timeDropdown(
                                      label: "End Time",
                                      value: endTime,
                                      items: filteredEndTimes(),
                                      onChanged: availableAllDay
                                          ? null
                                          : (v) => setState(() => endTime = v!),
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
                                    availableAllDay = !availableAllDay;
                                    startTime = '';
                                    endTime = '';
                                  }),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: availableAllDay,
                                          onChanged: (v) => setState(() {
                                            availableAllDay = v!;
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
                          if ((availableAllDay ||
                                  (startTime.isNotEmpty &&
                                      endTime.isNotEmpty)) &&
                              selectedAvailability.isNotEmpty)
                            _card(
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: kAccentBlue.withValues(
                                        alpha: 0.08,
                                      ),
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
                                          availableAllDay
                                              ? "$selectedAvailability � All Day (24 hours)"
                                              : "$selectedAvailability � $startTime � $endTime",
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
                        onPressed: isLoading ? null : saveAvailability,
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
