import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'OfficeSpacePricedetails.dart';

const String API_BASE = "https://rentit-backend-omega.vercel.app";

class OfficeSpaceAmenities extends StatefulWidget {
  const OfficeSpaceAmenities({super.key});

  @override
  State<OfficeSpaceAmenities> createState() => _OfficeSpaceAmenitiesState();
}

class _OfficeSpaceAmenitiesState extends State<OfficeSpaceAmenities> {
  bool loading = false;

  bool? petAllowed;
  bool? nonVegAllowed;
  bool? gatedCommunity;

  final TextEditingController noOfFloors = TextEditingController();
  final TextEditingController noOfBalcony = TextEditingController();

  Map<String, int> parking = {"car": 0, "bike": 0};

  Map<String, int> furnishing = {
    "Bed": 0,
    "Fan": 0,
    "Wardrobe": 0,
    "Chimney": 0,
  };

  Set<String> selectedAmenities = {};

  /*
  ==========================
  PARKING
  ==========================
  */

  void updateParking(String type, int delta) {
    setState(() {
      parking[type] = (parking[type]! + delta).clamp(0, 100);
    });
  }

  /*
  ==========================
  FURNISHING
  ==========================
  */

  void updateFurnishing(String item, int delta) {
    setState(() {
      furnishing[item] = (furnishing[item]! + delta).clamp(0, 100);
    });
  }

  /*
  ==========================
  AMENITIES
  ==========================
  */

  void toggleAmenity(String item) {
    setState(() {
      if (selectedAmenities.contains(item)) {
        selectedAmenities.remove(item);
      } else {
        selectedAmenities.add(item);
      }
    });
  }

  /*
  ==========================
  API SUBMIT
  ==========================
  */

  Future handleNext() async {
    final prefs = await SharedPreferences.getInstance();

    int? propertyId = prefs.getInt("propertyId");
    String? token = prefs.getString("token");

    if (propertyId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login or property missing")),
      );

      return;
    }

    try {
      setState(() {
        loading = true;
      });

      Map<String, bool> societyAmenities = {
        for (var item in selectedAmenities) item: true,
      };

      final body = {
        "parking": parking,
        "furnishing": furnishing,
        "societyAmenities": societyAmenities,

        "petAllowed": petAllowed ?? false,
        "nonVegAllowed": nonVegAllowed ?? false,
        "gatedCommunity": gatedCommunity ?? false,

        "noOfFloors": noOfFloors.text,
        "noOfBalcony": noOfBalcony.text,
      };

      final res = await http.put(
        Uri.parse("$API_BASE/property/$propertyId/amenities"),

        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },

        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Amenities saved")));

        /// ? Navigate to Price Details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OfficeSpacePricedetails(),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Server error: ${res.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to save amenities")));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  /*
  ==========================
  COUNTER WIDGET
  ==========================
  */

  Widget counter(String title, int value, Function(int) onChange) {
    return Row(
      children: [
        Expanded(child: Text(title)),

        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () => onChange(-1),
        ),

        Text(value.toString()),

        IconButton(icon: const Icon(Icons.add), onPressed: () => onChange(1)),
      ],
    );
  }

  /*
  ==========================
  UI
  ==========================
  */

  @override
  Widget build(BuildContext context) {
    List<String> amenitiesList = [
      "Water Supply",
      "Power Backup",
      "Gym",
      "Play Ground",
      "Swimming Pool",
      "Lift",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Amenities")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text("Parking", style: TextStyle(fontSize: 18)),

            counter("Car", parking["car"]!, (d) => updateParking("car", d)),
            counter("Bike", parking["bike"]!, (d) => updateParking("bike", d)),

            const SizedBox(height: 20),

            const Text("Pet Allowed"),

            Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => petAllowed = true),
                  child: const Text("Yes"),
                ),

                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: () => setState(() => petAllowed = false),
                  child: const Text("No"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text("Non Veg Allowed"),

            Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => nonVegAllowed = true),
                  child: const Text("Yes"),
                ),

                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: () => setState(() => nonVegAllowed = false),
                  child: const Text("No"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text("Gated Community"),

            Row(
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => gatedCommunity = true),
                  child: const Text("Yes"),
                ),

                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: () => setState(() => gatedCommunity = false),
                  child: const Text("No"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            TextField(
              controller: noOfFloors,
              decoration: const InputDecoration(
                labelText: "No of Floors",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 10),

            TextField(
              controller: noOfBalcony,
              decoration: const InputDecoration(
                labelText: "No of Balcony",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),

            const Text("Furnishing", style: TextStyle(fontSize: 18)),

            ...furnishing.keys.map((item) {
              return counter(
                item,
                furnishing[item]!,
                (d) => updateFurnishing(item, d),
              );
            }),

            const SizedBox(height: 20),

            const Text("Society Amenities"),

            Wrap(
              spacing: 10,
              runSpacing: 10,

              children: amenitiesList.map((item) {
                bool selected = selectedAmenities.contains(item);

                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected ? Colors.green : Colors.grey,
                  ),

                  onPressed: () => toggleAmenity(item),

                  child: Text(item),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            Center(
              child: ElevatedButton(
                onPressed: loading ? null : handleNext,

                child: Text(loading ? "Saving..." : "Next Step"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    noOfFloors.dispose();
    noOfBalcony.dispose();
    super.dispose();
  }
}
