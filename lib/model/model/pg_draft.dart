import 'dart:io';

class PGDraft {
  // -- Room ------------------------------------------------------------------
  List<Map<String, dynamic>> roomType = []; // matches DB column: roomType (Json)

  // -- Property Details ------------------------------------------------------
  String? propertyName;
  List<String> preferredTenant = [];  // DB: preferredTenant Json (array)
  List<String> preferredGuests = [];  // DB: preferredGuests Json (array)
  String? landmark;
  int? noticePeriod;                  // DB: noticePeriod Int
  DateTime? availableFrom;            // DB: availableFrom DateTime
  String? gateClosingTime;            // DB: gateClosingTime stored as String, sent as DateTime

  // -- Location --------------------------------------------------------------
  String? city;
  String? locality;
  String? street;
  double? latitude;
  double? longitude;

  // -- Amenities -------------------------------------------------------------
  bool foodIncluded = false;           // DB: foodIncluded Boolean
  Map<String, bool> foodType = {
    "breakfast": false,
    "lunch": false,
    "dinner": false,
  };
  Map<String, bool> pgAmenities = {
    "laundry": false,
    "roomCleaning": false,
    "wifi": false,
    "commonTV": false,
    "lift": false,
    "powerBackup": false,
    "refrigerator": false,
    "mess": false,
  };
  Map<String, bool> restrictions = {
    "smoking": false,
    "drinking": false,
     "nonVegAllowed": false,
    "girlsEntry": false,
    "loudMusic": false,
  };
  String? parking;
  String? propertyDescription;

  // -- Media -----------------------------------------------------------------
  List<File> images = [];              // uploaded separately via multipart
  File? video;                         // uploaded separately via multipart

  // -- Contact ---------------------------------------------------------------
  String? contactName;
  String? mobileNo;
  bool whatsapp = true;                // DB: whatsapp Boolean
  bool whatsappUpdates = true;         // DB: whatsappupdates Boolean

  // -- Availability ----------------------------------------------------------
  String? availabilityDay;             // DB: availabilityDay Json (sent as array)
  String? startTime;                   // DB: startTime String
  String? endTime;                     // DB: endTime String
  bool availableAllDay = false;        // DB: availableAllDay Boolean
}
