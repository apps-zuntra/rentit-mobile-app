// PGSchedule.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/main/rental_home.dart';
import 'package:rentit/providers/pg_draft_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------
// API Config
// ---------------------------------------------
class _ApiConfig {
  static const String baseUrl = "https://rentit-backend-omega.vercel.app";
  static const String property = '$baseUrl/property';
}

// ---------------------------------------------
// Screen
// ---------------------------------------------
class PGScheduleForm extends ConsumerStatefulWidget {
  const PGScheduleForm({super.key});

  @override
  ConsumerState<PGScheduleForm> createState() => _PGScheduleFormState();
}

class _PGScheduleFormState extends ConsumerState<PGScheduleForm> {
  // -- State --
  String availability = '';
  String startTime = '';
  String endTime = '';
  bool allDay = false;
  bool isLoading = false;

  // -- Colors --
  static const Color _primary = Color(0xFF00897B);
  static const Color _red = Color(0xFFE53935);

  // -- Time Options --
  late final List<String> timeOptions;

  // ---------------------------------------------
  // Lifecycle
  // ---------------------------------------------
  @override
  void initState() {
    super.initState();
    timeOptions = _generateTimeOptions();
    _loadExistingData();
  }

  // ---------------------------------------------
  // Time Helpers
  // ---------------------------------------------

  /// Generates 30-minute interval time slots: 12:00 AM ➔ 11:30 PM
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

  /// Converts "02:30 PM" ➔ "14:30"
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

  /// Converts "14:30" ➔ "02:30 PM"
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
  // Load Existing Data (Edit Mode)
  // ---------------------------------------------
  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? propertyId = prefs.getInt('propertyId');
      final String? token = prefs.getString('token');

      debugPrint('SCHEDULE LOAD PROPERTY ID ?? $propertyId');

      if (propertyId == null) return;
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${_ApiConfig.property}/$propertyId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('SCHEDULE GET STATUS ?? ${response.statusCode}');
      debugPrint('SCHEDULE GET BODY ?? ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          // ? Availability Day
          final availabilityDay = data['availabilityDay'];
          if (availabilityDay is List && availabilityDay.isNotEmpty) {
            availability = availabilityDay.first.toString();
          } else if (availabilityDay is String && availabilityDay.isNotEmpty) {
            availability = availabilityDay;
          }

          // ? Available All Day
          allDay = data['availableAllDay'] ?? false;

          // ? Start Time
          final rawStart = data['startTime'];
          if (rawStart != null && rawStart.toString().trim().isNotEmpty) {
            startTime = _convertTo12(rawStart.toString());
          } else {
            startTime = '';
          }

          // ? End Time
          final rawEnd = data['endTime'];
          if (rawEnd != null && rawEnd.toString().trim().isNotEmpty) {
            endTime = _convertTo12(rawEnd.toString());
          } else {
            endTime = '';
          }

          // ? If All Day ➔ Clear time dropdowns
          if (allDay) {
            startTime = '';
            endTime = '';
          }
        });

        debugPrint('? Loaded Availability: $availability');
        debugPrint('? Loaded All Day: $allDay');
        debugPrint('? Loaded Start Time: $startTime');
        debugPrint('? Loaded End Time: $endTime');
      }
    } catch (e) {
      debugPrint('? LOAD SCHEDULE ERROR ?? $e');
    }
  }

  // ---------------------------------------------
  // Save Schedule & Submit PG
  // ---------------------------------------------
  Future<void> _saveSchedule() async {
    // Validation
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

    final draftProvider = ref.read(pgDraftProvider);

    draftProvider.update(() {
      draftProvider.draft.availabilityDay = availability;
      draftProvider.draft.startTime = allDay ? null : _convertTo24(startTime);
      draftProvider.draft.endTime = allDay ? null : _convertTo24(endTime);
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
      _showSnackBar("Session expired or Property ID missing");
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final String apiBase = _ApiConfig.baseUrl;

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
          "city": draft.city,
          "locality": draft.locality,
          "street": draft.street,
          "latitude": draft.latitude,
          "longitude": draft.longitude,
        }),
      );
      debugPrint("DETAILS: ${propRes.statusCode} | ${propRes.body}");

      // -- 2. Location (only lat/lng) ---------------------------------------
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
            "nonVegAllowed": draft.restrictions["nonVegAllowed"] ?? false,
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

        final res = await request.send();
        final body = await res.stream.bytesToString();
        debugPrint("IMAGES: ${res.statusCode} | $body");
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

        final res = await request.send();
        final body = await res.stream.bytesToString();
        debugPrint("VIDEO: ${res.statusCode} | $body");
      }

      if (!mounted) return;
      setState(() => isLoading = false);

      _showSnackBar('Property posted successfully', success: true);

      // Clear draft after success
      ref.read(pgDraftProvider).clear();

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RentHomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('SAVE PROPERTY ERROR ?? $e');
      _showSnackBar('Something went wrong during submit');
    }
  }

  // ---------------------------------------------
  // Snack Bar
  // ---------------------------------------------
  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? _primary : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------
  // Widget Helpers
  // ---------------------------------------------
  Widget _buildAvailabilityOption(String label, String sub) {
    final bool active = availability == label;
    return GestureDetector(
      onTap: () => setState(() => availability = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        width: 100,
        decoration: BoxDecoration(
          color: active ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _primary),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                color: active ? Colors.white70 : _primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------
  // Build
  // ---------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7F9),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Availability --
            const Text(
              'Availability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAvailabilityOption('Everyday', 'Mon-Sun'),
                _buildAvailabilityOption('Weekday', 'Mon-Fri'),
                _buildAvailabilityOption('Weekend', 'Sat, Sun'),
              ],
            ),

            const SizedBox(height: 25),

            // -- Time Schedule --
            const Text(
              'Select Time Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // Start Time
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: startTime.isEmpty ? null : startTime,
                    decoration: const InputDecoration(
                      labelText: 'Start Time..',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: timeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: allDay
                        ? null
                        : (v) {
                            setState(() {
                              startTime = v ?? '';
                              endTime = ''; // reset end time on start change
                            });
                          },
                  ),
                ),
                const SizedBox(width: 10),
                // End Time
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: endTime.isEmpty ? null : endTime,
                    decoration: const InputDecoration(
                      labelText: 'End Time',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _getFilteredEndTimes()
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: allDay
                        ? null
                        : (v) => setState(() => endTime = v ?? ''),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // -- All Day Checkbox --
            Row(
              children: [
                Checkbox(
                  value: allDay,
                  activeColor: _primary,
                  onChanged: (v) {
                    setState(() {
                      allDay = v ?? false;
                      startTime = '';
                      endTime = '';
                    });
                  },
                ),
                const Text('Available All Day', style: TextStyle(fontSize: 15)),
              ],
            ),

            const Spacer(),

            // -- Save Button --
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save And Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
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
