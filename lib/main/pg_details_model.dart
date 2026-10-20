// lib/main/g_details_model.dart

// -----------------------------------------------------------------------------

// PGDetailsModel — typed model for PG cards and detail screen

// Correctly maps `viewscount` from the API response

// -----------------------------------------------------------------------------



import 'dart:convert';
import 'package:rentit/core/image_utils.dart';



// -- Sub-models ----------------------------------------------------------------



class RoomType {

  final String? sharing;

  final double? rent;

  final double? deposit;

  final String? type;

  final List<String> amenities;

  final int? availability;



  const RoomType({

    this.sharing,

    this.rent,

    this.deposit,

    this.type,

    this.amenities = const [],

    this.availability,

  });



  factory RoomType.fromJson(Map<String, dynamic> json) {

    List<String> parseAmenities(dynamic raw) {

      if (raw == null) return [];

      if (raw is List) return raw.map((e) => e.toString()).toList();

      if (raw is String) {

        try {

          final parsed = jsonDecode(raw);

          if (parsed is List) return parsed.map((e) => e.toString()).toList();

        } catch (_) {}

        return [raw];

      }

      return [];

    }



    double? parseDouble(dynamic v) {

      if (v == null) return null;

      if (v is num) return v.toDouble();

      return double.tryParse(v.toString());

    }



    int? parseInt(dynamic v) {

      if (v == null) return null;

      if (v is int) return v;

      return int.tryParse(v.toString());

    }



    return RoomType(

      sharing: json['sharing']?.toString() ?? json['type']?.toString(),

      type: json['type']?.toString(),

      rent: parseDouble(json['rent']),

      deposit: parseDouble(json['deposit']),

      amenities: parseAmenities(json['amenities']),

      availability: parseInt(json['availability'] ?? json['slots']),

    );

  }



  Map<String, dynamic> toJson() => {

        'sharing': sharing,

        'type': type,

        'rent': rent,

        'deposit': deposit,

        'amenities': amenities,

        'availability': availability,

      };

}



// -----------------------------------------------------------------------------

// Main Model

// -----------------------------------------------------------------------------



class PGDetailsModel {

  final int id;

  final int userId;

  final String? propertyName;

  final String? propertyType;

  final String? propertyType2;

  final String? city;

  final String? locality;

  final String? street;

  final String? landmark;

  final String? pincode;

  final double? latitude;

  final double? longitude;

  final List<String> images;

  final String? video;

  final String? propertyDescription;

  final String? description;

  final List<RoomType> roomType;

  final Map<String, dynamic> pgAmenities;

  final Map<String, dynamic> restrictions;

  final Map<String, dynamic> foodType;

  final bool foodIncluded;

  final String? parking;

  final String? gender;

  final List<String> preferredTenant;

  final List<String> preferredGuests;

  final String? contactName;

  final String? mobileNo;

  final String? whatsapp;

  final bool? whatsappupdates;

  final String? availableFrom;

  final int? noticePeriod;

  final String? gateClosingTime;

  final String? facing;

  final String? occupancy;

  final double? builtUpArea;

  final String? propertyAge;

  final int? floor;

  final int? totalFloor;

  final bool isDraft;

  final bool isDeleted;

  final int currentStep;

  final DateTime? createdAt;

  final DateTime? updatedAt;



  // -- View count — mapped from `viewscount` field in DB ----------------------

  final int viewCount;



  const PGDetailsModel({

    required this.id,

    required this.userId,

    this.propertyName,

    this.propertyType,

    this.propertyType2,

    this.city,

    this.locality,

    this.street,

    this.landmark,

    this.pincode,

    this.latitude,

    this.longitude,

    this.images = const [],

    this.video,

    this.propertyDescription,

    this.description,

    this.roomType = const [],

    this.pgAmenities = const {},

    this.restrictions = const {},

    this.foodType = const {},

    this.foodIncluded = false,

    this.parking,

    this.gender,

    this.preferredTenant = const [],

    this.preferredGuests = const [],

    this.contactName,

    this.mobileNo,

    this.whatsapp,

    this.whatsappupdates,

    this.availableFrom,

    this.noticePeriod,

    this.gateClosingTime,

    this.facing,

    this.occupancy,

    this.builtUpArea,

    this.propertyAge,

    this.floor,

    this.totalFloor,

    this.isDraft = true,

    this.isDeleted = false,

    this.currentStep = 1,

    this.createdAt,

    this.updatedAt,

    this.viewCount = 0,

  });



  // -- Factory ---------------------------------------------------------------



  factory PGDetailsModel.fromJson(Map<String, dynamic> json) {

    // -- Helpers --------------------------------------------------------------

    List<String> parseStrList(dynamic raw) {

      if (raw == null) return [];

      if (raw is List) return raw.map((e) => e.toString()).toList();

      if (raw is String) {

        try {

          final p = jsonDecode(raw);

          if (p is List) return p.map((e) => e.toString()).toList();

        } catch (_) {}

        return raw.isNotEmpty ? [raw] : [];

      }

      return [];

    }



    Map<String, dynamic> parseMap(dynamic raw) {

      if (raw == null) return {};

      if (raw is Map<String, dynamic>) return raw;

      if (raw is String) {

        try {

          final p = jsonDecode(raw);

          if (p is Map<String, dynamic>) return p;

        } catch (_) {}

      }

      return {};

    }



    List<RoomType> parseRooms(dynamic raw) {

      if (raw == null) return [];

      List<dynamic> list = [];

      if (raw is List) {

        list = raw;

      } else if (raw is String) {

        try {

          final p = jsonDecode(raw);

          if (p is List) list = p;

        } catch (_) {}

      }

      return list

          .whereType<Map<String, dynamic>>()

          .map((m) => RoomType.fromJson(m))

          .toList();

    }



    double? parseDouble(dynamic v) {

      if (v == null) return null;

      if (v is num) return v.toDouble();

      return double.tryParse(v.toString());

    }



    int parseInt(dynamic v, [int fallback = 0]) {

      if (v == null) return fallback;

      if (v is int) return v;

      return int.tryParse(v.toString()) ?? fallback;

    }



    int? parseIntNullable(dynamic v) {

      if (v == null) return null;

      if (v is int) return v;

      return int.tryParse(v.toString());

    }



    // -- VIEW COUNT ------------------------------------------------------------

    // The DB column is `viewscount` (lowercase).

    // `_count.propertyViews` is the relation-count fallback.

    int resolveViewCount() {

      // 1. Direct field from DB (most reliable)

      final direct = json['viewscount'];

      if (direct != null) {

        final v = int.tryParse(direct.toString());

        if (v != null) return v;

      }



      // 2. Aggregated count from Prisma _count include

      final count = json['_count'];

      if (count is Map) {

        final v = count['propertyViews'];

        if (v != null) return int.tryParse(v.toString()) ?? 0;

      }



      return 0;

    }



    return PGDetailsModel(

      id: parseInt(json['id']),

      userId: parseInt(json['userId']),

      propertyName: json['propertyName']?.toString(),

      propertyType: json['propertyType']?.toString(),

      propertyType2: json['propertyType2']?.toString(),

      city: json['city']?.toString(),

      locality: json['locality']?.toString(),

      street: json['street']?.toString(),

      landmark: json['landmark']?.toString(),

      pincode: json['pincode']?.toString(),

      latitude: parseDouble(json['latitude']),

      longitude: parseDouble(json['longitude']),

      images: extractPropertyImages(json['images']),

      video: json['video']?.toString(),

      propertyDescription: json['propertyDescription']?.toString(),

      description: json['description']?.toString(),

      roomType: parseRooms(json['roomType']),

      pgAmenities: parseMap(json['pgAmenities']),

      restrictions: parseMap(json['restrictions']),

      foodType: parseMap(json['foodType']),

      foodIncluded: json['foodIncluded'] == true,

      parking: json['parking']?.toString(),

      gender: json['gender']?.toString(),

      preferredTenant: parseStrList(json['preferredTenant']),

      preferredGuests: parseStrList(json['preferredGuests']),

      contactName: json['contactName']?.toString(),

      mobileNo: json['mobileNo']?.toString(),

      whatsapp: json['whatsapp']?.toString(),

      whatsappupdates: json['whatsappupdates'] as bool?,

      availableFrom: json['availableFrom']?.toString(),

      noticePeriod: parseIntNullable(json['noticePeriod']),

      gateClosingTime: json['gateClosingTime']?.toString(),

      facing: json['facing']?.toString(),

      occupancy: json['occupancy']?.toString(),

      builtUpArea: parseDouble(json['builtUpArea']),

      propertyAge: json['propertyAge']?.toString(),

      floor: parseIntNullable(json['floor']),

      totalFloor: parseIntNullable(json['totalFloor']),

      isDraft: json['isDraft'] != false,

      isDeleted: json['isDeleted'] == true,

      currentStep: parseInt(json['currentStep'], 1),

      createdAt: json['createdAt'] != null

          ? DateTime.tryParse(json['createdAt'].toString())

          : null,

      updatedAt: json['updatedAt'] != null

          ? DateTime.tryParse(json['updatedAt'].toString())

          : null,

      viewCount: resolveViewCount(),

    );

  }



  // -- toJson — preserves viewscount for filter round-trip -------------------



  Map<String, dynamic> toJson() => {

        'id': id,

        'userId': userId,

        'propertyName': propertyName,

        'propertyType': propertyType,

        'propertyType2': propertyType2,

        'city': city,

        'locality': locality,

        'street': street,

        'landmark': landmark,

        'pincode': pincode,

        'latitude': latitude,

        'longitude': longitude,

        'images': images,

        'video': video,

        'propertyDescription': propertyDescription,

        'description': description,

        'roomType': roomType.map((r) => r.toJson()).toList(),

        'pgAmenities': pgAmenities,

        'restrictions': restrictions,

        'foodType': foodType,

        'foodIncluded': foodIncluded,

        'parking': parking,

        'gender': gender,

        'preferredTenant': preferredTenant,

        'preferredGuests': preferredGuests,

        'contactName': contactName,

        'mobileNo': mobileNo,

        'whatsapp': whatsapp,

        'whatsappupdates': whatsappupdates,

        'availableFrom': availableFrom,

        'noticePeriod': noticePeriod,

        'gateClosingTime': gateClosingTime,

        'facing': facing,

        'occupancy': occupancy,

        'builtUpArea': builtUpArea,

        'propertyAge': propertyAge,

        'floor': floor,

        'totalFloor': totalFloor,

        'isDraft': isDraft,

        'isDeleted': isDeleted,

        'currentStep': currentStep,

        'createdAt': createdAt?.toIso8601String(),

        'updatedAt': updatedAt?.toIso8601String(),

        // -- keep both forms so filter functions and display both work ------

        'viewscount': viewCount,

        '_count': {'propertyViews': viewCount},

      };



  // -- Convenience getters ---------------------------------------------------



  bool get isPG {

    final t = (propertyType ?? '').toLowerCase();

    final t2 = (propertyType2 ?? '').toLowerCase();

    return t.contains('pg') ||

        t2.contains('pg') ||

        t.contains('hostel') ||

        t2.contains('hostel') ||

        // If no type set yet still show it (newly created)

        (propertyType == null && propertyType2 == null);

  }



  String get displayName =>

      propertyName?.trim().isNotEmpty == true ? propertyName! : 'PG Accommodation';



  String get displayAddress {

    final parts = [locality, city]

        .where((e) => e != null && e.trim().isNotEmpty)

        .map((e) => e!.trim())

        .toList();

    return parts.isNotEmpty ? parts.join(', ') : (street ?? '');

  }



  // copyWith — used when view count is refreshed from detail screen

  PGDetailsModel copyWith({int? viewCount}) => PGDetailsModel(

        id: id,

        userId: userId,

        propertyName: propertyName,

        propertyType: propertyType,

        propertyType2: propertyType2,

        city: city,

        locality: locality,

        street: street,

        landmark: landmark,

        pincode: pincode,

        latitude: latitude,

        longitude: longitude,

        images: images,

        video: video,

        propertyDescription: propertyDescription,

        description: description,

        roomType: roomType,

        pgAmenities: pgAmenities,

        restrictions: restrictions,

        foodType: foodType,

        foodIncluded: foodIncluded,

        parking: parking,

        gender: gender,

        preferredTenant: preferredTenant,

        preferredGuests: preferredGuests,

        contactName: contactName,

        mobileNo: mobileNo,

        whatsapp: whatsapp,

        whatsappupdates: whatsappupdates,

        availableFrom: availableFrom,

        noticePeriod: noticePeriod,

        gateClosingTime: gateClosingTime,

        facing: facing,

        occupancy: occupancy,

        builtUpArea: builtUpArea,

        propertyAge: propertyAge,

        floor: floor,

        totalFloor: totalFloor,

        isDraft: isDraft,

        isDeleted: isDeleted,

        currentStep: currentStep,

        createdAt: createdAt,

        updatedAt: updatedAt,

        viewCount: viewCount ?? this.viewCount,

      );

}

