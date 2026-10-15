import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<Map<String, dynamic>> getLocation() async {

    // ?? STEP 1: CHECK GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      // ?? THIS WILL OPEN LOCATION SETTINGS
      await Geolocator.openLocationSettings();
      throw "Please enable location";
    }

    // ?? STEP 2: PERMISSION
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw "Permission permanently denied";
    }

    // ?? STEP 3: GET POSITION
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // ?? STEP 4: GET CITY
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

Placemark place = placemarks.firstWhere(
  (p) =>
      (p.subLocality != null && p.subLocality!.trim().isNotEmpty) ||
      (p.locality != null && p.locality!.trim().isNotEmpty),
  orElse: () => placemarks.first,
);

String safe(String? v) =>
    (v == null || v.trim().isEmpty) ? "" : v.trim();

return {
  "latitude": position.latitude,
  "longitude": position.longitude,

  "city": safe(place.locality ?? place.subAdministrativeArea),

  "locality": safe(place.subLocality ?? place.locality),

  "area": safe(
    place.subLocality ??
    place.thoroughfare ??
    place.name ??
    place.locality,
  ),
};
  }
}
