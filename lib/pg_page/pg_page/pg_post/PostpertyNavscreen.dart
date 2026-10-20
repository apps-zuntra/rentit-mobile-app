// PostpertyNavscreen.dart
import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/pg_page/pg_page/pg_post/PGRoomTypeDetailsScreen.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentPropertydetails.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialPropertydetails.dart';
import 'package:rentit/screen/Flatmate/Flatmate/FlatmatePropertydetails.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TopProgressBar extends StatelessWidget {
  const _TopProgressBar({this.currentStep = 1, this.totalSteps = 8});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 4),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isCompleted
                  ? const Color(0xFF2F4253)
                  : const Color(0xFFE5E7EB),
            ),
          ),
        );
      }),
    );
  }
}

class PostPropertyScreen extends StatefulWidget {
  const PostPropertyScreen({super.key});

  @override
  State<PostPropertyScreen> createState() => _PostPropertyScreenState();
}

const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kCardBorder = Color(0xFFE8ECF0);
const Color _kPrimaryText = Color(0xFF1A2332);
const Color _kLabelColor = Color(0xFF8A97A8);
const Color _kProgressFg = Color(0xFF2C3E50);
const Color _kProgressBg = Color(0xFFE4E9F0);

class _PostPropertyScreenState extends State<PostPropertyScreen> {
  // --- Config ------------------------------------------------------------------
  final String baseUrl = "https://rentit-backend-omega.vercel.app";

  // --- State -------------------------------------------------------------------
  String mainType = "Residential";
  String selectedCity = "Chennai";
  String subType = "PG/Hostel";
  bool loading = false;

  // --- Constants ---------------------------------------------------------------
  final List<String> cities = ["Chennai"];

  final List<Map<String, dynamic>> steps = [
    {"label": "Basic", "index": 0},
    {"label": "Property details", "index": 1},
    {"label": "Amenities", "index": 2},
    {"label": "Price details", "index": 3},
    {"label": "Photos", "index": 4},
    {"label": "Contact", "index": 5},
    {"label": "Verify", "index": 6},
  ];

  final int currentStep = 0;

  // --- Sub-types per main type --------------------------------------------------
  List<String> get subTypes {
    return ["Apartment", "PG/Hostel", "Flatmates"];
  }

  // --- Lifecycle ---------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    mainType = "Residential";
    subType = "PG/Hostel";
    selectedCity = "Chennai";
  }

  Future<int?> createBasic(String selectedSubType) async {
    if (selectedSubType.isEmpty) {
      _showMsg("Please select a property type");
      return null;
    }

    if (selectedCity.trim().isEmpty) {
      _showMsg("Please select a city");
      return null;
    }

    try {
      setState(() => loading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null) {
        _showMsg("Please login first");
        return null;
      }

      // ? If a propertyId already exists, reuse it - don't create a new row
      if (selectedSubType == "PG/Hostel") {
        final existingId = prefs.getInt("pgId");
        if (existingId != null) {
          debugPrint("REUSING EXISTING PG ID ?? $existingId");
          await prefs.setInt("propertyId", existingId);
          return existingId;
        }
      }

      if (selectedSubType == "Apartment") {
        final existingId = prefs.getInt("apartmentId");
        if (existingId != null) {
          debugPrint("REUSING EXISTING APARTMENT ID ?? $existingId");
          await prefs.setInt("propertyId", existingId);
          return existingId;
        }
      }

      if (selectedSubType == "Flatmates") {
        final existingId = prefs.getInt("flatmateId");
        if (existingId != null) {
          debugPrint("REUSING EXISTING FLATMATE ID ?? $existingId");
          return existingId;
        }
      }

      if (selectedSubType == "Commercial") {
        final existingId = prefs.getInt("commercialId");
        if (existingId != null) {
          debugPrint("REUSING EXISTING COMMERCIAL ID ?? $existingId");
          return existingId;
        }
      }

      // -- No existing ID — create a new row -------------------------------
      http.Response response;

      if (selectedSubType == "Commercial") {
        response = await http.post(
          Uri.parse("$baseUrl/commercial"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "city": selectedCity.trim(),
            "propertyType": "Commercial",
          }),
        );
      } else if (selectedSubType == "Flatmates") {
        response = await http.post(
          Uri.parse("$baseUrl/flatmate"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "city": selectedCity.trim(),
            "propertyType": "Flatmates",
          }),
        );
      } else {
        response = await http.post(
          Uri.parse("$baseUrl/property/basic"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "city": selectedCity.trim(),
            "propertyType": selectedSubType,
          }),
        );
      }

      debugPrint("STATUS ?? ${response.statusCode}");
      debugPrint("BODY ?? ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        int? propertyId;

        if (selectedSubType == "Commercial") {
          propertyId =
              data["id"] ?? data["commercial"]?["id"] ?? data["data"]?["id"];
          if (propertyId == null) {
            _showMsg("Commercial ID not found");
            return null;
          }
          await prefs.setInt("commercialId", propertyId);
          debugPrint("COMMERCIAL ID SAVED ?? $propertyId");
        } else if (selectedSubType == "Flatmates") {
          propertyId = data["id"];
          if (propertyId == null) {
            _showMsg("Flatmate ID not found");
            return null;
          }
          await prefs.setInt("flatmateId", propertyId);
          debugPrint("FLATMATE ID SAVED ?? $propertyId");
        } else {
          propertyId = data["id"];
          if (propertyId == null) {
            _showMsg("Property ID not found");
            return null;
          }
          await prefs.setInt("propertyId", propertyId);
          if (selectedSubType == "Apartment") {
            await prefs.setInt("apartmentId", propertyId);
            debugPrint("APARTMENT ID SAVED ?? $propertyId");
          } else if (selectedSubType == "PG/Hostel") {
            await prefs.setInt("pgId", propertyId);
            debugPrint("PG ID SAVED ?? $propertyId");
          }
        }

        return propertyId;
      } else {
        _showMsg(data["message"] ?? "Failed");
        return null;
      }
    } catch (e) {
      debugPrint("CREATE ERROR ?? $e");
      _showMsg("Something went wrong");
      return null;
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> navigateToDetails(String type) async {
    final prefs = await SharedPreferences.getInstance();

    switch (type) {
      case "Apartment":
        final apartmentId = prefs.getInt("apartmentId");

        if (apartmentId == null) {
          _showMsg("Apartment ID not found");
          return;
        }

        await prefs.setInt("propertyId", apartmentId);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ApartmentPropertyDetailsScreen(apartmentId: apartmentId),
          ),
        );
        break;

      case "PG/Hostel":
        final pgId = prefs.getInt("pgId");
        if (pgId != null) {
          await prefs.setInt("propertyId", pgId);
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PGRoomTypeDetailsScreen(selectedCity: selectedCity) as Widget,
          ),
        );
        break;

      // ? FLATMATES
      case "Flatmates":
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FlatmatePropertyDetailsScreen(),
          ),
        );
        break;

      case "Commercial":
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CommercialPropertyDetailsScreen(),
          ),
        );
        break;

      default:
        _showMsg("Unknown property type: $type");
    }
  }

  // --- Helpers -----------------------------------------------------------------
  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onContinue() async {
    final selectedType = mainType == "Commercial" ? "Commercial" : subType;

    final propertyId = await createBasic(selectedType);

    if (propertyId != null) {
      navigateToDetails(selectedType);
    }
  }

  // --- UI Widgets --------------------------------------------------------------
  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: _kCardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,

      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kCardBorder),
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            color: _kPrimaryText,
            size: 22,
          ),
        ),
      ),

      title: const Text(
        "Post New Propertys",
        style: TextStyle(
          color: _kPrimaryText,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),

      centerTitle: true,

      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              "1 / 8",
              style: TextStyle(
                color: _kLabelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(14),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _TopProgressBar(),
        ),
      ),
    );
  }

  Widget _cityDropdown() {
    return DropdownButtonFormField2<String>(
      value: selectedCity.isEmpty ? null : selectedCity,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "City",
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xff6B7280)),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        prefixIcon: const Icon(
          Icons.location_city_outlined,
          size: 20,
          color: Color(0xff6B7280),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(Icons.expand_more_rounded),
        iconSize: 22,
        iconEnabledColor: Color(0xff6B7280),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        elevation: 8,
      ),
      menuItemStyleData: const MenuItemStyleData(padding: EdgeInsets.zero),
      selectedItemBuilder: (context) {
        return cities.map((city) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              city,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: Color(0xff111827),
              ),
            ),
          );
        }).toList();
      },
      items: cities.map((city) {
        final isSelected = city == selectedCity;
        return DropdownMenuItem<String>(
          value: city,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected ? const Color(0xffEEF2FF) : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: isSelected
                      ? const Color(0xff6366F1)
                      : const Color(0xff9CA3AF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    city,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xff111827)
                          : const Color(0xff374151),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Color(0xff6366F1),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => selectedCity = value);
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xff374151),
      ),
    );
  }

  Widget _mainTypeSelector() {
    return Row(
      children: ["Residential", "Commercial"].map((type) {
        final isSelected = mainType == type;
        final isLast = type == "Commercial";
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                mainType = type;

                if (type == "Residential") {
                  subType = "Apartment";
                } else {
                  subType = "Commercial";
                }
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: isLast ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xff2F4253) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xff2F4253)
                      : const Color(0xffE5E7EB),
                ),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.white : const Color(0xff374151),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _subTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subTypes.map((type) {
        final isSelected = subType == type;
        return GestureDetector(
          onTap: () => setState(() => subType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xff2F4253) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xff2F4253)
                    : const Color(0xffE5E7EB),
              ),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xff374151),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _continueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff2F4253),
          disabledBackgroundColor: const Color(0xff2F4253).withOpacity(0.6),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "Continue",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // --- Build -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      appBar: _appBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress card

            // Scrollable form body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- White card ------------------------------------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // City
                          _sectionLabel("Select City"),
                          const SizedBox(height: 10),
                          _cityDropdown(),

                          const SizedBox(height: 24),

                          // Main type
                          _sectionLabel("Property Category"),
                          const SizedBox(height: 10),
                          _mainTypeSelector(),

                          const SizedBox(height: 24),

                          // Sub type
                          if (mainType == "Residential") ...[
                            _sectionLabel("Property Type"),
                            const SizedBox(height: 10),
                            _subTypeSelector(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Continue button
                    _continueButton(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
