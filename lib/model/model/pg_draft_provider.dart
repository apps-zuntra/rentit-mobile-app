import 'package:flutter/material.dart';
import 'package:rentit/model/model/pg_draft.dart';

class PGDraftProvider extends ChangeNotifier {
  final PGDraft draft = PGDraft();

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  void clear() {
    // -- Room ----------------------------------------------------------------
    draft.roomType.clear();

    // -- Property Details ----------------------------------------------------
    draft.propertyName = null;
    draft.preferredTenant = [];
    draft.preferredGuests = [];
    draft.landmark = null;
    draft.noticePeriod = null;
    draft.availableFrom = null;
    draft.gateClosingTime = null;

    // -- Location ------------------------------------------------------------
    draft.city = null;
    draft.locality = null;
    draft.street = null;
    draft.latitude = null;
    draft.longitude = null;

    // -- Amenities -----------------------------------------------------------
    draft.foodIncluded = false;
    draft.foodType = {"breakfast": false, "lunch": false, "dinner": false};
    draft.pgAmenities = {
      "laundry": false,
      "roomCleaning": false,
      "wifi": false,
      "commonTV": false,
      "lift": false,
      "powerBackup": false,
      "refrigerator": false,
      "mess": false,
    };
    draft.restrictions = {
      "smoking": false,
      "drinking": false,
      "nonVeg": false,
      "girlsEntry": false,
      "loudMusic": false,
    };
    draft.parking = null;
    draft.propertyDescription = null;

    // -- Media ---------------------------------------------------------------
    draft.images = [];
    draft.video = null;

    // -- Contact -------------------------------------------------------------
    draft.contactName = null;
    draft.mobileNo = null;
    draft.whatsapp = true;
    draft.whatsappUpdates = true;

    // -- Availability ---------------------------------------------------------
    draft.availabilityDay = null;
    draft.startTime = null;
    draft.endTime = null;
    draft.availableAllDay = false;

    notifyListeners();
  }
}
