import 'dart:convert';
import 'package:rentit/core/image_utils.dart';

// --- Room type sub-model -------------------------------------------------------

class RoomType {
  final String? sharing;
  final double? rent;
  final double? deposit;
  final int? slots;
  final List<String> amenities;

  const RoomType({
    this.sharing,
    this.rent,
    this.deposit,
    this.slots,
    this.amenities = const [],
  });

  factory RoomType.fromJson(Map<String, dynamic> json) {
    List<String> parseAmenities(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String) {
        try {
          final parsed = jsonDecode(v);
          if (parsed is List) return parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return RoomType(
      sharing: json['sharing']?.toString(),
      rent: _parseDouble(json['rent']),
      deposit: _parseDouble(json['deposit']),
      slots: _parseInt(json['availability'] ?? json['slots']),
      amenities: parseAmenities(json['amenities']),
    );
  }

  Map<String, dynamic> toJson() => {
        'sharing': sharing,
        'rent': rent,
        'deposit': deposit,
        'availability': slots,
        'amenities': amenities,
      };

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

// --- Count sub-model (for Prisma _count includes) -----------------------------

class PropertyCount {
  final int propertyViews;
  final int messages;

  const PropertyCount({
    this.propertyViews = 0,
    this.messages = 0,
  });

  factory PropertyCount.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PropertyCount();
    return PropertyCount(
      propertyViews: _parseInt(json['propertyViews']) ?? 0,
      messages: _parseInt(json['messages']) ?? 0,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

// --- Main model ---------------------------------------------------------------

class PGDetailsModel {
  final int id;
  final int userId;

  // Identity
  final String? propertyType;
  final String? propertyType2;
  final String? propertyName;

  // Location
  final String? city;
  final String? locality;
  final String? street;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  // Pricing & rooms
  final List<RoomType> roomType;
  final double? rent;
  final double? deposit;

  // Guest preferences
  final List<String> preferredTenant;
  final List<String> preferredGuests;

  // Amenities
  final Map<String, dynamic> pgAmenities;
  final bool foodIncluded;
  final String? foodType;
  final String? parking;
  final List<String> restrictions;
  final String? propertyDescription;

  // Availability
  final DateTime? availableFrom;
  final int? noticePeriod;
  final DateTime? gateClosingTime;

  // Contact
  final String? contactName;
  final String? mobileNo;
  final String? whatsapp;
  final bool whatsappupdates;

  // Media
  final List<String> images;
  final String? video;

  // Status
  final bool isDraft;
  final bool isDeleted;
  final int currentStep;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // -- View count -------------------------------------------------------------
  // viewscount  ? flat column returned by getAllProperties (property.service.ts)
  // count       ? Prisma _count include (used by getMyProperties / detail views)
  final int viewscount;
  final PropertyCount count;

  const PGDetailsModel({
    required this.id,
    required this.userId,
    this.propertyType,
    this.propertyType2,
    this.propertyName,
    this.city,
    this.locality,
    this.street,
    this.landmark,
    this.latitude,
    this.longitude,
    this.roomType = const [],
    this.rent,
    this.deposit,
    this.preferredTenant = const [],
    this.preferredGuests = const [],
    this.pgAmenities = const {},
    this.foodIncluded = false,
    this.foodType,
    this.parking,
    this.restrictions = const [],
    this.propertyDescription,
    this.availableFrom,
    this.noticePeriod,
    this.gateClosingTime,
    this.contactName,
    this.mobileNo,
    this.whatsapp,
    this.whatsappupdates = false,
    this.images = const [],
    this.video,
    this.isDraft = true,
    this.isDeleted = false,
    this.currentStep = 1,
    this.createdAt,
    this.updatedAt,
    this.viewscount = 0,          // ? flat column
    this.count = const PropertyCount(), // ? _count relation
  });

  // -- fromJson ----------------------------------------------------------------

  factory PGDetailsModel.fromJson(Map<String, dynamic> json) {
    return PGDetailsModel(
      id: _parseInt(json['id']) ?? 0,
      userId: _parseInt(json['userId']) ?? 0,

      propertyType: json['propertyType']?.toString(),
      propertyType2: json['propertyType2']?.toString(),
      propertyName: json['propertyName']?.toString(),

      city: json['city']?.toString(),
      locality: json['locality']?.toString(),
      street: json['street']?.toString(),
      landmark: json['landmark']?.toString(),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),

      roomType: _parseRoomTypes(json['roomType']),
      rent: _parseDouble(json['rent']),
      deposit: _parseDouble(json['deposit']),

      preferredTenant: _parseStringList(json['preferredTenant']),
      preferredGuests: _parseStringList(json['preferredGuests']),

      pgAmenities: _parseMap(json['pgAmenities']),
      foodIncluded: json['foodIncluded'] == true,
      foodType: json['foodType']?.toString(),
      parking: json['parking']?.toString(),
      restrictions: _parseRestrictions(json['restrictions']),
      propertyDescription: json['propertyDescription']?.toString(),

      availableFrom: _parseDate(json['availableFrom']),
      noticePeriod: _parseInt(json['noticePeriod']),
      gateClosingTime: _parseDate(json['gateClosingTime']),

      contactName: json['contactName']?.toString(),
      mobileNo: json['mobileNo']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      whatsappupdates: json['whatsappupdates'] == true,

      images: extractPropertyImages(json['images']),
      video: json['video']?.toString(),

      isDraft: json['isDraft'] != false,
      isDeleted: json['isDeleted'] == true,
      currentStep: _parseInt(json['currentStep']) ?? 1,

      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),

      // ? Reads the flat `viewscount` column (returned by getAllProperties)
      viewscount: _parseInt(json['viewscount']) ?? 0,

      // ? Reads the nested _count relation (returned by getMyProperties etc.)
      count: PropertyCount.fromJson(json['_count'] as Map<String, dynamic>?),
    );
  }

  // -- toJson ------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'propertyType': propertyType,
        'propertyType2': propertyType2,
        'propertyName': propertyName,
        'city': city,
        'locality': locality,
        'street': street,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'roomType': roomType.map((r) => r.toJson()).toList(),
        'rent': rent,
        'deposit': deposit,
        'preferredTenant': preferredTenant,
        'preferredGuests': preferredGuests,
        'pgAmenities': pgAmenities,
        'foodIncluded': foodIncluded,
        'foodType': foodType,
        'parking': parking,
        'restrictions': restrictions,
        'propertyDescription': propertyDescription,
        'availableFrom': availableFrom?.toIso8601String(),
        'noticePeriod': noticePeriod,
        'gateClosingTime': gateClosingTime?.toIso8601String(),
        'contactName': contactName,
        'mobileNo': mobileNo,
        'whatsapp': whatsapp,
        'whatsappupdates': whatsappupdates,
        'images': images,
        'video': video,
        'isDraft': isDraft,
        'isDeleted': isDeleted,
        'currentStep': currentStep,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        // Preserve both so round-trip through toJson ? fromJson still works
        'viewscount': viewscount,
        '_count': {
          'propertyViews': count.propertyViews,
          'messages': count.messages,
        },
      };

  // -- Convenience getters ----------------------------------------------------

  /// Returns the correct view count regardless of which API endpoint was called.
  /// - getAllProperties  ? returns flat `viewscount` column  ?
  /// - getMyProperties  ? returns `_count.messages` but NOT viewscount, use count
  /// - getProperty      ? returns flat `viewscount` column  ?
  int get viewCount {
    if (viewscount > 0) return viewscount;
    return count.propertyViews;
  }

  /// Lowest rent across all room types, falling back to the flat rent field.
  double? get lowestRent {
    if (roomType.isNotEmpty) {
      return roomType
          .where((r) => r.rent != null && r.rent! > 0)
          .map((r) => r.rent!)
          .fold<double?>(
              null, (min, v) => (min == null || v < min) ? v : min);
    }
    return rent;
  }

  String get displayAddress {
    final parts = [locality, city]
        .where((e) => e != null && e.trim().isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : (street ?? '');
  }

  String get displayName =>
      (propertyName?.trim().isNotEmpty == true)
          ? propertyName!
          : 'PG Accommodation';

  bool get isPG {
    final t = (propertyType ?? '').toLowerCase();
    final t2 = (propertyType2 ?? '').toLowerCase();
    return t.contains('pg') || t2.contains('pg') || t.contains('hostel');
  }

  // -- copyWith ---------------------------------------------------------------

  PGDetailsModel copyWith({
    int? id,
    int? userId,
    String? propertyType,
    String? propertyType2,
    String? propertyName,
    String? city,
    String? locality,
    String? street,
    String? landmark,
    double? latitude,
    double? longitude,
    List<RoomType>? roomType,
    double? rent,
    double? deposit,
    List<String>? preferredTenant,
    List<String>? preferredGuests,
    Map<String, dynamic>? pgAmenities,
    bool? foodIncluded,
    String? foodType,
    String? parking,
    List<String>? restrictions,
    String? propertyDescription,
    DateTime? availableFrom,
    int? noticePeriod,
    DateTime? gateClosingTime,
    String? contactName,
    String? mobileNo,
    String? whatsapp,
    bool? whatsappupdates,
    List<String>? images,
    String? video,
    bool? isDraft,
    bool? isDeleted,
    int? currentStep,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewscount,
    PropertyCount? count,
  }) {
    return PGDetailsModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      propertyType: propertyType ?? this.propertyType,
      propertyType2: propertyType2 ?? this.propertyType2,
      propertyName: propertyName ?? this.propertyName,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      street: street ?? this.street,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      roomType: roomType ?? this.roomType,
      rent: rent ?? this.rent,
      deposit: deposit ?? this.deposit,
      preferredTenant: preferredTenant ?? this.preferredTenant,
      preferredGuests: preferredGuests ?? this.preferredGuests,
      pgAmenities: pgAmenities ?? this.pgAmenities,
      foodIncluded: foodIncluded ?? this.foodIncluded,
      foodType: foodType ?? this.foodType,
      parking: parking ?? this.parking,
      restrictions: restrictions ?? this.restrictions,
      propertyDescription: propertyDescription ?? this.propertyDescription,
      availableFrom: availableFrom ?? this.availableFrom,
      noticePeriod: noticePeriod ?? this.noticePeriod,
      gateClosingTime: gateClosingTime ?? this.gateClosingTime,
      contactName: contactName ?? this.contactName,
      mobileNo: mobileNo ?? this.mobileNo,
      whatsapp: whatsapp ?? this.whatsapp,
      whatsappupdates: whatsappupdates ?? this.whatsappupdates,
      images: images ?? this.images,
      video: video ?? this.video,
      isDraft: isDraft ?? this.isDraft,
      isDeleted: isDeleted ?? this.isDeleted,
      currentStep: currentStep ?? this.currentStep,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewscount: viewscount ?? this.viewscount,
      count: count ?? this.count,
    );
  }

  // -- Private helpers --------------------------------------------------------

  static List<RoomType> _parseRoomTypes(dynamic v) {
    if (v == null) return [];
    List<dynamic> list;
    if (v is List) {
      list = v;
    } else if (v is String) {
      try {
        final parsed = jsonDecode(v);
        list = parsed is List ? parsed : [];
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => RoomType.fromJson(e))
        .toList();
  }

  static List<String> _parseStringList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      try {
        final parsed = jsonDecode(v);
        if (parsed is List) {
          return parsed.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return [v];
      }
    }
    return [];
  }

  static List<String> _parseRestrictions(dynamic v) {
    if (v == null) return [];
    
    // If it's a JSON string, try to decode it
    dynamic parsed = v;
    if (v is String) {
      try {
        parsed = jsonDecode(v);
      } catch (_) {}
    }

    // If it's a Map (which PG API returns for restrictions: {"smoking": true, "drinking": false})
    if (parsed is Map) {
      return parsed.entries
          .where((e) => e.value == true || e.value == 'true')
          .map((e) => e.key.toString())
          .toList();
    }
    
    // Fallback if it's already a list (just in case)
    if (parsed is List) {
      return parsed.map((e) => e.toString()).toList();
    }

    return [];
  }

  static Map<String, dynamic> _parseMap(dynamic v) {
    if (v == null) return {};
    if (v is Map<String, dynamic>) return v;
    if (v is String) {
      try {
        final parsed = jsonDecode(v);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return {};
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}
