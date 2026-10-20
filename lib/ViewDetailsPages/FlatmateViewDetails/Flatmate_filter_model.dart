// -----------------------------------------------------------------------------

// Flatmate_filter_model.dart

// Filter state for the Flatmate module — matches the Prisma Flatmate schema

// -----------------------------------------------------------------------------



class FlatmateFilterModel {

  // -- Location --------------------------------------------------------------

  final String city;

  final String locality;

  final String search;



  // -- Rent ------------------------------------------------------------------

  final double rentMin;

  final double rentMax;



  // -- Tenant Type -----------------------------------------------------------

  // DB: tenantType — '' | 'Male' | 'Female' | 'Anyone'

  final String tenantType;



  // -- BHK Type --------------------------------------------------------------

  // DB: bhkType — '1 BHK' | '2 BHK' | '3 BHK' | '4+ BHK' etc.

  final String bhkType;



  // -- Room Type -------------------------------------------------------------

  // DB: roomType — 'Single room' | 'Shared Room'

  final String roomType;



  // -- Furnishing ------------------------------------------------------------

  // DB: furnishing — '' | 'Full' | 'Semi' | 'None'

  final String furnishing;



  // -- Property Type ---------------------------------------------------------

  // DB: propertyType — 'Gated Societies' | 'Apartment' | 'Independent House/Villa' | 'Gated Community Villa'

  final String propertyType;



  // -- Apartment Type --------------------------------------------------------

  // DB: apartmentType — 'Studio' | '1 BHK' etc. (separate from bhkType)

  final String apartmentType;



  // -- Parking ---------------------------------------------------------------

  // DB: parking — '' | '2 Wheeler' | '4 Wheeler' | 'Both' | 'None'

  final String parking;



  // -- Floor -----------------------------------------------------------------

  // DB: floor — 'Ground' | '1 to 3' | '4 to 6' | '7 to 9' | '10 & above'

  final String floor;



  // -- Bathroom --------------------------------------------------------------

  // UI: '1 or more' | '2 or more' | '3 or more'

  final String bathroom;



  // -- Availability ----------------------------------------------------------

  // DB: availableFrom — filter: 'Immediately' | 'Within 15 days' | 'Within 30 days'

  final String availability;



  // -- Boolean amenities -----------------------------------------------------

  // DB: acRoom, attachedBathroom, balcony, gym, liftSelected,

  //     gatedSecurity, powerBackupSelected, swimmingPoolSelected,

  //     clubHouseSelected, parkSelected, nonVegAllowed,

  //     smokingAllowed, drinkingAllowed

  final bool? acRoom;

  final bool? attachedBathroom;

  final bool? balcony;

  final bool? gym;

  final bool? liftSelected;

  final bool? gatedSecurity;

  final bool? powerBackupSelected;

  final bool? swimmingPoolSelected;

  final bool? clubHouseSelected;

  final bool? nonVegAllowed;

  final bool? smokingAllowed;

  final bool? drinkingAllowed;



  // -- Show Only toggles (multi-select UI) ----------------------------------

  // Each maps to a specific boolean DB field (see above)

  final List<String> showOnly; // e.g. ['Non Veg Allowed', 'With Photos', 'Gym']



  // -- Remove seen -----------------------------------------------------------

  final bool removeSeenProperties;



  // -- Sort ------------------------------------------------------------------

  final String sortBy; // 'newest' | 'oldest' | 'price-low' | 'price-high'



  const FlatmateFilterModel({

    this.city = '',

    this.locality = '',

    this.search = '',

    this.rentMin = 0,

    this.rentMax = 1000000,

    this.tenantType = '',

    this.bhkType = '',

    this.roomType = '',

    this.furnishing = '',

    this.propertyType = '',

    this.apartmentType = '',

    this.parking = '',

    this.floor = '',

    this.bathroom = '',

    this.availability = '',

    this.acRoom,

    this.attachedBathroom,

    this.balcony,

    this.gym,

    this.liftSelected,

    this.gatedSecurity,

    this.powerBackupSelected,

    this.swimmingPoolSelected,

    this.clubHouseSelected,

    this.nonVegAllowed,

    this.smokingAllowed,

    this.drinkingAllowed,

    this.showOnly = const [],

    this.removeSeenProperties = false,

    this.sortBy = 'newest',

  });



  // -- Copy with -------------------------------------------------------------

  FlatmateFilterModel copyWith({

    String? city,

    String? locality,

    String? search,

    double? rentMin,

    double? rentMax,

    String? tenantType,

    String? bhkType,

    String? roomType,

    String? furnishing,

    String? propertyType,

    String? apartmentType,

    String? parking,

    String? floor,

    String? bathroom,

    String? availability,

    bool? acRoom,

    bool? attachedBathroom,

    bool? balcony,

    bool? gym,

    bool? liftSelected,

    bool? gatedSecurity,

    bool? powerBackupSelected,

    bool? swimmingPoolSelected,

    bool? clubHouseSelected,

    bool? nonVegAllowed,

    bool? smokingAllowed,

    bool? drinkingAllowed,

    List<String>? showOnly,

    bool? removeSeenProperties,

    String? sortBy,

  }) =>

      FlatmateFilterModel(

        city: city ?? this.city,

        locality: locality ?? this.locality,

        search: search ?? this.search,

        rentMin: rentMin ?? this.rentMin,

        rentMax: rentMax ?? this.rentMax,

        tenantType: tenantType ?? this.tenantType,

        bhkType: bhkType ?? this.bhkType,

        roomType: roomType ?? this.roomType,

        furnishing: furnishing ?? this.furnishing,

        propertyType: propertyType ?? this.propertyType,

        apartmentType: apartmentType ?? this.apartmentType,

        parking: parking ?? this.parking,

        floor: floor ?? this.floor,

        bathroom: bathroom ?? this.bathroom,

        availability: availability ?? this.availability,

        acRoom: acRoom ?? this.acRoom,

        attachedBathroom: attachedBathroom ?? this.attachedBathroom,

        balcony: balcony ?? this.balcony,

        gym: gym ?? this.gym,

        liftSelected: liftSelected ?? this.liftSelected,

        gatedSecurity: gatedSecurity ?? this.gatedSecurity,

        powerBackupSelected: powerBackupSelected ?? this.powerBackupSelected,

        swimmingPoolSelected: swimmingPoolSelected ?? this.swimmingPoolSelected,

        clubHouseSelected: clubHouseSelected ?? this.clubHouseSelected,

        nonVegAllowed: nonVegAllowed ?? this.nonVegAllowed,

        smokingAllowed: smokingAllowed ?? this.smokingAllowed,

        drinkingAllowed: drinkingAllowed ?? this.drinkingAllowed,

        showOnly: showOnly ?? List.from(this.showOnly),

        removeSeenProperties: removeSeenProperties ?? this.removeSeenProperties,

        sortBy: sortBy ?? this.sortBy,

      );



  // -- Reset (keeps city) ----------------------------------------------------

  FlatmateFilterModel resetFilters() => FlatmateFilterModel(city: city);



  // -- Active filter count ---------------------------------------------------

  int get activeCount {

    int n = 0;

    if (locality.isNotEmpty || search.isNotEmpty) n++;

    if (rentMin > 0 || rentMax < 1000000) n++;

    if (tenantType.isNotEmpty) n++;

    if (bhkType.isNotEmpty) n++;

    if (roomType.isNotEmpty) n++;

    if (furnishing.isNotEmpty) n++;

    if (propertyType.isNotEmpty) n++;

    if (parking.isNotEmpty) n++;

    if (floor.isNotEmpty) n++;

    if (bathroom.isNotEmpty) n++;

    if (availability.isNotEmpty) n++;

    if (showOnly.isNotEmpty) n++;

    if (removeSeenProperties) n++;

    return n;

  }



  // -- Query params ----------------------------------------------------------

  Map<String, String> toQueryParams() {

    final m = <String, String>{};

    if (city.isNotEmpty) m['city'] = city;

    if (locality.isNotEmpty) m['locality'] = locality;

    if (search.isNotEmpty) m['search'] = search;

    if (tenantType.isNotEmpty) m['tenantType'] = tenantType;

    if (bhkType.isNotEmpty) m['bhkType'] = bhkType;

    if (roomType.isNotEmpty) m['roomType'] = roomType;

    if (furnishing.isNotEmpty) m['furnishing'] = furnishing;

    if (apartmentType.isNotEmpty) m['apartmentType'] = propertyType;

    if (apartmentType.isNotEmpty) m['apartmentType'] = apartmentType;

    if (parking.isNotEmpty) m['parking'] = parking;

    if (floor.isNotEmpty) m['floor'] = floor;

    if (bathroom.isNotEmpty) m['bathroom'] = bathroom;

    if (availability.isNotEmpty) m['availability'] = availability;

    if (showOnly.isNotEmpty) m['showOnly'] = showOnly.join(',');

    if (removeSeenProperties) m['removeSeenProperties'] = 'true';

    m['rentMin'] = rentMin.toStringAsFixed(0);

    m['rentMax'] = rentMax.toStringAsFixed(0);

    m['sortBy'] = sortBy;

    return m;

  }



  factory FlatmateFilterModel.fromQueryParams(Map<String, String> p) {

    List<String> split(String key) =>

        p[key]?.isNotEmpty == true ? p[key]!.split(',') : [];



    return FlatmateFilterModel(

      city: p['city'] ?? '',

      locality: p['locality'] ?? '',

      search: p['search'] ?? '',

      rentMin: double.tryParse(p['rentMin'] ?? '0') ?? 0,

      rentMax: double.tryParse(p['rentMax'] ?? '1000000') ?? 1000000,

      tenantType: p['tenantType'] ?? '',

      bhkType: p['bhkType'] ?? '',

      roomType: p['roomType'] ?? '',

      furnishing: p['furnishing'] ?? '',

      propertyType: p['propertyType'] ?? '',

      apartmentType: p['apartmentType'] ?? '',

      parking: p['parking'] ?? '',

      floor: p['floor'] ?? '',

      bathroom: p['bathroom'] ?? '',

      availability: p['availability'] ?? '',

      showOnly: split('showOnly'),

      removeSeenProperties: p['removeSeenProperties'] == 'true',

      sortBy: p['sortBy'] ?? 'newest',

    );

  }

}

