// filter_sidebar.dart

// Converted from Filter.jsx — Standalone Filter Sidebar Component



import 'package:flutter/material.dart';



// --- THEME CONSTANTS ----------------------------------------------------------

const Color kGreen      = Color(0xFF0A7C66);

const Color kGreenDark  = Color(0xFF085F4E);

const Color kGreenLight = Color(0xFFF0FAF4);

const Color kGreenMid   = Color(0xFFD1FAE5);

const Color kText1      = Color(0xFF1A1A2E);

const Color kText2      = Color(0xFF4B5563);

const Color kText3      = Color(0xFF9CA3AF);

const Color kBorder     = Color(0xFFE5E7EB);

const Color kBg         = Color(0xFFF5F6F8);

const Color kCard       = Color(0xFFFFFFFF);



// --- CATEGORY OPTIONS ---------------------------------------------------------

const List<String> kCategories = ["All", "Apartment", "PG", "Commercial"];



// PG

const List<String> kPgFor       = ["Male", "Female", "Anyone"];

const List<String> kRoomTypes   = ["Single Room", "Double Room", "Triple Room", "Four Room"];

const List<String> kPreferredFor = ["Student", "Professional"];

const List<String> kFood        = ["BreakFast", "Lunch", "Dinner"];

const List<String> kShowOnlyPg  = ["With Photos", "Attached Bathroom"];



// Apartment

const List<String> kBhk        = ["1 RK", "1 BHK", "2 BHK", "3 BHK", "4 BHK", "4+ BHK"];

const List<String> kAptTypes   = ["Gated Societies", "Apartment", "Independent House/Villa", "Gated Community Villa"];

const List<String> kAptFurnish = ["Fully Furnished", "Semi-Furnished", "Unfurnished"];

const List<String> kAptParking = ["2 Wheeler", "4 Wheeler"];

const List<String> kTenants    = ["Family", "Company", "Bachelor Male", "Bachelor Female"];

const List<String> kAvail      = ["Immediately", "Within 15 Days", "Within 30 Days", "After 30 Days"];



// Commercial

const List<String> kCommTypes    = ["Office Space", "Co-Working", "Shop", "Showroom", "Godown/Warehouse", "Industrial Shed", "Industrial Building", "Other Business", "Restaurant/Cafe"];

const List<String> kCommFurnish  = ["Fully Furnished", "Semi-Furnished", "Unfurnished"];

const List<String> kCommParking  = ["Public", "Reserved"];

const List<String> kBuildingType = ["Independent House", "Business Park", "Mall", "Standalone Building", "Independent Shop"];



// --- FILTER MODEL -------------------------------------------------------------

class PropertyFilters {

  double rentMin;

  double rentMax;

  double builtAreaMin;

  double builtAreaMax;

  List<String> availability;

  String pgFor;

  List<String> roomTypes;

  List<String> preferredFor;

  List<String> foodIncluded;

  List<String> showOnlyPG;

  bool removeSeenPG;

  List<String> bhk;

  List<String> aptTypes;

  List<String> aptFurnishing;

  List<String> aptParking;

  List<String> tenants;

  bool visitNext2Days;

  bool ownerHostingVisit;

  bool showLeaseOnly;

  List<String> commTypes;

  List<String> commFurnishing;

  List<String> commParking;

  List<String> buildingType;



  PropertyFilters({

    this.rentMin = 0,

    double? rentMax,

    this.builtAreaMin = 0,

    this.builtAreaMax = 100000,

    List<String>? availability,

    this.pgFor = '',

    List<String>? roomTypes,

    List<String>? preferredFor,

    List<String>? foodIncluded,

    List<String>? showOnlyPG,

    this.removeSeenPG = false,

    List<String>? bhk,

    List<String>? aptTypes,

    List<String>? aptFurnishing,

    List<String>? aptParking,

    List<String>? tenants,

    this.visitNext2Days = false,

    this.ownerHostingVisit = false,

    this.showLeaseOnly = false,

    List<String>? commTypes,

    List<String>? commFurnishing,

    List<String>? commParking,

    List<String>? buildingType,

    String lookingFor = 'All',

  })  : rentMax = rentMax ??

            (lookingFor == 'Commercial'

                ? 10000000

                : lookingFor == 'Apartment'

                    ? 500000

                    : 100000),

        availability = availability ?? [],

        roomTypes = roomTypes ?? [],

        preferredFor = preferredFor ?? [],

        foodIncluded = foodIncluded ?? [],

        showOnlyPG = showOnlyPG ?? [],

        bhk = bhk ?? [],

        aptTypes = aptTypes ?? [],

        aptFurnishing = aptFurnishing ?? [],

        aptParking = aptParking ?? [],

        tenants = tenants ?? [],

        commTypes = commTypes ?? [],

        commFurnishing = commFurnishing ?? [],

        commParking = commParking ?? [],

        buildingType = buildingType ?? [];



  PropertyFilters copyWith({

    double? rentMin,

    double? rentMax,

    double? builtAreaMin,

    double? builtAreaMax,

    List<String>? availability,

    String? pgFor,

    List<String>? roomTypes,

    List<String>? preferredFor,

    List<String>? foodIncluded,

    List<String>? showOnlyPG,

    bool? removeSeenPG,

    List<String>? bhk,

    List<String>? aptTypes,

    List<String>? aptFurnishing,

    List<String>? aptParking,

    List<String>? tenants,

    bool? visitNext2Days,

    bool? ownerHostingVisit,

    bool? showLeaseOnly,

    List<String>? commTypes,

    List<String>? commFurnishing,

    List<String>? commParking,

    List<String>? buildingType,

  }) {

    return PropertyFilters(

      rentMin: rentMin ?? this.rentMin,

      rentMax: rentMax ?? this.rentMax,

      builtAreaMin: builtAreaMin ?? this.builtAreaMin,

      builtAreaMax: builtAreaMax ?? this.builtAreaMax,

      availability: availability ?? List.from(this.availability),

      pgFor: pgFor ?? this.pgFor,

      roomTypes: roomTypes ?? List.from(this.roomTypes),

      preferredFor: preferredFor ?? List.from(this.preferredFor),

      foodIncluded: foodIncluded ?? List.from(this.foodIncluded),

      showOnlyPG: showOnlyPG ?? List.from(this.showOnlyPG),

      removeSeenPG: removeSeenPG ?? this.removeSeenPG,

      bhk: bhk ?? List.from(this.bhk),

      aptTypes: aptTypes ?? List.from(this.aptTypes),

      aptFurnishing: aptFurnishing ?? List.from(this.aptFurnishing),

      aptParking: aptParking ?? List.from(this.aptParking),

      tenants: tenants ?? List.from(this.tenants),

      visitNext2Days: visitNext2Days ?? this.visitNext2Days,

      ownerHostingVisit: ownerHostingVisit ?? this.ownerHostingVisit,

      showLeaseOnly: showLeaseOnly ?? this.showLeaseOnly,

      commTypes: commTypes ?? List.from(this.commTypes),

      commFurnishing: commFurnishing ?? List.from(this.commFurnishing),

      commParking: commParking ?? List.from(this.commParking),

      buildingType: buildingType ?? List.from(this.buildingType),

    );

  }



  static PropertyFilters init(String lookingFor) =>

      PropertyFilters(lookingFor: lookingFor);

}



// --- FILTER SIDEBAR WIDGET ----------------------------------------------------

class FilterSidebar extends StatefulWidget {

  final PropertyFilters filters;

  final ValueChanged<PropertyFilters> onFiltersChanged;

  final String lookingFor;

  final ValueChanged<String> onLookingForChanged;

  final int filterCount;

  final bool isOpen;

  final VoidCallback onClose;

  final VoidCallback onReset;

  final VoidCallback onPageReset;



  const FilterSidebar({

    super.key,

    required this.filters,

    required this.onFiltersChanged,

    required this.lookingFor,

    required this.onLookingForChanged,

    required this.filterCount,

    required this.isOpen,

    required this.onClose,

    required this.onReset,

    required this.onPageReset,

  });



  @override

  State<FilterSidebar> createState() => _FilterSidebarState();

}



class _FilterSidebarState extends State<FilterSidebar> {

  bool _showPremium = false;



  void _update(PropertyFilters f) {

    widget.onFiltersChanged(f);

    widget.onPageReset();

  }



  @override

  Widget build(BuildContext context) {

    final isMobile = MediaQuery.of(context).size.width < 900;



    if (isMobile) {

      return Stack(

        children: [

          if (widget.isOpen)

            GestureDetector(

              onTap: widget.onClose,

              child: Container(

                color: Colors.black.withOpacity(0.45),

                width: double.infinity,

                height: double.infinity,

              ),

            ),

          AnimatedPositioned(

            duration: const Duration(milliseconds: 300),

            curve: Curves.easeInOut,

            left: widget.isOpen ? 0 : -310,

            top: 0,

            bottom: 0,

            width: 300,

            child: _buildSidebarContent(),

          ),

        ],

      );

    }



    return SizedBox(

      width: 280,

      child: _buildSidebarContent(),

    );

  }



  Widget _buildSidebarContent() {

    return Container(

      decoration: BoxDecoration(

        color: kCard,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorder),

        boxShadow: const [

          BoxShadow(

              color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),

        ],

      ),

      child: Column(

        children: [

          _buildHeader(),

          _buildCategoryTabs(),

          Expanded(child: _buildScrollBody()),

        ],

      ),

    );

  }



  // -- Header ------------------------------------------------------------------

  Widget _buildHeader() {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),

      decoration: const BoxDecoration(

        border: Border(bottom: BorderSide(color: kBorder)),

      ),

      child: Row(

        children: [

          Text(

            'Filters',

            style: const TextStyle(

                fontSize: 14, fontWeight: FontWeight.w700, color: kText1),

          ),

          if (widget.filterCount > 0) ...[

            const SizedBox(width: 6),

            Container(

              padding: const EdgeInsets.symmetric(horizontal: 7),

              decoration: BoxDecoration(

                color: kGreen,

                borderRadius: BorderRadius.circular(20),

              ),

              child: Text(

                '${widget.filterCount}',

                style: const TextStyle(

                    color: Colors.white,

                    fontSize: 11,

                    fontWeight: FontWeight.w600),

              ),

            ),

          ],

          const SizedBox(width: 8),

          // Premium / Filters toggle

          Container(

            padding: const EdgeInsets.all(3),

            decoration: BoxDecoration(

              color: kBg,

              borderRadius: BorderRadius.circular(20),

            ),

            child: Row(

              children: [

                _tabBtn('Filters', !_showPremium,

                    () => setState(() => _showPremium = false)),

                _tabBtn('Premium', _showPremium,

                    () => setState(() => _showPremium = true)),

              ],

            ),

          ),

          const Spacer(),

          if (widget.filterCount > 0)

            GestureDetector(

              onTap: widget.onReset,

              child: const Text(

                '? Reset',

                style: TextStyle(

                    fontSize: 12,

                    color: kGreen,

                    fontWeight: FontWeight.w600),

              ),

            ),

        ],

      ),

    );

  }



  Widget _tabBtn(String label, bool active, VoidCallback onTap) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 150),

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

        decoration: BoxDecoration(

          color: active ? kCard : Colors.transparent,

          borderRadius: BorderRadius.circular(20),

          boxShadow: active

              ? [

                  const BoxShadow(

                      color: Color(0x14000000),

                      blurRadius: 3,

                      offset: Offset(0, 1))

                ]

              : [],

        ),

        child: Text(

          label,

          style: TextStyle(

            fontSize: 11.5,

            fontWeight: FontWeight.w600,

            color: active ? kGreen : kText3,

          ),

        ),

      ),

    );

  }



  // -- Category tabs ------------------------------------------------------------

  Widget _buildCategoryTabs() {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),

      decoration: const BoxDecoration(

        border: Border(bottom: BorderSide(color: kBorder)),

      ),

      child: Wrap(

        spacing: 4,

        runSpacing: 4,

        children: kCategories.map((t) {

          final on = widget.lookingFor == t;

          return GestureDetector(

            onTap: () {

              widget.onLookingForChanged(t);

              widget.onPageReset();

            },

            child: AnimatedContainer(

              duration: const Duration(milliseconds: 150),

              padding:

                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

              decoration: BoxDecoration(

                color: on ? kGreen : kBg,

                border: Border.all(color: on ? kGreen : kBorder, width: 1.5),

                borderRadius: BorderRadius.circular(20),

              ),

              child: Text(

                t,

                style: TextStyle(

                  fontSize: 11.5,

                  fontWeight: FontWeight.w600,

                  color: on ? Colors.white : kText2,

                ),

              ),

            ),

          );

        }).toList(),

      ),

    );

  }



  // -- Scrollable body ----------------------------------------------------------

  Widget _buildScrollBody() {

    return SingleChildScrollView(

      child: _showPremium

          ? _PremiumFiltersUI()

          : Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                if (widget.lookingFor == 'All' ||

                    widget.lookingFor == 'PG') ...[

                  if (widget.lookingFor == 'All')

                    _PanelLabel(label: 'PG'),

                  _PGFilters(

                    f: widget.filters,

                    onChanged: _update,

                  ),

                ],

                if (widget.lookingFor == 'All' ||

                    widget.lookingFor == 'Apartment') ...[

                  if (widget.lookingFor == 'All')

                    _PanelLabel(label: 'Apartment'),

                  _ApartmentFilters(

                    f: widget.filters,

                    onChanged: _update,

                  ),

                ],

                if (widget.lookingFor == 'All' ||

                    widget.lookingFor == 'Commercial') ...[

                  if (widget.lookingFor == 'All')

                    _PanelLabel(label: 'Commercial'),

                  _CommercialFilters(

                    f: widget.filters,

                    onChanged: _update,

                  ),

                ],

              ],

            ),

    );

  }

}



// --- PANEL LABEL -------------------------------------------------------------

class _PanelLabel extends StatelessWidget {

  final String label;

  const _PanelLabel({required this.label});



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),

      decoration: const BoxDecoration(

        color: kGreenLight,

        border: Border(top: BorderSide(color: kGreenMid, width: 2)),

      ),

      child: Text(

        label.toUpperCase(),

        style: const TextStyle(

          fontSize: 10,

          fontWeight: FontWeight.w800,

          letterSpacing: 0.8,

          color: kGreen,

        ),

      ),

    );

  }

}



// --- COLLAPSIBLE SECTION -----------------------------------------------------

class _Section extends StatefulWidget {

  final String title;

  final Widget child;

  final bool initiallyOpen;



  const _Section({

    required this.title,

    required this.child,

    this.initiallyOpen = true,

  });



  @override

  State<_Section> createState() => _SectionState();

}



class _SectionState extends State<_Section> {

  late bool _open;



  @override

  void initState() {

    super.initState();

    _open = widget.initiallyOpen;

  }



  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: const BoxDecoration(

        border: Border(top: BorderSide(color: kBorder)),

      ),

      child: Column(

        children: [

          GestureDetector(

            onTap: () => setState(() => _open = !_open),

            child: Container(

              width: double.infinity,

              padding:

                  const EdgeInsets.symmetric(horizontal: 15, vertical: 9),

              color: Colors.transparent,

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Text(

                    widget.title.toUpperCase(),

                    style: const TextStyle(

                      fontSize: 10,

                      fontWeight: FontWeight.w700,

                      letterSpacing: 0.5,

                      color: kText2,

                    ),

                  ),

                  AnimatedRotation(

                    turns: _open ? 0.5 : 0,

                    duration: const Duration(milliseconds: 200),

                    child: const Icon(Icons.keyboard_arrow_down,

                        size: 16, color: kText3),

                  ),

                ],

              ),

            ),

          ),

          if (_open)

            Padding(

              padding:

                  const EdgeInsets.only(left: 13, right: 13, bottom: 13),

              child: widget.child,

            ),

        ],

      ),

    );

  }

}



// --- CHIP BUTTON (toggle) -----------------------------------------------------

class _ChipBtn extends StatelessWidget {

  final String label;

  final bool active;

  final VoidCallback onTap;



  const _ChipBtn(

      {required this.label, required this.active, required this.onTap});



  @override

  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 150),

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

        decoration: BoxDecoration(

          color: active ? kGreen : kCard,

          border: Border.all(

              color: active ? kGreen : kBorder, width: 1.5),

          borderRadius: BorderRadius.circular(20),

        ),

        child: Text(

          label,

          style: TextStyle(

            fontSize: 12,

            fontWeight: FontWeight.w500,

            color: active ? Colors.white : kText2,

          ),

        ),

      ),

    );

  }

}



// --- RADIO GROUP -------------------------------------------------------------

class _RadioGroup extends StatelessWidget {

  final List<String> options;

  final String value;

  final ValueChanged<String> onChange;



  const _RadioGroup(

      {required this.options, required this.value, required this.onChange});



  @override

  Widget build(BuildContext context) {

    return Column(

      children: options.map((opt) {

        final on = value == opt;

        return GestureDetector(

          onTap: () => onChange(on ? '' : opt),

          child: AnimatedContainer(

            duration: const Duration(milliseconds: 150),

            width: double.infinity,

            margin: const EdgeInsets.only(bottom: 7),

            padding:

                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

            decoration: BoxDecoration(

              color: on ? kGreenLight : kCard,

              border: Border.all(

                  color: on ? kGreen : kBorder, width: 1.5),

              borderRadius: BorderRadius.circular(8),

            ),

            child: Row(

              children: [

                Container(

                  width: 14,

                  height: 14,

                  decoration: BoxDecoration(

                    shape: BoxShape.circle,

                    border: Border.all(

                        color: on ? kGreen : kBorder, width: 2),

                    color: on ? kGreen : Colors.transparent,

                  ),

                  child: on

                      ? Container(

                          margin: const EdgeInsets.all(2),

                          decoration: const BoxDecoration(

                            shape: BoxShape.circle,

                            color: kGreenLight,

                          ),

                        )

                      : null,

                ),

                const SizedBox(width: 8),

                Text(

                  opt,

                  style: TextStyle(

                    fontSize: 13,

                    fontWeight: FontWeight.w500,

                    color: on ? kGreen : kText2,

                  ),

                ),

              ],

            ),

          ),

        );

      }).toList(),

    );

  }

}



// --- CHECKBOX GROUP ----------------------------------------------------------

class _CheckGroup extends StatelessWidget {

  final List<String> options;

  final List<String> values;

  final ValueChanged<List<String>> onChange;



  const _CheckGroup(

      {required this.options,

      required this.values,

      required this.onChange});



  @override

  Widget build(BuildContext context) {

    return Column(

      children: options.map((opt) {

        final on = values.contains(opt);

        return GestureDetector(

          onTap: () {

            final next = on

                ? values.where((v) => v != opt).toList()

                : [...values, opt];

            onChange(next);

          },

          child: AnimatedContainer(

            duration: const Duration(milliseconds: 150),

            width: double.infinity,

            margin: const EdgeInsets.only(bottom: 6),

            padding:

                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

            decoration: BoxDecoration(

              color: on ? kGreenLight : kCard,

              border: Border.all(

                  color: on ? kGreen : kBorder, width: 1.5),

              borderRadius: BorderRadius.circular(8),

            ),

            child: Row(

              children: [

                AnimatedContainer(

                  duration: const Duration(milliseconds: 150),

                  width: 14,

                  height: 14,

                  decoration: BoxDecoration(

                    color: on ? kGreen : Colors.transparent,

                    border: Border.all(

                        color: on ? kGreen : kBorder, width: 2),

                    borderRadius: BorderRadius.circular(4),

                  ),

                  child: on

                      ? const Icon(Icons.check,

                          size: 10, color: Colors.white)

                      : null,

                ),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    opt,

                    style: TextStyle(

                      fontSize: 13,

                      fontWeight: FontWeight.w500,

                      color: on ? kGreen : kText2,

                    ),

                  ),

                ),

              ],

            ),

          ),

        );

      }).toList(),

    );

  }

}



// --- DUAL RANGE SLIDER -------------------------------------------------------

class _DualRangeSlider extends StatelessWidget {

  final String label;

  final double min;

  final double max;

  final double step;

  final double valueMin;

  final double valueMax;

  final ValueChanged<double> onChangeMin;

  final ValueChanged<double> onChangeMax;

  final String Function(double) format;



  const _DualRangeSlider({

    required this.label,

    required this.min,

    required this.max,

    required this.step,

    required this.valueMin,

    required this.valueMax,

    required this.onChangeMin,

    required this.onChangeMax,

    required this.format,

  });



  @override

  Widget build(BuildContext context) {

    final safeMin = valueMin.clamp(min, max - step);

    final safeMax = valueMax.clamp(min + step, max);



    return Column(

      children: [

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(label,

                style: const TextStyle(

                    fontSize: 12,

                    fontWeight: FontWeight.w600,

                    color: kText2)),

            Text(

              '${format(safeMin)} — ${format(safeMax)}${safeMax >= max ? "+" : ""}',

              style: const TextStyle(

                  fontSize: 12,

                  fontWeight: FontWeight.w700,

                  color: kGreen,

                  fontStyle: FontStyle.italic),

            ),

          ],

        ),

        const SizedBox(height: 8),

        SliderTheme(

          data: SliderTheme.of(context).copyWith(

            activeTrackColor: kGreen,

            inactiveTrackColor: kBorder,

            thumbColor: kGreen,

            overlayColor: kGreen.withOpacity(0.12),

            trackHeight: 4,

          ),

          child: Column(

            children: [

              Slider(

                min: min,

                max: max,

                value: safeMin,

                onChanged: (v) {

                  if (v < safeMax - step) onChangeMin(v);

                },

              ),

              Slider(

                min: min,

                max: max,

                value: safeMax,

                onChanged: (v) {

                  if (v > safeMin + step) onChangeMax(v);

                },

              ),

            ],

          ),

        ),

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(format(min),

                style: const TextStyle(fontSize: 10.5, color: kText3)),

            Text('${format(max)}+',

                style: const TextStyle(fontSize: 10.5, color: kText3)),

          ],

        ),

      ],

    );

  }

}



// --- TOGGLE CHIP -------------------------------------------------------------

class _ToggleChip extends StatelessWidget {

  final String label;

  final bool active;

  final VoidCallback onTap;



  const _ToggleChip(

      {required this.label, required this.active, required this.onTap});



  @override

  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 150),

        width: double.infinity,

        margin: const EdgeInsets.only(bottom: 5),

        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),

        decoration: BoxDecoration(

          color: active ? kGreenLight : kCard,

          border: Border.all(

              color: active ? kGreen : kBorder, width: 1.5),

          borderRadius: BorderRadius.circular(8),

        ),

        child: Row(

          children: [

            AnimatedContainer(

              duration: const Duration(milliseconds: 150),

              width: 16,

              height: 16,

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                color: active ? kGreen : Colors.transparent,

                border: Border.all(

                    color: active ? kGreen : kBorder, width: 2),

              ),

            ),

            const SizedBox(width: 8),

            Expanded(

              child: Text(

                label,

                style: TextStyle(

                  fontSize: 12.5,

                  fontWeight: FontWeight.w500,

                  color: active ? kGreen : kText2,

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



// --- PG FILTERS --------------------------------------------------------------

class _PGFilters extends StatelessWidget {

  final PropertyFilters f;

  final ValueChanged<PropertyFilters> onChanged;



  static const double _pgMax = 100000;



  const _PGFilters({required this.f, required this.onChanged});



  String _rentFmt(double v) {

    if (v >= _pgMax) return '?1L';

    if (v >= 1000) return '?${(v / 1000).toStringAsFixed(0)}K';

    return '?${v.toInt()}';

  }



  @override

  Widget build(BuildContext context) {

    return Column(

      children: [

        _Section(

          title: 'PG For',

          child: _RadioGroup(

            options: kPgFor,

            value: f.pgFor,

            onChange: (v) => onChanged(f.copyWith(pgFor: v)),

          ),

        ),

        _Section(

          title: 'Room Type',

          child: _CheckGroup(

            options: kRoomTypes,

            values: f.roomTypes,

            onChange: (v) => onChanged(f.copyWith(roomTypes: v)),

          ),

        ),

        _Section(

          title: 'Rent Range',

          child: _DualRangeSlider(

            label: 'Rent',

            min: 0,

            max: _pgMax,

            step: 1000,

            valueMin: f.rentMin.clamp(0, _pgMax),

            valueMax: f.rentMax.clamp(0, _pgMax),

            onChangeMin: (v) => onChanged(f.copyWith(rentMin: v)),

            onChangeMax: (v) => onChanged(f.copyWith(rentMax: v)),

            format: _rentFmt,

          ),

        ),

        _Section(

          title: 'Preferred For',

          child: _CheckGroup(

            options: kPreferredFor,

            values: f.preferredFor,

            onChange: (v) => onChanged(f.copyWith(preferredFor: v)),

          ),

        ),

        _Section(

          title: 'Food Included',

          child: _CheckGroup(

            options: kFood,

            values: f.foodIncluded,

            onChange: (v) => onChanged(f.copyWith(foodIncluded: v)),

          ),

        ),

        _Section(

          title: 'Show Only',

          child: Wrap(

            spacing: 5,

            runSpacing: 5,

            children: kShowOnlyPg.map((opt) {

              return _ChipBtn(

                label: opt,

                active: f.showOnlyPG.contains(opt),

                onTap: () {

                  final next = f.showOnlyPG.contains(opt)

                      ? f.showOnlyPG.where((v) => v != opt).toList()

                      : [...f.showOnlyPG, opt];

                  onChanged(f.copyWith(showOnlyPG: next));

                },

              );

            }).toList(),

          ),

        ),

        _Section(

          title: 'Remove Seen Properties',

          initiallyOpen: false,

          child: GestureDetector(

            onTap: () =>

                onChanged(f.copyWith(removeSeenPG: !f.removeSeenPG)),

            child: AnimatedContainer(

              duration: const Duration(milliseconds: 150),

              width: double.infinity,

              padding:

                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

              decoration: BoxDecoration(

                color: f.removeSeenPG ? kGreenLight : kCard,

                border: Border.all(

                    color: f.removeSeenPG ? kGreen : kBorder, width: 1.5),

                borderRadius: BorderRadius.circular(8),

              ),

              child: Row(

                children: [

                  AnimatedContainer(

                    duration: const Duration(milliseconds: 150),

                    width: 14,

                    height: 14,

                    decoration: BoxDecoration(

                      color: f.removeSeenPG

                          ? kGreen

                          : Colors.transparent,

                      border: Border.all(

                          color: f.removeSeenPG ? kGreen : kBorder,

                          width: 2),

                      borderRadius: BorderRadius.circular(4),

                    ),

                    child: f.removeSeenPG

                        ? const Icon(Icons.check,

                            size: 10, color: Colors.white)

                        : null,

                  ),

                  const SizedBox(width: 8),

                  const Expanded(

                    child: Text(

                        "Remove properties I've already seen",

                        style: TextStyle(fontSize: 13, color: kText2)),

                  ),

                  Container(

                    padding: const EdgeInsets.symmetric(

                        horizontal: 5, vertical: 1),

                    decoration: BoxDecoration(

                      color: const Color(0xFFFF6B35),

                      borderRadius: BorderRadius.circular(20),

                    ),

                    child: const Text('NEW',

                        style: TextStyle(

                            color: Colors.white,

                            fontSize: 9,

                            fontWeight: FontWeight.w800)),

                  ),

                ],

              ),

            ),

          ),

        ),

      ],

    );

  }

}



// --- APARTMENT FILTERS -------------------------------------------------------

class _ApartmentFilters extends StatelessWidget {

  final PropertyFilters f;

  final ValueChanged<PropertyFilters> onChanged;



  static const double _aptMax = 500000;



  const _ApartmentFilters({required this.f, required this.onChanged});



  String _rentFmt(double v) {

    if (v >= _aptMax) return '?5L';

    if (v >= 100000) return '?${(v / 100000).toStringAsFixed(1)}L';

    if (v >= 1000) return '?${(v / 1000).toStringAsFixed(0)}K';

    return '?${v.toInt()}';

  }



  @override

  Widget build(BuildContext context) {

    return Column(

      children: [

        _Section(

          title: 'BHK Type',

          child: Wrap(

            spacing: 5,

            runSpacing: 5,

            children: kBhk.map((b) {

              return _ChipBtn(

                label: b,

                active: f.bhk.contains(b),

                onTap: () {

                  final next = f.bhk.contains(b)

                      ? f.bhk.where((v) => v != b).toList()

                      : [...f.bhk, b];

                  onChanged(f.copyWith(bhk: next));

                },

              );

            }).toList(),

          ),

        ),

        _Section(

          title: 'Rent Range',

          child: _DualRangeSlider(

            label: 'Rent',

            min: 0,

            max: _aptMax,

            step: 5000,

            valueMin: f.rentMin.clamp(0, _aptMax),

            valueMax: f.rentMax.clamp(0, _aptMax),

            onChangeMin: (v) => onChanged(f.copyWith(rentMin: v)),

            onChangeMax: (v) => onChanged(f.copyWith(rentMax: v)),

            format: _rentFmt,

          ),

        ),

        _Section(

          title: 'Visit Properties',

          child: Column(

            children: [

              _ToggleChip(

                label: 'Visit within next 2 days',

                active: f.visitNext2Days,

                onTap: () =>

                    onChanged(f.copyWith(visitNext2Days: !f.visitNext2Days)),

              ),

              _ToggleChip(

                label: 'Owner hosting a visit',

                active: f.ownerHostingVisit,

                onTap: () => onChanged(

                    f.copyWith(ownerHostingVisit: !f.ownerHostingVisit)),

              ),

            ],

          ),

        ),

        _Section(

          title: 'Availability',

          child: _RadioGroup(

            options: kAvail,

            value: f.availability.isNotEmpty ? f.availability.first : '',

            onChange: (v) =>

                onChanged(f.copyWith(availability: v.isEmpty ? [] : [v])),

          ),

        ),

        _Section(

          title: 'Preferred Tenants',

          child: _CheckGroup(

            options: kTenants,

            values: f.tenants,

            onChange: (v) => onChanged(f.copyWith(tenants: v)),

          ),

        ),

        _Section(

          title: 'Property Type',

          child: _CheckGroup(

            options: kAptTypes,

            values: f.aptTypes,

            onChange: (v) => onChanged(f.copyWith(aptTypes: v)),

          ),

        ),

        _Section(

          title: 'Furnishing',

          child: _CheckGroup(

            options: kAptFurnish,

            values: f.aptFurnishing,

            onChange: (v) => onChanged(f.copyWith(aptFurnishing: v)),

          ),

        ),

        _Section(

          title: 'Parking',

          child: _CheckGroup(

            options: kAptParking,

            values: f.aptParking,

            onChange: (v) => onChanged(f.copyWith(aptParking: v)),

          ),

        ),

        _Section(

          title: 'Show Only',

          initiallyOpen: false,

          child: _ToggleChip(

            label: 'Show Only Lease Properties',

            active: f.showLeaseOnly,

            onTap: () =>

                onChanged(f.copyWith(showLeaseOnly: !f.showLeaseOnly)),

          ),

        ),

      ],

    );

  }

}



// --- COMMERCIAL FILTERS ------------------------------------------------------

class _CommercialFilters extends StatelessWidget {

  final PropertyFilters f;

  final ValueChanged<PropertyFilters> onChanged;



  static const double _commMax = 10000000;



  const _CommercialFilters({required this.f, required this.onChanged});



  String _rentFmt(double v) {

    if (v >= _commMax) return '?1Cr';

    if (v >= 100000) return '?${(v / 100000).toStringAsFixed(0)}L';

    if (v >= 1000) return '?${(v / 1000).toStringAsFixed(0)}K';

    return '?${v.toInt()}';

  }



  String _areaFmt(double v) => '${v.toInt()} sq.ft';



  @override

  Widget build(BuildContext context) {

    return Column(

      children: [

        _Section(

          title: 'Property Type',

          child: _CheckGroup(

            options: kCommTypes,

            values: f.commTypes,

            onChange: (v) => onChanged(f.copyWith(commTypes: v)),

          ),

        ),

        _Section(

          title: 'Rent Range',

          child: _DualRangeSlider(

            label: 'Rent',

            min: 0,

            max: _commMax,

            step: 50000,

            valueMin: f.rentMin.clamp(0, _commMax),

            valueMax: f.rentMax.clamp(0, _commMax),

            onChangeMin: (v) => onChanged(f.copyWith(rentMin: v)),

            onChangeMax: (v) => onChanged(f.copyWith(rentMax: v)),

            format: _rentFmt,

          ),

        ),

        _Section(

          title: 'Built Up Area (sq.ft.)',

          child: _DualRangeSlider(

            label: 'Area',

            min: 0,

            max: 100000,

            step: 100,

            valueMin: f.builtAreaMin,

            valueMax: f.builtAreaMax,

            onChangeMin: (v) => onChanged(f.copyWith(builtAreaMin: v)),

            onChangeMax: (v) => onChanged(f.copyWith(builtAreaMax: v)),

            format: _areaFmt,

          ),

        ),

        _Section(

          title: 'Furnishing',

          child: _CheckGroup(

            options: kCommFurnish,

            values: f.commFurnishing,

            onChange: (v) => onChanged(f.copyWith(commFurnishing: v)),

          ),

        ),

        _Section(

          title: 'Building Type',

          child: _CheckGroup(

            options: kBuildingType,

            values: f.buildingType,

            onChange: (v) => onChanged(f.copyWith(buildingType: v)),

          ),

        ),

        _Section(

          title: 'Availability',

          child: _RadioGroup(

            options: kAvail,

            value: f.availability.isNotEmpty ? f.availability.first : '',

            onChange: (v) =>

                onChanged(f.copyWith(availability: v.isEmpty ? [] : [v])),

          ),

        ),

        _Section(

          title: 'Parking',

          child: _CheckGroup(

            options: kCommParking,

            values: f.commParking,

            onChange: (v) => onChanged(f.copyWith(commParking: v)),

          ),

        ),

      ],

    );

  }

}



// --- PREMIUM FILTERS (stub UI) ------------------------------------------------

class _PremiumFiltersUI extends StatelessWidget {

  @override

  Widget build(BuildContext context) {

    return Column(

      children: [

        _Section(

          title: 'Show Only',

          child: Column(

            children: [

              Wrap(

                spacing: 5,

                children: [

                  _ChipBtn(

                      label: 'With Photos', active: false, onTap: () {}),

                ],

              ),

              const SizedBox(height: 8),

              Container(

                padding: const EdgeInsets.symmetric(

                    horizontal: 9, vertical: 5),

                decoration: BoxDecoration(

                  color: kCard,

                  border: Border.all(color: kBorder, width: 1.5),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: Row(

                  children: [

                    const Text('Remove Seen Properties',

                        style:

                            TextStyle(fontSize: 13, color: kText2)),

                    const SizedBox(width: 6),

                    Container(

                      padding: const EdgeInsets.symmetric(

                          horizontal: 5, vertical: 1),

                      decoration: BoxDecoration(

                        color: const Color(0xFFFF6B35),

                        borderRadius: BorderRadius.circular(20),

                      ),

                      child: const Text('NEW',

                          style: TextStyle(

                              color: Colors.white,

                              fontSize: 9,

                              fontWeight: FontWeight.w800)),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

        _Section(

          title: 'Amenities',

          child: _CheckGroup(

            options: const ['Power Backup', 'Lift'],

            values: const [],

            onChange: (_) {},

          ),

        ),

        _Section(

          title: 'Floors',

          child: Wrap(

            spacing: 5,

            runSpacing: 5,

            children: ['Ground', '1 to 3', '4 to 6', '7 to 9', '10 & above', 'Custom']

                .map((f) => _ChipBtn(label: f, active: false, onTap: () {}))

                .toList(),

          ),

        ),

        _Section(

          title: 'Property Age',

          child: _CheckGroup(

            options: const [

              'Less than a Year',

              '1 to 5 year',

              '5 to 10 year',

              'More than 10 year'

            ],

            values: const [],

            onChange: (_) {},

          ),

        ),

      ],

    );

  }

}

