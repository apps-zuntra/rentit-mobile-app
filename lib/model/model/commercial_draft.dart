import 'dart:io';

class CommercialDraft {
  // ── Location ───────────────────────────────────────────
  String? city;
  String? locality;
  String? street;
  String? landmark;
  double? latitude;
  double? longitude;

  // ── Property Details ───────────────────────────────────
  String? propertyType;
  String? buildingType;
  String? propertyAge;

  int? floor;
  int? totalFloor;
  int? builtUpArea;

  Map<String, dynamic> furnishing = {};
  Map<String, dynamic> otherFeatures = {};

  // ── Rent Details ───────────────────────────────────────
  String? rentType;
  int? expectedRent;
  int? deposit;
  int? maintenanceAmount;

  String? maintenance;

  bool rentNegotiable = false;
  bool depositNegotiable = false;
  bool maintenanceExtra = false;

  String? leaseDuration;
  String? lockinPeriod;
  DateTime? availableFrom;

  // ── Commercial Details ────────────────────────────────
  List<String> idealFor = [];

  String? addOthertags;

  String? commercialPropertyType;

  Map<String, dynamic> commercialOtherFeatures = {};

  String? slots;

  // ── Contact ────────────────────────────────────────────
  String? contactName;
  String? mobileNo;

  bool whatsapp = true;

  // ── Media ──────────────────────────────────────────────
  List<File> images = [];
  File? video;

  // ── Description & Property Info ────────────────────────
  String? description;
  String? previousOccupancy;
  bool? propertyCleaning;
  bool? propertyPainting;
  String? whoShowsProperty;

  // ── Availability ──────────────────────────────────────
  List<String> availabilityDay = [];

  String? startTime;
  String? endTime;

  bool availableAllDay = false;
}
