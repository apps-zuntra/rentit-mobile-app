import 'dart:io';

class ApartmentDraft {
  // -- Location ---------------------------------------------
  String? city;
  String? locality;
  String? street;
  String? landmark;

  double? latitude;
  double? longitude;

  // -- Property Details -------------------------------------
  String? propertyType2;
  String? apartmentType;
  String? buildingType;
  String? bhkType;

  int? floor;
  int? totalFloor;
  int? builtUpArea;

  String? propertyAge;
  String? facing;

  // -- Rent Details -----------------------------------------
  String? rentType;

  int? expectedRent;
  int? deposit;

  int? maintenanceAmount;
  String? maintenance;

  bool rentNegotiable = false;

  String? availableFrom;

  List<String> preferredTenant = [];

  // -- Features ---------------------------------------------
  String? furnishing;
  String? parking;
  String? description;

  Map<String, dynamic>? otherFeatures;

  // -- Additional Details ----------------------------------
  int? bathroom;
  int? noOfBalcony;

  dynamic waterSupply;

  bool petAllowed = false;
  bool gymAllowed = false;
  bool nonVegAllowed = false;
  bool gateSecurity = false;

  String? shownBy;

  dynamic propertyCondition;

  String? secondaryNumber;

  bool unitsPropertiesAvailable = false;

  String? directions;

  List<String> amenities = [];

  // -- Media ------------------------------------------------
  List<File> images = [];
  File? video;

  // Existing URLs (editing mode)
  List<String> uploadedImages = [];
  String? uploadedVideo;

  // -- Availability ----------------------------------------
  dynamic availabilityDay;

  String? startTime;
  String? endTime;

  bool availableAllDay = false;
}
