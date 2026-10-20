// Commercial_filter_model.dart

// Shared filter state passed between screens.

// Every field maps 1-to-1 to a real column in the Commercial Prisma model.



class CommercialFilterModel {

  // -- Location --------------------------------------------------------------

  // DB: city (String), locality (String?), street/landmark searched as text

  String city;

  String locality; // resolved locality from Google Places

  String search;   // raw free-text fallback



  // -- Search type -----------------------------------------------------------

  bool searchAlongMetro;



  // -- Rent ------------------------------------------------------------------

  // DB: expectedRent (Int?)

  double rentMin;

  double rentMax;



  // -- Commercial / Property type --------------------------------------------

  // DB: commercialPropertyType (String?)

  // Values: 'Office Space' | 'Co-Working' | 'Shop' | 'Showroom' |

  //         'Godown/Warehouse' | 'Industrial Shed' | 'Industrial Building' |

  //         'Other business'

  String commercialPropertyType;



  // -- Building type ---------------------------------------------------------

  // DB: buildingType (String?)

  // Values: 'Independent House' | 'Business Park' | 'Standalone building' |

  //         'Mall' | 'Independent shop'

  String buildingType;



  // -- Property age ----------------------------------------------------------

  // DB: propertyAge (String?)

  // Values: 'Less than a Year' | '1 to 5 year' | '5 to 10 year' | 'More than 10 year'

  String propertyAge;



  // -- Floor -----------------------------------------------------------------

  // DB: floor (Int?) — we store a range label that maps to numeric range

  // Values: 'Ground' | '1 to 3' | '4 to 6' | '7 to 9' | '10 & above'

  String floorRange;



  // -- Furnishing ------------------------------------------------------------

  // DB: furnishing (Json?) — stored as JSON array or string

  // Values: 'Full' | 'Semi' | 'None'

  String furnishing;



  // -- Availability ----------------------------------------------------------

  // DB: availableFrom (String? — date string)

  // Values: '' | 'Immediately' | 'Within 15 days' | 'Within 30 days'

  String availability;



  // -- Parking type ----------------------------------------------------------

  // DB: idealFor (Json?) — stored as JSON array

  // Values: '' | 'Public' | 'Reserved'

  String parking;



  // -- Sort ------------------------------------------------------------------

  String sortBy; // 'newest' | 'oldest' | 'price-low' | 'price-high'



  // -- Premium: Amenities ----------------------------------------------------

  // DB: otherFeatures (Json?) — stored as JSON array/object

  // Backend keys: 'lift' | 'powerBackup'

  List<String> amenities;



  // -- Premium: Floor range (nearby) ----------------------------------------

  // DB: floor (Int?) — stored as the same floorRange label set

  // We keep a separate premium list so premium screen can multi-select.

  List<String> nearby; // reused for floor multi-select in premium screen



  // -- Premium: Property age (restrictions) ---------------------------------

  // DB: propertyAge (String?) — multi-select in premium screen

  List<String> restrictions; // reused for propertyAge multi-select



  // -- Premium: Sort / show only ---------------------------------------------

  String premiumSort; // '' | 'Remove Seen Properties'



  // -------------------------------------------------------------------------



  CommercialFilterModel({

    this.city = '',

    this.locality = '',

    this.search = '',

    this.searchAlongMetro = false,

    this.rentMin = 0,

    this.rentMax = 1000000,

    this.commercialPropertyType = '',

    this.buildingType = '',

    this.propertyAge = '',

    this.floorRange = '',

    this.furnishing = '',

    this.availability = '',

    this.parking = '',

    this.sortBy = 'newest',

    this.amenities = const [],

    this.nearby = const [],

    this.restrictions = const [],

    this.premiumSort = '',

  });



  // -- Deep copy -------------------------------------------------------------



  CommercialFilterModel copyWith({

    String? city,

    String? locality,

    String? search,

    bool? searchAlongMetro,

    double? rentMin,

    double? rentMax,

    String? commercialPropertyType,

    String? buildingType,

    String? propertyAge,

    String? floorRange,

    String? furnishing,

    String? availability,

    String? parking,

    String? sortBy,

    List<String>? amenities,

    List<String>? nearby,

    List<String>? restrictions,

    String? premiumSort,

  }) =>

      CommercialFilterModel(

        city: city ?? this.city,

        locality: locality ?? this.locality,

        search: search ?? this.search,

        searchAlongMetro: searchAlongMetro ?? this.searchAlongMetro,

        rentMin: rentMin ?? this.rentMin,

        rentMax: rentMax ?? this.rentMax,

        commercialPropertyType:

            commercialPropertyType ?? this.commercialPropertyType,

        buildingType: buildingType ?? this.buildingType,

        propertyAge: propertyAge ?? this.propertyAge,

        floorRange: floorRange ?? this.floorRange,

        furnishing: furnishing ?? this.furnishing,

        availability: availability ?? this.availability,

        parking: parking ?? this.parking,

        sortBy: sortBy ?? this.sortBy,

        amenities: amenities ?? List<String>.from(this.amenities),

        nearby: nearby ?? List<String>.from(this.nearby),

        restrictions: restrictions ?? List<String>.from(this.restrictions),

        premiumSort: premiumSort ?? this.premiumSort,

      );



  // -- Reset (keeps city) ----------------------------------------------------



  CommercialFilterModel resetFilters() => CommercialFilterModel(

        city: city,

        locality: '',

        search: '',

        searchAlongMetro: false,

        rentMin: 0,

        rentMax: 1000000,

        commercialPropertyType: '',

        buildingType: '',

        propertyAge: '',

        floorRange: '',

        furnishing: '',

        availability: '',

        parking: '',

        sortBy: 'newest',

        amenities: [],

        nearby: [],

        restrictions: [],

        premiumSort: '',

      );



  // -- Active filter count (shown as badge on filter icon) -------------------



  int get activeCount {

    int n = 0;

    if (locality.isNotEmpty || search.isNotEmpty) n++;

    if (rentMax < 1000000 || rentMin > 0) n++;

    if (commercialPropertyType.isNotEmpty) n++;

    if (buildingType.isNotEmpty) n++;

    if (propertyAge.isNotEmpty) n++;

    if (floorRange.isNotEmpty) n++;

    if (furnishing.isNotEmpty) n++;

    if (availability.isNotEmpty) n++;

    if (parking.isNotEmpty) n++;

    return n;

  }



  bool get hasPremiumFilters =>

      amenities.isNotEmpty ||

      nearby.isNotEmpty ||

      restrictions.isNotEmpty ||

      premiumSort.isNotEmpty;



  // -- Serialize ? query params (for route arguments) ------------------------



  Map<String, String> toQueryParams() {

    final m = <String, String>{};

    if (city.isNotEmpty) m['city'] = city;

    if (locality.isNotEmpty) m['locality'] = locality;

    if (search.isNotEmpty) m['search'] = search;

    if (commercialPropertyType.isNotEmpty)

      m['commercialPropertyType'] = commercialPropertyType;

    if (buildingType.isNotEmpty) m['buildingType'] = buildingType;

    if (propertyAge.isNotEmpty) m['propertyAge'] = propertyAge;

    if (floorRange.isNotEmpty) m['floorRange'] = floorRange;

    if (furnishing.isNotEmpty) m['furnishing'] = furnishing;

    if (availability.isNotEmpty) m['availability'] = availability;

    if (parking.isNotEmpty) m['parking'] = parking;

    m['rentMin'] = rentMin.toStringAsFixed(0);

    m['rentMax'] = rentMax.toStringAsFixed(0);

    m['sortBy'] = sortBy;

    if (amenities.isNotEmpty) m['amenities'] = amenities.join(',');

    if (nearby.isNotEmpty) m['nearby'] = nearby.join(',');

    if (restrictions.isNotEmpty) m['restrictions'] = restrictions.join(',');

    if (premiumSort.isNotEmpty) m['premiumSort'] = premiumSort;

    return m;

  }



  // -- Deserialize from query params -----------------------------------------



  factory CommercialFilterModel.fromQueryParams(Map<String, String> p) {

    List<String> splitParam(String key) =>

        p[key]?.isNotEmpty == true ? p[key]!.split(',') : [];



    return CommercialFilterModel(

      city: p['city'] ?? '',

      locality: p['locality'] ?? '',

      search: p['search'] ?? '',

      commercialPropertyType: p['commercialPropertyType'] ?? '',

      buildingType: p['buildingType'] ?? '',

      propertyAge: p['propertyAge'] ?? '',

      floorRange: p['floorRange'] ?? '',

      furnishing: p['furnishing'] ?? '',

      availability: p['availability'] ?? '',

      parking: p['parking'] ?? '',

      rentMin: double.tryParse(p['rentMin'] ?? '0') ?? 0,

      rentMax: double.tryParse(p['rentMax'] ?? '1000000') ?? 1000000,

      sortBy: p['sortBy'] ?? 'newest',

      amenities: splitParam('amenities'),

      nearby: splitParam('nearby'),

      restrictions: splitParam('restrictions'),

      premiumSort: p['premiumSort'] ?? '',

    );

  }

}

