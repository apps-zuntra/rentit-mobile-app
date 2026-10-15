// SearchModel.dart
// Shared filter state passed between LocationScreen ? FilterScreen ? AllPropertiesScreen

class SearchModel {
  // -- Location --------------------------------------------------------------
  String city;
  String locality; // resolved locality from Google Places
  String search;   // raw text fallback when no locality picked

  // -- Search type -----------------------------------------------------------
  bool searchAlongMetro;

  // -- Rent ------------------------------------------------------------------
  double rentMin;
  double rentMax;

  // -- PG For ----------------------------------------------------------------
  // '' = no filter | 'Boys' | 'Girls' | 'Anyone'
  String pgFor;

  // -- Room type / sharing ---------------------------------------------------
  // Matches roomType[].sharing values exactly:
  //   'Single room' | 'Double sharing' | '3 Sharing' | '4+ Sharing'
  List<String> sharingTypes;

  // -- Preferred tenant ------------------------------------------------------
  // '' = no filter | 'Students' | 'Working Professionals' | 'Anyone'
  String preferredTenant;

  // -- Availability ----------------------------------------------------------
  // '' | 'Immediately' | 'Within 15 days' | 'Within 30 days'
  String availability;

  // -- Parking ---------------------------------------------------------------
  // '' | 'Yes' | 'No'
  String parking;

  // -- Food ------------------------------------------------------------------
  // null = no filter | true = food included | false = no food
  bool? foodIncluded;

  // -- Sort ------------------------------------------------------------------
  // 'price-low' | 'price-high' | 'newest' | 'oldest'
  String sortBy;

  // -- Premium Filters -------------------------------------------------------
  // Amenities: 'AC', 'Cupboard', 'TV', 'WiFi', 'Geyser', 'Attached Bathroom',
  //            'Bedding', 'Laundry', 'Room cleaning', 'Common TV', 'Lift',
  //            'Power Backup', 'Refrigerator', 'Mess'
  List<String> amenities;

  // Nearby: 'Bus stop', 'Metro', 'School', 'Hospital'
  List<String> nearby;

  // Restrictions: 'Smoking', 'Alcohol', 'Loud Music', 'Non-Veg', 'Girls/Boys Entry'
  List<String> restrictions;

  // Premium sort: '' | 'new' | 'recent'
  String premiumSort;

  SearchModel({
    this.city = '',
    this.locality = '',
    this.search = '',
    this.searchAlongMetro = false,
    this.rentMin = 0,
    this.rentMax = 1000000,
    this.pgFor = '',
    this.sharingTypes = const [],
    this.preferredTenant = '',
    this.availability = '',
    this.parking = '',
    this.foodIncluded,
    this.sortBy = 'newest',
    this.amenities = const [],
    this.nearby = const [],
    this.restrictions = const [],
    this.premiumSort = '',
  });

  // -- Deep copy -------------------------------------------------------------
  SearchModel copyWith({
    String? city,
    String? locality,
    String? search,
    bool? searchAlongMetro,
    double? rentMin,
    double? rentMax,
    String? pgFor,
    List<String>? sharingTypes,
    String? preferredTenant,
    String? availability,
    String? parking,
    bool? Function()? foodIncluded,
    String? sortBy,
    List<String>? amenities,
    List<String>? nearby,
    List<String>? restrictions,
    String? premiumSort,
  }) =>
      SearchModel(
        city: city ?? this.city,
        locality: locality ?? this.locality,
        search: search ?? this.search,
        searchAlongMetro: searchAlongMetro ?? this.searchAlongMetro,
        rentMin: rentMin ?? this.rentMin,
        rentMax: rentMax ?? this.rentMax,
        pgFor: pgFor ?? this.pgFor,
        sharingTypes: sharingTypes ?? List.from(this.sharingTypes),
        preferredTenant: preferredTenant ?? this.preferredTenant,
        availability: availability ?? this.availability,
        parking: parking ?? this.parking,
        foodIncluded:
            foodIncluded != null ? foodIncluded() : this.foodIncluded,
        sortBy: sortBy ?? this.sortBy,
        amenities: amenities ?? List.from(this.amenities),
        nearby: nearby ?? List.from(this.nearby),
        restrictions: restrictions ?? List.from(this.restrictions),
        premiumSort: premiumSort ?? this.premiumSort,
      );

  // -- Reset (keeps city) ----------------------------------------------------
  SearchModel resetFilters() => SearchModel(
        city: city,
        locality: '',
        search: '',
        searchAlongMetro: false,
        rentMin: 0,
        rentMax: 1000000,
        pgFor: '',
        sharingTypes: [],
        preferredTenant: '',
        availability: '',
        parking: '',
        foodIncluded: null,
        sortBy: 'newest',
        amenities: [],
        nearby: [],
        restrictions: [],
        premiumSort: '',
      );

  // -- Active filter count ---------------------------------------------------
  int get activeCount {
    int n = 0;
    if (locality.isNotEmpty || search.isNotEmpty) n++;
    if (rentMax < 1000000 || rentMin > 0) n++;
    if (pgFor.isNotEmpty && pgFor != 'Anyone') n++;
    if (sharingTypes.isNotEmpty) n++;
    if (preferredTenant.isNotEmpty && preferredTenant != 'Anyone') n++;
    if (availability.isNotEmpty) n++;
    if (parking.isNotEmpty) n++;
    if (foodIncluded != null) n++;
    if (amenities.isNotEmpty) n++;
    if (nearby.isNotEmpty) n++;
    if (restrictions.isNotEmpty) n++;
    return n;
  }

  bool get hasPremiumFilters =>
      amenities.isNotEmpty ||
      nearby.isNotEmpty ||
      restrictions.isNotEmpty ||
      premiumSort.isNotEmpty;

  // -- Query params ----------------------------------------------------------
  Map<String, String> toQueryParams() {
    final m = <String, String>{};
    if (city.isNotEmpty) m['city'] = city;
    if (locality.isNotEmpty) m['locality'] = locality;
    if (search.isNotEmpty) m['search'] = search;
    if (pgFor.isNotEmpty) m['pgFor'] = pgFor;
    if (sharingTypes.isNotEmpty) m['sharingTypes'] = sharingTypes.join(',');
    if (preferredTenant.isNotEmpty) m['preferredTenant'] = preferredTenant;
    if (availability.isNotEmpty) m['availability'] = availability;
    if (parking.isNotEmpty) m['parking'] = parking;
    if (foodIncluded != null) m['foodIncluded'] = foodIncluded!.toString();
    m['rentMin'] = rentMin.toStringAsFixed(0);
    m['rentMax'] = rentMax.toStringAsFixed(0);
    m['sortBy'] = sortBy;
    if (amenities.isNotEmpty) m['amenities'] = amenities.join(',');
    if (nearby.isNotEmpty) m['nearby'] = nearby.join(',');
    if (restrictions.isNotEmpty) m['restrictions'] = restrictions.join(',');
    if (premiumSort.isNotEmpty) m['premiumSort'] = premiumSort;
    return m;
  }

  factory SearchModel.fromQueryParams(Map<String, String> p) {
    bool? food;
    if (p['foodIncluded'] == 'true') food = true;
    if (p['foodIncluded'] == 'false') food = false;

    List<String> splitParam(String key) =>
        p[key]?.isNotEmpty == true ? p[key]!.split(',') : [];

    return SearchModel(
      city: p['city'] ?? '',
      locality: p['locality'] ?? '',
      search: p['search'] ?? '',
      rentMin: double.tryParse(p['rentMin'] ?? '0') ?? 0,
      rentMax: double.tryParse(p['rentMax'] ?? '1000000') ?? 1000000,
      pgFor: p['pgFor'] ?? '',
      sharingTypes: splitParam('sharingTypes'),
      preferredTenant: p['preferredTenant'] ?? '',
      availability: p['availability'] ?? '',
      parking: p['parking'] ?? '',
      foodIncluded: food,
      sortBy: p['sortBy'] ?? 'newest',
      amenities: splitParam('amenities'),
      nearby: splitParam('nearby'),
      restrictions: splitParam('restrictions'),
      premiumSort: p['premiumSort'] ?? '',
    );
  }
}
