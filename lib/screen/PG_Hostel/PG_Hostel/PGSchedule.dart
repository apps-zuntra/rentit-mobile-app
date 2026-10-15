// lib/pg_page/pg_post/PGSchedule.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/providers/pg_draft_provider.dart';
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

class PGScheduleForm extends ConsumerStatefulWidget {
  const PGScheduleForm({super.key});

  @override
  ConsumerState<PGScheduleForm> createState() => _PGScheduleFormState();
}

class _PGScheduleFormState extends ConsumerState<PGScheduleForm> {
  // -- State ------------------------------------------------------------------
  String availability = "";
  String startTime = "";
  String endTime = "";
  bool allDay = false;
  bool isLoading = false;
  bool dataLoading = true;

  String apiBase = "https://rentit-backend-yti9.onrender.com";

  late final List<String> timeOptions;

  // -- Lifecycle --------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    timeOptions = generateTimeOptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        loadDraftData();
      });
    });
  }

  // -- Time Helpers -----------------------------------------------------------

  List<String> generateTimeOptions() {
    List<String> options = [];
    for (int i = 0; i < 48; i++) {
      int hour = i ~/ 2;
      String minutes = i % 2 == 0 ? "00" : "30";
      String suffix = hour >= 12 ? "PM" : "AM";
      int formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      options.add(
        "${formattedHour.toString().padLeft(2, '0')}:$minutes $suffix",
      );
    }
    return options;
  }

  String convertTo24(String time) {
    if (time.isEmpty) return "";
    List parts = time.split(" ");
    List hm = parts[0].split(":");
    int h = int.parse(hm[0]);
    String m = hm[1];
    String suffix = parts[1];
    if (suffix == "PM" && h != 12) h += 12;
    if (suffix == "AM" && h == 12) h = 0;
    return "${h.toString().padLeft(2, '0')}:$m";
  }

  bool isEndGreater(String start, String end) {
    return convertTo24(end).compareTo(convertTo24(start)) > 0;
  }

  List<String> getFilteredEndTimes() {
    if (startTime.isEmpty) return timeOptions;
    return timeOptions
        .where((t) => convertTo24(t).compareTo(convertTo24(startTime)) > 0)
        .toList();
  }

  String convertTo12(String time24) {
    if (time24.isEmpty) return "";
    try {
      final parts = time24.split(":");
      int hour = int.parse(parts[0]);
      final minute = parts[1].substring(0, 2);
      final suffix = hour >= 12 ? "PM" : "AM";
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      return "${formattedHour.toString().padLeft(2, '0')}:$minute $suffix";
    } catch (e) {
      return "";
    }
  }

  // -- Load Existing Data -----------------------------------------------------
  void loadDraftData() {
    final draft = ref.read(pgDraftProvider).draft;

    availability = draft.availabilityDay ?? '';

    allDay = draft.availableAllDay;

    if (draft.startTime != null) {
      startTime = convertTo12(draft.startTime!);
    }

    if (draft.endTime != null) {
      endTime = convertTo12(draft.endTime!);
    }

    dataLoading = false;
  }

  // -- Save Schedule ----------------------------------------------------------
  Future<void> saveSchedule() async {
    if (!allDay) {
      if (startTime.isEmpty || endTime.isEmpty) {
        showSnack("Please select start & end time");
        return;
      }

      if (!isEndGreater(startTime, endTime)) {
        showSnack("End time must be greater than start time");
        return;
      }
    }

    final draftProvider = ref.read(pgDraftProvider);

    draftProvider.update(() {
      draftProvider.draft.availabilityDay = availability;

      draftProvider.draft.startTime = allDay ? null : convertTo24(startTime);

      draftProvider.draft.endTime = allDay ? null : convertTo24(endTime);

      draftProvider.draft.availableAllDay = allDay;
    });

    await submitPG();
  }

  Future<void> submitPG() async {
    final draft = ref.read(pgDraftProvider).draft;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final propertyId = prefs.getInt("propertyId");

    if (token == null || propertyId == null) {
      showSnack("Session expired");
      return;
    }

    try {
      setState(() => isLoading = true);

      // -- 1. Details (handles property info + location fields) -------------
      final propRes = await http.put(
        Uri.parse("$apiBase/property/$propertyId/details"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "propertyName": draft.propertyName,
          "preferredTenant": draft.preferredTenant,
          "preferredGuests": draft.preferredGuests,
          "landmark": draft.landmark,
          "noticePeriod": draft.noticePeriod ?? 0,
          "availableFrom": draft.availableFrom?.toIso8601String(),
          "gateClosingTime": draft.gateClosingTime,
          "roomType": draft.roomType,
          // ? location fields go here � UpdateLocationDto only takes lat/lng
          "city": draft.city,
          "locality": draft.locality,
          "street": draft.street,
          "latitude": draft.latitude,
          "longitude": draft.longitude,
        }),
      );
      debugPrint("DETAILS: ${propRes.statusCode} | ${propRes.body}");

      // -- 2. Location (only lat/lng � that's all UpdateLocationDto accepts) -
      final locRes = await http.put(
        Uri.parse("$apiBase/property/location/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": draft.latitude,
          "longitude": draft.longitude,
        }),
      );
      debugPrint("LOCATION: ${locRes.statusCode} | ${locRes.body}");

      // -- 3. Amenities -----------------------------------------------------
      // ? restrictions key is "nonVegAllowed" not "nonVeg"
      final amenRes = await http.put(
        Uri.parse("$apiBase/property/$propertyId/amenities"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "parking": draft.parking,
          "foodIncluded": draft.foodIncluded,
          "foodType": draft.foodType,
          "pgAmenities": draft.pgAmenities,
          "restrictions": {
            "smoking": draft.restrictions["smoking"] ?? false,
            "drinking": draft.restrictions["drinking"] ?? false,
            "loudMusic": draft.restrictions["loudMusic"] ?? false,
            "nonVegAllowed":
                draft.restrictions["nonVeg"] ?? false, // ? key rename
            "girlsEntry": draft.restrictions["girlsEntry"] ?? false,
          },
          "propertyDescription": draft.propertyDescription,
        }),
      );
      debugPrint("AMENITIES: ${amenRes.statusCode} | ${amenRes.body}");

      // -- 4. Contact -------------------------------------------------------
      final contactRes = await http.put(
        Uri.parse("$apiBase/property/$propertyId/contact"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contactName": draft.contactName,
          "mobileNo": draft.mobileNo,
          "whatsapp": draft.whatsapp,
          "whatsappupdates": draft.whatsappUpdates,
        }),
      );
      debugPrint("CONTACT: ${contactRes.statusCode} | ${contactRes.body}");

      // -- 5. Availability --------------------------------------------------
      final availRes = await http.put(
        Uri.parse("$apiBase/property/$propertyId/availability"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "availabilityDay": draft.availabilityDay == null
              ? []
              : [draft.availabilityDay],
          "startTime": draft.startTime,
          "endTime": draft.endTime,
          "availableAllDay": draft.availableAllDay,
          // ? isDraft removed � not in CreateScheduleDto
        }),
      );
      debugPrint("AVAILABILITY: ${availRes.statusCode} | ${availRes.body}");

      // -- 6. Upload Images -------------------------------------------------
      if (draft.images.isNotEmpty) {
        final request = http.MultipartRequest(
          "POST",
          Uri.parse("$apiBase/property/$propertyId/upload-images"),
        );
        request.headers["Authorization"] = "Bearer $token";
        for (final file in draft.images) {
          request.files.add(
            await http.MultipartFile.fromPath("files", file.path),
          );
        }
        final imgRes = await request.send();
        debugPrint("IMAGES: ${imgRes.statusCode}");
      }

      // -- 7. Upload Video --------------------------------------------------
      if (draft.video != null) {
        final request = http.MultipartRequest(
          "POST",
          Uri.parse("$apiBase/property/$propertyId/upload-video"),
        );
        request.headers["Authorization"] = "Bearer $token";
        request.files.add(
          await http.MultipartFile.fromPath("file", draft.video!.path),
        );
        final vidRes = await request.send();
        debugPrint("VIDEO: ${vidRes.statusCode}");
      }

      if (!mounted) return;

      ref.read(pgDraftProvider).clear();

      // ? Clear saved propertyId so next listing creates a fresh row
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("propertyId");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const PgOwnerNavigationScreen(initialIndex: 1),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint("submitPG error: $e");
      showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // -- Snackbar ---------------------------------------------------------------
  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
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
                                      onChanged: allDay
                                          ? null
                                          : (v) => setState(() {
                                              startTime = v.toString();
                                              endTime = "";
                                            }),
                                    ),
                                    const SizedBox(width: 12),
                                    _timeDropdown(
                                      label: "End Time",
                                      value: endTime,
                                      items: getFilteredEndTimes(),
                                      onChanged: allDay
                                          ? null
                                          : (v) => setState(
                                              () => endTime = v.toString(),
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
                                    startTime = "";
                                    endTime = "";
                                  }),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: allDay,
                                          onChanged: (v) => setState(() {
                                            allDay = v!;
                                            startTime = "";
                                            endTime = "";
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

                  // -- Sticky Finish Posting Button -------------------------
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
                        onPressed: isLoading ? null : saveSchedule,
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
