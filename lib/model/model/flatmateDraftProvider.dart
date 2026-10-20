import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/model/model/FlatmateDraft.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the entire Flatmate posting flow.
///
/// Each screen writes its fields into [draft] via [update].
/// Only [saveAll] (called from the final Schedule screen) hits the network.
class FlatmateDraftProvider extends ChangeNotifier {
  static const String _baseUrl = "https://rentit-backend-omega.vercel.app";

  final FlatmateDraft draft = FlatmateDraft();

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  // -- Reset -----------------------------------------------------------------

  void clear() {
    // Property Details
    draft.apartmentType = null;
    draft.apartmentName = null;
    draft.bhkType = null;
    draft.floor = null;
    draft.totalFloor = null;
    draft.roomType = null;
    draft.tenantType = null;
    draft.propertyAge = null;
    draft.facing = null;
    draft.builtUpArea = null;

    // Location
    draft.city = null;
    draft.propertyType = null;
    draft.locality = null;
    draft.street = null;
    draft.landmark = null;
    draft.latitude = null;
    draft.longitude = null;

    // Rent
    draft.expectedRent = null;
    draft.expectedDeposit = null;
    draft.maintenanceType = null;
    draft.maintenanceAmount = null;
    draft.availableFrom = null;
    draft.furnishing = null;
    draft.parking = null;
    draft.description = null;

    // Amenities / Room / Preferences
    draft.attachedBathroom = null;
    draft.bathroomType = null;
    draft.acRoom = null;
    draft.balcony = null;
    draft.nonVegAllowed = null;
    draft.smokingAllowed = null;
    draft.drinkingAllowed = null;
    draft.gym = null;
    draft.gatedSecurity = null;
    draft.liftSelected = false;
    draft.swimmingPoolSelected = false;
    draft.clubHouseSelected = false;
    draft.powerBackupSelected = false;
    draft.parkSelected = false;

    // Media
    draft.images = [];
    draft.existingImageUrls = [];
    draft.video = null;
    draft.existingVideoUrl = null;

    // Contact
    draft.whoShowsProperty = null;
    draft.secondaryNumber = null;
    draft.waterSupply = null;
    draft.directionsTip = null;

    // Schedule
    draft.availabilityDay = null;
    draft.startTime = null;
    draft.endTime = null;
    draft.availableAllDay = false;

    notifyListeners();
  }

  // -- SINGLE SAVE (called only from FlatmateScheduleScreen) -----------------

  /// Sends all collected data to the server in three steps:
  ///   1. PATCH  � all scalar fields
  ///   2. POST   � images (multipart), if any new ones were selected
  ///   3. POST   � video  (multipart), if a new video was selected
  ///
  /// Returns the updated Flatmate object from the server on success,
  /// or throws an [Exception] with a human-readable message on failure.
  Future<Map<String, dynamic>> saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    final flatmateId = prefs.getInt("flatmateId");
    final token = prefs.getString("token");

    if (flatmateId == null) throw Exception("Flatmate ID missing");
    if (token == null || token.isEmpty) throw Exception("Login token missing");

    // -- 1. PATCH scalar fields ---------------------------------------------
    final body = _buildPatchBody();

    debugPrint("FLATMATE PATCH ? $body");

    final patchRes = await http.patch(
      Uri.parse("$_baseUrl/flatmate/$flatmateId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint("PATCH STATUS  ? ${patchRes.statusCode}");
    debugPrint("PATCH BODY    ? ${patchRes.body}");

    if (patchRes.statusCode != 200 && patchRes.statusCode != 201) {
      throw Exception("Save failed (${patchRes.statusCode}): ${patchRes.body}");
    }

    // -- 2. Upload images ---------------------------------------------------
    if (draft.images.isNotEmpty) {
      await _uploadImages(flatmateId, token);
    }

    // -- 3. Upload video ----------------------------------------------------
    if (draft.video != null) {
      await _uploadVideo(flatmateId, token);
    }

    // -- Done ---------------------------------------------------------------
    final data = jsonDecode(patchRes.body) as Map<String, dynamic>;

    // Persist updated id (create flow may have generated a new record earlier)
    await prefs.setInt("flatmateId", data["id"] ?? flatmateId);

    return data;
  }

  // -- Private helpers -------------------------------------------------------

  Map<String, dynamic> _buildPatchBody() {
    final d = draft;
    return {
      // Property Details
      if (d.apartmentType != null) "apartmentType": d.apartmentType,
      if (d.apartmentName != null) "apartmentName": d.apartmentName,
      if (d.bhkType != null) "bhkType": d.bhkType,
      if (d.floor != null) "floor": d.floor,
      if (d.totalFloor != null) "totalFloor": d.totalFloor,
      if (d.roomType != null) "roomType": d.roomType,
      if (d.tenantType != null) "tenantType": d.tenantType,
      if (d.propertyAge != null) "propertyAge": d.propertyAge,
      if (d.facing != null) "facing": d.facing,
      if (d.builtUpArea != null) "builtUpArea": d.builtUpArea,

      // Location
      if (d.city != null) "city": d.city,
      if (d.propertyType != null) "propertyType": d.propertyType,
      if (d.locality != null) "locality": d.locality,
      if (d.street != null) "street": d.street,
      if (d.landmark != null) "landmark": d.landmark,
      if (d.latitude != null) "latitude": d.latitude,
      if (d.longitude != null) "longitude": d.longitude,

      // Rent
      if (d.expectedRent != null) "expectedRent": d.expectedRent,
      if (d.expectedDeposit != null) "expectedDeposit": d.expectedDeposit,
      if (d.maintenanceType != null) "maintenanceType": d.maintenanceType,
      if (d.maintenanceAmount != null) "maintenanceAmount": d.maintenanceAmount,
      if (d.availableFrom != null)
        "availableFrom": d.availableFrom!.toIso8601String(),
      if (d.furnishing != null) "furnishing": d.furnishing,
      if (d.parking != null) "parking": d.parking,
      if (d.description != null) "description": d.description,

      // Room
      if (d.attachedBathroom != null) "attachedBathroom": d.attachedBathroom,
      if (d.bathroomType != null) "bathroomType": d.bathroomType,
      if (d.acRoom != null) "acRoom": d.acRoom,
      if (d.balcony != null) "balcony": d.balcony,

      // Preferences
      if (d.nonVegAllowed != null) "nonVegAllowed": d.nonVegAllowed,
      if (d.smokingAllowed != null) "smokingAllowed": d.smokingAllowed,
      if (d.drinkingAllowed != null) "drinkingAllowed": d.drinkingAllowed,

      // Amenities
      if (d.gym != null) "gym": d.gym,
      if (d.gatedSecurity != null) "gatedSecurity": d.gatedSecurity,
      "liftSelected": d.liftSelected,
      "swimmingPoolSelected": d.swimmingPoolSelected,
      "clubHouseSelected": d.clubHouseSelected,
      "powerBackupSelected": d.powerBackupSelected,
      "parkSelected": d.parkSelected,

      // Contact
      if (d.whoShowsProperty != null) "whoShowsProperty": d.whoShowsProperty,
      if (d.secondaryNumber != null) "secondaryNumber": d.secondaryNumber,
      if (d.waterSupply != null) "waterSupply": d.waterSupply,
      if (d.directionsTip != null) "directionsTip": d.directionsTip,

      // Schedule
      "availabilityDay": d.availabilityDay is List
          ? d.availabilityDay
          : (d.availabilityDay != null ? [d.availabilityDay] : []),
      if (d.startTime != null) "startTime": d.startTime,
      if (d.endTime != null) "endTime": d.endTime,
      "availableAllDay": d.availableAllDay,
    };
  }

  Future<void> _uploadImages(int flatmateId, String token) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$_baseUrl/flatmate/$flatmateId/upload-images"),
    );
    request.headers["Authorization"] = "Bearer $token";
    // Pass existing server URLs so the backend merges, not replaces
    request.fields["existingImages"] = jsonEncode(draft.existingImageUrls);

    for (final file in draft.images) {
      request.files.add(await http.MultipartFile.fromPath("files", file.path));
    }

    final res = await request.send();
    final body = await res.stream.bytesToString();

    debugPrint("IMAGE UPLOAD STATUS ? ${res.statusCode}");
    debugPrint("IMAGE UPLOAD BODY   ? $body");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Image upload failed (${res.statusCode})");
    }
  }

  Future<void> _uploadVideo(int flatmateId, String token) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$_baseUrl/flatmate/$flatmateId/upload-video"),
    );
    request.headers["Authorization"] = "Bearer $token";
    request.files.add(
      await http.MultipartFile.fromPath("file", draft.video!.path),
    );

    final res = await request.send();
    final body = await res.stream.bytesToString();

    debugPrint("VIDEO UPLOAD STATUS ? ${res.statusCode}");
    debugPrint("VIDEO UPLOAD BODY   ? $body");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Video upload failed (${res.statusCode})");
    }
  }
}
