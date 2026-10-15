import 'package:rentit/core/image_utils.dart';

class PropertyModel {
  final int id;
  final String propertyName;
  final String city;
  final double rent;
  final String image;
  final String bhk;
  final String propertyType;

  PropertyModel({
    required this.id,
    required this.propertyName,
    required this.city,
    required this.rent,
    required this.image,
    required this.bhk,
    required this.propertyType,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    const fallbackImage =
        "https://images.unsplash.com/photo-1568605114967-8130f3a36994";

    final images = extractPropertyImages(json);
    final imageUrl = images.isNotEmpty ? images.first : fallbackImage;

    return PropertyModel(
      id: json["id"] ?? 0,
      propertyName: json["propertyName"] ?? json["title"] ?? "Property",
      city: json["city"] ?? "",
      rent: (json["rent"] ?? json["expectedRent"] ?? json["price"] ?? 0).toDouble(),
      bhk: json["bhkType"] ?? "",
      propertyType: json["propertyType"] ?? json["type"] ?? "",
      image: imageUrl,
    );
  }
}
