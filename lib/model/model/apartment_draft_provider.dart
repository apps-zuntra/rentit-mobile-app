import 'package:flutter/material.dart';
import 'package:rentit/model/model/apartment_draft.dart';

class ApartmentDraftProvider extends ChangeNotifier {
  final ApartmentDraft draft = ApartmentDraft();

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  void clear() {
    // -- Location -----------------------------------------
    draft.city = null;
    draft.locality = null;
    draft.street = null;
    draft.landmark = null;

    draft.latitude = null;
    draft.longitude = null;

    // -- Property Details --------------------------------
    draft.propertyType2 = null;
    draft.apartmentType = null;
    draft.buildingType = null;
    draft.bhkType = null;

    draft.floor = null;
    draft.totalFloor = null;
    draft.builtUpArea = null;

    draft.propertyAge = null;
    draft.facing = null;

    // -- Rent Details ------------------------------------
    draft.rentType = null;

    draft.expectedRent = null;
    draft.deposit = null;

    draft.maintenanceAmount = null;
    draft.maintenance = null;

    draft.rentNegotiable = false;

    draft.availableFrom = null;

    draft.preferredTenant = [];

    // -- Features ----------------------------------------
    draft.furnishing = null;
    draft.parking = null;
    draft.description = null;

    draft.otherFeatures = null;

    // -- Additional Details ------------------------------
    draft.bathroom = null;
    draft.noOfBalcony = null;

    draft.waterSupply = null;

    draft.petAllowed = false;
    draft.gymAllowed = false;
    draft.nonVegAllowed = false;
    draft.gateSecurity = false;

    draft.shownBy = null;

    draft.propertyCondition = null;

    draft.secondaryNumber = null;

    draft.unitsPropertiesAvailable = false;

    draft.directions = null;

    draft.amenities = [];

    // -- Media -------------------------------------------
    draft.images = [];
    draft.video = null;

    draft.uploadedImages = [];
    draft.uploadedVideo = null;

    // -- Availability ------------------------------------
    draft.availabilityDay = null;

    draft.startTime = null;
    draft.endTime = null;

    draft.availableAllDay = false;

    notifyListeners();
  }
}
