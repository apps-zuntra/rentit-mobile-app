// -----------------------------------------------------------------------------
// Apartment_filter_model.dart
// Shared immutable filter state for the Apartment module.
// Matches the Prisma Apartment schema exactly.
// -----------------------------------------------------------------------------

class ApartmentFilterModel {
  // -- Location ---------------------------------------------------------------
  final String city;
  final String locality; // resolved from Google Places or typed text
  final String search;   // raw fallback free-text search

  // -- Rent -------------------------------------------------------------------
  final double rentMin;
  final double rentMax;

  // -- BHK type  (maps to Apartment.bhkType) ---------------------------------
  final List<String> bhkTypes;

  // -- Preferred Tenant  (maps to Apartment.preferredTenant String[]) ---------
  final String preferredTenant;

  // -- Furnishing  (maps to Apartment.furnishing) ----------------------------
  final String furnishing;

  // -- Availability  (maps to Apartment.availableFrom) -----------------------
  final String availability;

  // -- Parking  (maps to Apartment.parking) ----------------------------------
  final String parking;
  final List<String> parkingTypes;

  // -- Sort -------------------------------------------------------------------
  final String sortBy;

  // -- Toggles ----------------------------------------------------------------
  final bool leaseOnly;
  final bool ownerHosting;

  // --------------------------------------------------------------------------
  //  PREMIUM FILTERS
  // --------------------------------------------------------------------------

  // Amenities  (maps to Apartment.amenities String[]) ------------------------
  final List<String> amenities;

  // Nearby facilities --------------------------------------------------------
  final List<String> nearby;

  // Restrictions  (boolean fields on Apartment) ------------------------------
  // Selecting a restriction means "must NOT have this allowed"
  final List<String> restrictions;

  // Premium sort -------------------------------------------------------------
  final String premiumSort;

  // Built-up area  (maps to Apartment.builtUpArea) ---------------------------
  final double areaMin;
  final double areaMax;

  // Property age  (maps to Apartment.propertyAge) ----------------------------
  final List<String> propertyAges;

  // Show-only options --------------------------------------------------------
  final List<String> showOnly;

  // Remove seen properties ---------------------------------------------------
  final bool removeSeen;

  // Bathroom count  (maps to Apartment.bathroom Int) -------------------------
  final String bathroom;

  // Floors  (maps to Apartment.floor) ---------------------------------------
  final List<String> floors;

  // -- Constructor ------------------------------------------------------------
  const ApartmentFilterModel({
    this.city            = '',
    this.locality        = '',
    this.search          = '',
    this.rentMin         = 0,
    this.rentMax         = 1000000,
    this.bhkTypes        = const [],
    this.preferredTenant = '',
    this.furnishing      = '',
    this.availability    = '',
    this.parking         = '',
    this.parkingTypes    = const [],
    this.sortBy          = 'newest',
    this.leaseOnly       = false,
    this.ownerHosting    = false,
    this.amenities       = const [],
    this.nearby          = const [],
    this.restrictions    = const [],
    this.premiumSort     = '',
    this.areaMin         = 0,
    this.areaMax         = 10000,
    this.propertyAges    = const [],
    this.showOnly        = const [],
    this.removeSeen      = false,
    this.bathroom        = '',
    this.floors          = const [],
  });

  // -- copyWith ---------------------------------------------------------------
  ApartmentFilterModel copyWith({
    String?       city,
    String?       locality,
    String?       search,
    double?       rentMin,
    double?       rentMax,
    List<String>? bhkTypes,
    String?       preferredTenant,
    String?       furnishing,
    String?       availability,
    String?       parking,
    List<String>? parkingTypes,
    String?       sortBy,
    bool?         leaseOnly,
    bool?         ownerHosting,
    List<String>? amenities,
    List<String>? nearby,
    List<String>? restrictions,
    String?       premiumSort,
    double?       areaMin,
    double?       areaMax,
    List<String>? propertyAges,
    List<String>? showOnly,
    bool?         removeSeen,
    String?       bathroom,
    List<String>? floors,
  }) =>
      ApartmentFilterModel(
        city:            city            ?? this.city,
        locality:        locality        ?? this.locality,
        search:          search          ?? this.search,
        rentMin:         rentMin         ?? this.rentMin,
        rentMax:         rentMax         ?? this.rentMax,
        bhkTypes:        bhkTypes        ?? List.from(this.bhkTypes),
        preferredTenant: preferredTenant ?? this.preferredTenant,
        furnishing:      furnishing      ?? this.furnishing,
        availability:    availability    ?? this.availability,
        parking:         parking         ?? this.parking,
        parkingTypes:    parkingTypes    ?? List.from(this.parkingTypes),
        sortBy:          sortBy          ?? this.sortBy,
        leaseOnly:       leaseOnly       ?? this.leaseOnly,
        ownerHosting:    ownerHosting    ?? this.ownerHosting,
        amenities:       amenities       ?? List.from(this.amenities),
        nearby:          nearby          ?? List.from(this.nearby),
        restrictions:    restrictions    ?? List.from(this.restrictions),
        premiumSort:     premiumSort     ?? this.premiumSort,
        areaMin:         areaMin         ?? this.areaMin,
        areaMax:         areaMax         ?? this.areaMax,
        propertyAges:    propertyAges    ?? List.from(this.propertyAges),
        showOnly:        showOnly        ?? List.from(this.showOnly),
        removeSeen:      removeSeen      ?? this.removeSeen,
        bathroom:        bathroom        ?? this.bathroom,
        floors:          floors          ?? List.from(this.floors),
      );

  // -- Reset standard filters only (keeps city + all premium) ----------------
  ApartmentFilterModel resetFilters() => ApartmentFilterModel(
        city:         city,
        amenities:    List.from(amenities),
        nearby:       List.from(nearby),
        restrictions: List.from(restrictions),
        premiumSort:  premiumSort,
        areaMin:      areaMin,
        areaMax:      areaMax,
        propertyAges: List.from(propertyAges),
        showOnly:     List.from(showOnly),
        removeSeen:   removeSeen,
        bathroom:     bathroom,
        floors:       List.from(floors),
      );

  // -- Reset premium filters only ---------------------------------------------
  ApartmentFilterModel resetPremiumFilters() => copyWith(
        amenities:    [],
        nearby:       [],
        restrictions: [],
        premiumSort:  '',
        areaMin:      0,
        areaMax:      10000,
        propertyAges: [],
        showOnly:     [],
        removeSeen:   false,
        bathroom:     '',
        floors:       [],
      );

  // -- Active standard filter count (badge on filter icon) -------------------
  int get activeCount {
    int n = 0;
    if (locality.isNotEmpty || search.isNotEmpty)      n++;
    if (rentMin > 0 || rentMax < 1000000)              n++;
    if (bhkTypes.isNotEmpty)                           n++;
    if (preferredTenant.isNotEmpty)                    n++;
    if (furnishing.isNotEmpty)                         n++;
    if (availability.isNotEmpty)                       n++;
    if (parking.isNotEmpty || parkingTypes.isNotEmpty) n++;
    if (leaseOnly)                                     n++;
    if (ownerHosting)                                  n++;
    return n;
  }

  // -- Whether any premium filter is active ----------------------------------
  bool get hasPremiumFilters =>
      amenities.isNotEmpty    ||
      nearby.isNotEmpty       ||
      restrictions.isNotEmpty ||
      premiumSort.isNotEmpty  ||
      areaMin > 0             ||
      areaMax < 10000         ||
      propertyAges.isNotEmpty ||
      showOnly.isNotEmpty     ||
      removeSeen              ||
      bathroom.isNotEmpty     ||
      floors.isNotEmpty;

  // -- Total premium filter count (for badge) ---------------------------------
  int get premiumCount {
    int n = 0;
    n += amenities.length;
    n += nearby.length;
    n += restrictions.length;
    if (premiumSort.isNotEmpty)          n++;
    if (areaMin > 0 || areaMax < 10000) n++;
    n += propertyAges.length;
    n += showOnly.length;
    if (removeSeen)                      n++;
    if (bathroom.isNotEmpty)             n++;
    n += floors.length;
    return n;
  }

  // -- Serialise ? query params -----------------------------------------------
  Map<String, String> toQueryParams() {
    final m = <String, String>{};
    if (city.isNotEmpty)            m['city']            = city;
    if (locality.isNotEmpty)        m['locality']        = locality;
    if (search.isNotEmpty)          m['search']          = search;
    if (preferredTenant.isNotEmpty) m['preferredTenant'] = preferredTenant;
    if (furnishing.isNotEmpty)      m['furnishing']      = furnishing;
    if (availability.isNotEmpty)    m['availability']    = availability;
    if (parking.isNotEmpty)         m['parking']         = parking;
    if (bhkTypes.isNotEmpty)        m['bhkTypes']        = bhkTypes.join(',');
    if (parkingTypes.isNotEmpty)    m['parkingTypes']    = parkingTypes.join(',');
    if (leaseOnly)                  m['leaseOnly']       = 'true';
    if (ownerHosting)               m['ownerHosting']    = 'true';
    m['rentMin'] = rentMin.toStringAsFixed(0);
    m['rentMax'] = rentMax.toStringAsFixed(0);
    m['sortBy']  = sortBy;
    if (amenities.isNotEmpty)    m['amenities']    = amenities.join(',');
    if (nearby.isNotEmpty)       m['nearby']       = nearby.join(',');
    if (restrictions.isNotEmpty) m['restrictions'] = restrictions.join(',');
    if (premiumSort.isNotEmpty)  m['premiumSort']  = premiumSort;
    m['areaMin'] = areaMin.toStringAsFixed(0);
    m['areaMax'] = areaMax.toStringAsFixed(0);
    if (propertyAges.isNotEmpty) m['propertyAges'] = propertyAges.join(',');
    if (showOnly.isNotEmpty)     m['showOnly']     = showOnly.join(',');
    if (removeSeen)              m['removeSeen']   = 'true';
    if (bathroom.isNotEmpty)     m['bathroom']     = bathroom;
    if (floors.isNotEmpty)       m['floors']       = floors.join(',');
    return m;
  }

  // -- Deserialise ? query params ---------------------------------------------
  factory ApartmentFilterModel.fromQueryParams(Map<String, String> p) {
    List<String> split(String key) =>
        (p[key]?.isNotEmpty == true) ? p[key]!.split(',') : [];

    return ApartmentFilterModel(
      city:            p['city']            ?? '',
      locality:        p['locality']        ?? '',
      search:          p['search']          ?? '',
      rentMin:         double.tryParse(p['rentMin'] ?? '0')       ?? 0,
      rentMax:         double.tryParse(p['rentMax'] ?? '1000000') ?? 1000000,
      bhkTypes:        split('bhkTypes'),
      preferredTenant: p['preferredTenant'] ?? '',
      furnishing:      p['furnishing']      ?? '',
      availability:    p['availability']    ?? '',
      parking:         p['parking']         ?? '',
      parkingTypes:    split('parkingTypes'),
      sortBy:          p['sortBy']          ?? 'newest',
      leaseOnly:       p['leaseOnly']       == 'true',
      ownerHosting:    p['ownerHosting']    == 'true',
      amenities:       split('amenities'),
      nearby:          split('nearby'),
      restrictions:    split('restrictions'),
      premiumSort:     p['premiumSort']     ?? '',
      areaMin:         double.tryParse(p['areaMin'] ?? '0')     ?? 0,
      areaMax:         double.tryParse(p['areaMax'] ?? '10000') ?? 10000,
      propertyAges:    split('propertyAges'),
      showOnly:        split('showOnly'),
      removeSeen:      p['removeSeen']      == 'true',
      bathroom:        p['bathroom']        ?? '',
      floors:          split('floors'),
    );
  }
}
