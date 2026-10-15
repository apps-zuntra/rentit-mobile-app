import 'dart:io';

/// Holds every field collected across all Flatmate posting screens.
/// Nothing is sent to the server until the final schedule screen.
class FlatmateDraft {
  // -- STEP 1 — Property Details ---------------------------------------------
  String? apartmentType;
  String? apartmentName;
  String? bhkType;
  String? floor;
  String? totalFloor;
  String? roomType;
  String? tenantType;
  String? propertyAge;
  String? facing;
  double? builtUpArea;

  // -- STEP 2 — Location -----------------------------------------------------
  String? city;           // carried from the BasicScreen / route argument
  String? propertyType;   // carried from the BasicScreen
  String? locality;
  String? street;
  String? landmark;
  double? latitude;
  double? longitude;

  // -- STEP 3 — Rent ---------------------------------------------------------
  double? expectedRent;
  double? expectedDeposit;
  String? maintenanceType;
  double? maintenanceAmount;
  DateTime? availableFrom;
  String? furnishing;
  String? parking;
  String? description;

  // -- STEP 4 — Amenities / Room / Preferences -------------------------------
  bool? attachedBathroom;
  String? bathroomType;
  bool? acRoom;
  bool? balcony;

  bool? nonVegAllowed;
  bool? smokingAllowed;
  bool? drinkingAllowed;

  bool? gym;
  bool? gatedSecurity;
  bool liftSelected        = false;
  bool swimmingPoolSelected = false;
  bool clubHouseSelected   = false;
  bool powerBackupSelected = false;
  bool parkSelected        = false;

  // -- STEP 5 — Media (uploaded separately at the end) -----------------------
  List<File> images        = [];
  List<String> existingImageUrls = []; // urls already on server (edit mode)
  File? video;
  String? existingVideoUrl;

  // -- STEP 6 — Contact ------------------------------------------------------
  String? whoShowsProperty;
  String? secondaryNumber;
  String? waterSupply;
  String? directionsTip;

  // -- STEP 7 — Schedule -----------------------------------------------------
  dynamic availabilityDay;   // sent as List<String>, e.g. ["Weekdays"]
  String? startTime;         // 24-h format: "09:00"
  String? endTime;           // 24-h format: "18:00"
  bool availableAllDay = false;
}
