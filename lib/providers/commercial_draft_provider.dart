import 'package:flutter/material.dart';
import 'package:rentit/model/model/commercial_draft.dart';

class CommercialDraftProvider extends ChangeNotifier {
  final CommercialDraft draft = CommercialDraft();

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  void clear() {
    // ── Location ───────────────────────────────────────────
    draft.city = null;
    draft.locality = null;
    draft.street = null;
    draft.landmark = null;
    draft.latitude = null;
    draft.longitude = null;

    // ── Property Details ───────────────────────────────────
    draft.propertyType = null;
    draft.buildingType = null;
    draft.propertyAge = null;

    draft.floor = null;
    draft.totalFloor = null;
    draft.builtUpArea = null;

    draft.furnishing = {};
    draft.otherFeatures = {};

    // ── Rent Details ───────────────────────────────────────
    draft.rentType = null;
    draft.expectedRent = null;
    draft.deposit = null;
    draft.maintenanceAmount = null;

    draft.maintenance = null;

    draft.rentNegotiable = false;
    draft.depositNegotiable = false;
    draft.maintenanceExtra = false;

    draft.leaseDuration = null;
    draft.lockinPeriod = null;
    draft.availableFrom = null;

    // ── Commercial Details ────────────────────────────────
    draft.idealFor = [];
    draft.addOthertags = null;

    draft.commercialPropertyType = null;
    draft.commercialOtherFeatures = {};

    draft.slots = null;

    // ── Contact ────────────────────────────────────────────
    draft.contactName = null;
    draft.mobileNo = null;
    draft.whatsapp = true;

    // ── Media ──────────────────────────────────────────────
    draft.images = [];
    draft.video = null;

    // ── Description & Property Info ────────────────────────
    draft.description = null;
    draft.previousOccupancy = null;
    draft.propertyCleaning = null;
    draft.propertyPainting = null;
    draft.whoShowsProperty = null;

    // ── Availability ──────────────────────────────────────
    draft.availabilityDay = [];
    draft.startTime = null;
    draft.endTime = null;
    draft.availableAllDay = false;

    notifyListeners();
  }
}
