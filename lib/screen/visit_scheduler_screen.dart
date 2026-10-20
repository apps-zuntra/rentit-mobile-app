// visit_scheduler_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/main/MyActivityScreen.dart';
import 'package:rentit/notification/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitSchedulerScreen extends ConsumerStatefulWidget {
  final int propertyId;
  final String propertyType;
  final int? visitId;
  final String? initialTime;
  final String? initialDate;

  const VisitSchedulerScreen({
    super.key,
    required this.propertyId,
    required this.propertyType,
    this.visitId,
    this.initialTime,
    this.initialDate,
  });

  @override
  ConsumerState<VisitSchedulerScreen> createState() =>
      _VisitSchedulerScreenState();
}

class _VisitSchedulerScreenState extends ConsumerState<VisitSchedulerScreen> {
  static const String _kBase = "https://rentit-backend-omega.vercel.app";

  int activeIndex = 0;
  String? selectedTime;
  bool loading = false;

  String? fetchedStartTime;
  String? fetchedEndTime;
  bool fetchedAllDay = false;
  DateTime? availableFrom;

  bool _timePreselected = false;

  int? _ownerUserId;
  String? _cachedPropertyName;

  // -- NEW: already-booked state ---------------------------------------------
  bool _checkingBooking = true;
  Map<String, dynamic>? _existingVisit; // non-null ? already booked

  // -- Lifecycle --------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
    // Only check existing booking when NOT in reschedule mode
    if (widget.visitId == null) {
      _checkExistingBooking();
    } else {
      _checkingBooking = false;
    }
  }

  // -- Check whether this user already has a live visit for this property -----

  Future<void> _checkExistingBooking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        if (mounted) setState(() => _checkingBooking = false);
        return;
      }

      final res = await http.get(
        Uri.parse('$_kBase/visit/property/${widget.propertyId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final body = jsonDecode(res.body);
        // API returns null / empty object when no visit exists
        if (body != null && body is Map && body.isNotEmpty) {
          setState(() {
            _existingVisit = Map<String, dynamic>.from(body);
            _checkingBooking = false;
          });
          return;
        }
      }

      setState(() => _checkingBooking = false);
    } catch (e) {
      debugPrint('? _checkExistingBooking error: $e');
      if (mounted) setState(() => _checkingBooking = false);
    }
  }

  // -- API: fetch property availability + extract owner id --------------------

  Future<void> _fetchAvailability() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final type = widget.propertyType.toLowerCase().trim();

      final List<String> endpoints = [];
      if (type.contains('flatmate')) {
        endpoints.add('$_kBase/flatmate/${widget.propertyId}');
      } else if (type.contains('commercial')) {
        endpoints.add('$_kBase/commercial/${widget.propertyId}');
      } else if (type.contains('apartment')) {
        endpoints.add('$_kBase/apartment/${widget.propertyId}');
      } else {
        endpoints.add('$_kBase/property/${widget.propertyId}');
      }

      // Add other endpoints as fallback
      for (final fallback in [
        '$_kBase/property/${widget.propertyId}',
        '$_kBase/apartment/${widget.propertyId}',
        '$_kBase/commercial/${widget.propertyId}',
        '$_kBase/flatmate/${widget.propertyId}',
      ]) {
        if (!endpoints.contains(fallback)) endpoints.add(fallback);
      }

      DateTime fromDate = DateTime.now();
      String? startTime;
      String? endTime;
      bool allDay = false;
      String? propName;
      int? ownerUserId;

      for (final ep in endpoints) {
        try {
          final res = await http.get(
            Uri.parse(ep),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            try {
              final raw = data['availableFrom'];
              if (raw != null && raw.toString().isNotEmpty) {
                final parsed = DateTime.parse(raw.toString());
                final now = DateTime.now();
                if (parsed.year >= now.year && parsed.year <= now.year + 1) {
                  fromDate = parsed;
                } else {
                  fromDate = now;
                }
              }
            } catch (_) {}

            startTime = data['startTime']?.toString();
            endTime = data['endTime']?.toString();
            allDay = data['availableAllDay'] == true;
            propName =
                data['propertyName']?.toString() ??
                data['bhkType']?.toString() ??
                data['commercialPropertyType']?.toString();

            ownerUserId =
                _parseInt(data['userId']) ??
                _parseInt(data['ownerId']) ??
                _parseInt((data['owner'] as Map?)?['id']) ??
                _parseInt((data['user'] as Map?)?['id']);

            break; // found valid property
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        availableFrom = fromDate;
        fetchedStartTime = startTime;
        fetchedEndTime = endTime;
        fetchedAllDay = allDay;
        _cachedPropertyName = propName;
        _ownerUserId = ownerUserId;
      });

      _preSelectInitialDate();
      _scheduleTimePreselection();
    } catch (e) {
      debugPrint('? _fetchAvailability error: $e');
      if (!mounted) return;
      setState(() {
        availableFrom = DateTime.now();
        fetchedStartTime = null;
        fetchedEndTime = null;
        fetchedAllDay = false;
      });
      _preSelectInitialDate();
      _scheduleTimePreselection();
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final n = int.tryParse(v.toString());
    return (n != null && n > 0) ? n : null;
  }

  String get _displayPropertyName => _cachedPropertyName?.isNotEmpty == true
      ? _cachedPropertyName!
      : widget.propertyType;

  // -- Date helpers -----------------------------------------------------------

  void _preSelectInitialDate() {
    if (widget.initialDate == null || availableFrom == null || !mounted) return;
    try {
      final target = DateTime.parse(widget.initialDate!).toLocal();
      final dates = _getDates();
      final idx = dates.indexWhere(
        (d) =>
            d.year == target.year &&
            d.month == target.month &&
            d.day == target.day,
      );
      if (idx >= 0) setState(() => activeIndex = idx);
    } catch (e) {
      debugPrint('? _preSelectInitialDate error: $e');
    }
  }

  void _scheduleTimePreselection() {
    if (widget.initialTime == null || _timePreselected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _timePreselected) return;
      _timePreselected = true;
      try {
        final t24 = _convertTo24(widget.initialTime!);
        final parts = t24.split(':');
        if (parts.length != 2) return;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) return;
        final formatted = TimeOfDay(hour: h, minute: m).format(context);
        final slots = _generateTimeSlots();
        if (slots.contains(formatted)) setState(() => selectedTime = formatted);
      } catch (e) {
        debugPrint('? _scheduleTimePreselection error: $e');
      }
    });
  }

  List<DateTime> _getDates() {
    final today = DateTime.now();
    DateTime from = availableFrom ?? today;
    if (from.year > today.year + 1 || from.year < today.year - 1) {
      from = today;
    }
    final start = today.isAfter(from) ? today : from;
    return List.generate(15, (i) => start.add(Duration(days: i)));
  }

  List<String> _generateTimeSlots() {
    if (fetchedAllDay) {
      return [
        for (int h = 0; h < 24; h++)
          for (int m = 0; m < 60; m += 30)
            TimeOfDay(hour: h, minute: m).format(context),
      ];
    }
    if (fetchedStartTime == null || fetchedEndTime == null) {
      return [
        for (int h = 7; h <= 22; h++)
          for (int m = 0; m < 60; m += 30)
            TimeOfDay(hour: h, minute: m).format(context),
      ];
    }
    final start24 = _convertTo24(fetchedStartTime!);
    final end24 = _convertTo24(fetchedEndTime!);
    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final slots = <String>[];
    for (int min = toMin(start24); min < toMin(end24); min += 30) {
      slots.add(TimeOfDay(hour: min ~/ 60, minute: min % 60).format(context));
    }
    return slots;
  }

  String _convertTo24(String time) {
    try {
      time = time.trim().replaceAll(RegExp(r'\s+'), ' ');
      // Replace dot separators if used (e.g. "9.00" -> "9:00", "09.30 AM" -> "09:30 AM")
      if (time.contains('.')) {
        time = time.replaceAll('.', ':');
      }

      if (!time.toUpperCase().contains('AM') &&
          !time.toUpperCase().contains('PM')) {
        final parts = time.split(':');
        if (parts.isNotEmpty) {
          final h = int.parse(parts[0]);
          final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
          return '${h.toString().padLeft(2, '0')}:$m';
        }
      }
      final parts = time.split(' ');
      if (parts.length >= 2) {
        final hm = parts[0].split(':');
        int hour = int.parse(hm[0]);
        final minute = hm.length > 1 ? hm[1].padLeft(2, '0') : '00';
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return '${hour.toString().padLeft(2, '0')}:$minute';
      }
      return '00:00';
    } catch (e) {
      debugPrint('⚠️ _convertTo24("$time") error: $e');
      return '00:00';
    }
  }

  bool _isPastTime(String slotTime, DateTime selectedDate) {
    try {
      final t24 = _convertTo24(slotTime);
      final date =
          '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';
      return DateTime.parse('${date}T$t24').isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _humanDate(DateTime d) =>
      '${_weekdayLabel(d.weekday)}, '
      '${d.day.toString().padLeft(2, '0')} '
      '${_monthLabel(d.month)} '
      '${d.year}';

  // -- Format existing visit date/time for display ----------------------------

  String _formatExistingVisitDate(Map<String, dynamic> visit) {
    try {
      final rawDate = visit['date']?.toString() ?? '';
      final rawTime = visit['time']?.toString() ?? '';
      if (rawDate.isEmpty) return 'Your visit has been scheduled';

      final d = DateTime.parse(rawDate);
      final dateStr =
          '${_weekdayLabel(d.weekday)}, ${d.day.toString().padLeft(2, '0')} '
          '${_monthLabel(d.month)} ${d.year}';

      if (rawTime.isEmpty) return dateStr;

      // Convert "HH:mm" ? "h:mm AM/PM"
      final parts = rawTime.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final disp = TimeOfDay(hour: h, minute: m).format(context);
        return '$dateStr at $disp';
      }
      return dateStr;
    } catch (_) {
      return 'Your visit has been scheduled';
    }
  }

  // -- Confirm / Submit -------------------------------------------------------

  Future<void> _handleConfirm(List<DateTime> dates) async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot ??')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('User not logged in');

      final date = dates[activeIndex];
      final dateStr =
          '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final time24 = _convertTo24(selectedTime!);

      late http.Response res;

      if (widget.visitId != null) {
        res = await http.patch(
          Uri.parse('$_kBase/visit/${widget.visitId}/reschedule'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'date': dateStr, 'time': time24}),
        );
      } else {
        res = await http.post(
          Uri.parse('$_kBase/visit'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'propertyId': widget.propertyId,
            'date': dateStr,
            'time': time24,
            'propertyType': widget.propertyType,
          }),
        );
      }

      debugPrint('?? Status : ${res.statusCode}');
      debugPrint('?? Body   : ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;

        int? newVisitId = widget.visitId;
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          newVisitId ??= body['id'] as int? ?? body['visitId'] as int?;

          if (_ownerUserId == null) {
            _ownerUserId =
                _parseInt(body['userId']) ??
                _parseInt(body['ownerId']) ??
                _parseInt((body['property'] as Map?)?['userId']) ??
                _parseInt((body['property'] as Map?)?['ownerId']) ??
                _parseInt((body['apartment'] as Map?)?['userId']) ??
                _parseInt((body['apartment'] as Map?)?['ownerId']);

            debugPrint('?? ownerUserId from booking response: $_ownerUserId');
          }
        } catch (_) {}

        debugPrint('?? VISIT BOOK SUCCESS');
        debugPrint('?? Response Body = ${res.body}');
        debugPrint('?? Owner UserId = $_ownerUserId');
        debugPrint('?? SEND NOTIFICATION');
        debugPrint('? Notification sent');
        debugPrint('? Response = ${res.body}');

        final humanDate = _humanDate(date);

        if (widget.visitId != null) {
          await NotificationService.addVisitRescheduledNotification(
            propertyName: _displayPropertyName,
            propertyType: widget.propertyType,
            date: humanDate,
            time: selectedTime!,
            propertyId: widget.propertyId,
            visitId: newVisitId,
            ownerUserId: _ownerUserId,
          );
        } else {
          await NotificationService.addVisitBookedNotification(
            propertyName: _displayPropertyName,
            propertyType: widget.propertyType,
            date: humanDate,
            time: selectedTime!,
            propertyId: widget.propertyId,
            visitId: newVisitId,
            ownerUserId: _ownerUserId,
          );
        }

        debugPrint('?? Notifications dispatched');
        debugPrint('?? Owner UserId = $_ownerUserId');
        debugPrint('?? Notifications dispatched (self + owner: $_ownerUserId)');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.visitId != null
                  ? '? Visit rescheduled successfully!'
                  : '? Visit booked successfully!',
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );

        ref.invalidate(visitProvider);
        Navigator.pop(context, true);
      } else {
        String errMsg = 'Something went wrong. Please try again.';
        try {
          final body = jsonDecode(res.body);
          errMsg =
              body['message']?.toString() ??
              body['error']?.toString() ??
              errMsg;
        } catch (_) {
          if (res.body.isNotEmpty) errMsg = res.body;
        }
        throw errMsg;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // -- Build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Show loader while both availability AND booking-check are in progress
    if (availableFrom == null || _checkingBooking) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.visitId != null ? 'Reschedule Visit' : 'Schedule Visit',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // -- Already-booked view -------------------------------------------------
    if (_existingVisit != null) {
      return _buildAlreadyBookedView();
    }

    // -- Normal scheduling view ----------------------------------------------
    final dates = _getDates();
    final slots = _generateTimeSlots();
    final isReschedule = widget.visitId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isReschedule ? 'Reschedule Visit' : 'Schedule Visit',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Header banner ----------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2B40), Color(0xFF2F4253)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isReschedule
                              ? Icons.event_repeat_rounded
                              : Icons.calendar_month_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isReschedule
                              ? 'Choose a new date & time'
                              : 'Schedule your FREE visit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Property type: ${widget.propertyType}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        if (isReschedule) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '?? Rescheduling existing visit',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -- Select Date ------------------------------------------
                  const Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dates.length,
                      itemBuilder: (_, i) {
                        final d = dates[i];
                        final isActive = activeIndex == i;
                        return GestureDetector(
                          onTap: () => setState(() {
                            activeIndex = i;
                            selectedTime = null;
                            _timePreselected = true;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 70,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF1A2B40)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: isActive
                                  ? null
                                  : Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _weekdayLabel(d.weekday),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _monthLabel(d.month),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isActive
                                        ? Colors.white54
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // -- Select Time ------------------------------------------
                  Row(
                    children: [
                      const Text(
                        'Select Time',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      if (selectedTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            selectedTime!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  slots.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'No time slots available for this property.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: slots.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemBuilder: (_, i) {
                            final slotTime = slots[i];
                            final isPast = _isPastTime(
                              slotTime,
                              dates[activeIndex],
                            );
                            final isSelected = selectedTime == slotTime;
                            return GestureDetector(
                              onTap: isPast
                                  ? null
                                  : () =>
                                        setState(() => selectedTime = slotTime),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.orange.shade50
                                      : isPast
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.orange
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    slotTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.orange.shade800
                                          : isPast
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 20),

                  // -- Selected summary card --------------------------------
                  if (selectedTime != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FAF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0A7C66).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF0A7C66),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isReschedule
                                      ? 'Rescheduling to'
                                      : 'Visit scheduled for',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${_weekdayLabel(dates[activeIndex].weekday)}, '
                                  '${dates[activeIndex].day} '
                                  '${_monthLabel(dates[activeIndex].month)} '
                                  '${dates[activeIndex].year} '
                                  'at $selectedTime',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0A7C66),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // -- Confirm button ---------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: loading ? null : () => _handleConfirm(dates),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2B40),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isReschedule ? 'Confirm Reschedule' : 'Confirm Booking',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Already-booked full screen ---------------------------------------------

  Widget _buildAlreadyBookedView() {
    final visit = _existingVisit!;
    final visitDetails = _formatExistingVisitDate(visit);
    final status = (visit['status'] ?? 'pending').toString();

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'confirmed':
        statusColor = const Color(0xFF0A7C66);
        statusLabel = 'Confirmed';
        statusIcon = Icons.verified_rounded;
        break;
      case 'calling':
        statusColor = Colors.blue.shade700;
        statusLabel = 'In Progress';
        statusIcon = Icons.phone_in_talk_rounded;
        break;
      default: // pending
        statusColor = Colors.orange.shade700;
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Schedule Visit',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // -- Hero banner ----------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A2B40), const Color(0xFF2F4253)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Tick icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Visit Already Booked!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You have already scheduled a visit\nfor this property.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // -- Details card ---------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date & time
                  _detailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Scheduled For',
                    value: visitDetails,
                  ),

                  const SizedBox(height: 12),

                  // Status badge
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Property type
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.apartment_rounded,
                    label: 'Property Type',
                    value: widget.propertyType,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // -- Action buttons -------------------------------------------
            Column(
              children: [
                // Reschedule button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final visitId = _parseInt(visit['id']);
                      final rawDate = visit['date']?.toString();
                      final rawTime = visit['time']?.toString();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisitSchedulerScreen(
                            propertyId: widget.propertyId,
                            propertyType: widget.propertyType,
                            visitId: visitId,
                            initialDate: rawDate,
                            initialTime: rawTime,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(
                        color: Color(0xFF1A2B40),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.event_repeat_rounded,
                      size: 18,
                      color: Color(0xFF1A2B40),
                    ),
                    label: const Text(
                      'Reschedule Visit',
                      style: TextStyle(
                        color: Color(0xFF1A2B40),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Go back button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2B40),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Go Back',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  // -- Label helpers ----------------------------------------------------------

  String _weekdayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
