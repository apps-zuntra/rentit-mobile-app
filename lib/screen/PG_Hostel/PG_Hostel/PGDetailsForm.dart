import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PGDetailsFormScreen extends StatefulWidget {
  const PGDetailsFormScreen({super.key});

  @override
  State<PGDetailsFormScreen> createState() => _PGDetailsFormScreenState();
}

class _PGDetailsFormScreenState extends State<PGDetailsFormScreen> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  bool loading = false;

  // FORM FIELDS
  String laundry = "";
  String cleaning = "";
  String warden = "";

  Map<String, bool> amenities = {
    "wifi": false,
    "tv": false,
    "lift": false,
    "powerBackup": false,
    "mess": false,
    "fridge": false,
    "cooking": false,
  };

  String parking = "";
  String directions = "";

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> handleSubmit() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null) {
      showSnack("Property ID missing");
      return;
    }

    final payload = {
      "laundry": laundry == "Yes",
      "roomCleaning": cleaning == "Yes",
      "warden": warden == "Yes",

      "roomAmenities": {
        "wifi": amenities["wifi"],
        "tv": amenities["tv"],
        "lift": amenities["lift"],
        "powerBackup": amenities["powerBackup"],
        "mess": amenities["mess"],
        "refrigerator": amenities["fridge"],
        "cookingAllowed": amenities["cooking"],
      },

      "parking": parking.isNotEmpty ? [parking] : [],
      "setDirection": directions,
    };

    try {
      setState(() => loading = true);

      final response = await http.put(
        Uri.parse("$API_BASE/property/$propertyId/amenities"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        showSnack("Saved successfully");

        // ? Navigate to PG Photos Screen
        if (mounted) {
          Navigator.pushNamed(context, "/pgPhotos");
        }
      } else {
        showSnack("Error saving data");
      }
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PG / Hostel Amenities"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION TITLE
            const Text(
              "Provide additional details about your place",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // SERVICES
            const Text(
              "Available Services",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            serviceBlock("Laundry", "laundry"),
            serviceBlock("Room Cleaning", "cleaning"),
            serviceBlock("Warden Facility", "warden"),

            const SizedBox(height: 20),

            // AMENITIES
            const Text(
              "Amenities",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: amenities.keys.map((key) {
                return FilterChip(
                  label: Text(key.toUpperCase()),
                  selected: amenities[key]!,
                  onSelected: (val) {
                    setState(() {
                      amenities[key] = val;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // PARKING
            const Text(
              "Parking",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField(
              value: parking.isEmpty ? null : parking,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "None", child: Text("None")),
                DropdownMenuItem(value: "Car", child: Text("Car")),
                DropdownMenuItem(value: "Bike", child: Text("Bike")),
                DropdownMenuItem(
                  value: "Car & Bike",
                  child: Text("Car & Bike"),
                ),
              ],
              onChanged: (val) {
                setState(() => parking = val ?? "");
              },
            ),

            const SizedBox(height: 20),

            // DIRECTIONS
            const Text(
              "Add Directions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Near XYZ temple...",
              ),
              onChanged: (val) => directions = val,
            ),

            const SizedBox(height: 30),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0f766e),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  loading ? "Saving..." : "Save & Continue",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SERVICE RADIO UI
  Widget serviceBlock(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Radio<String>(
              value: "Yes",
              groupValue: key == "laundry"
                  ? laundry
                  : key == "cleaning"
                  ? cleaning
                  : warden,
              onChanged: (val) {
                setState(() {
                  if (key == "laundry") laundry = val!;
                  if (key == "cleaning") cleaning = val!;
                  if (key == "warden") warden = val!;
                });
              },
            ),
            const Text("Yes"),
            Radio<String>(
              value: "No",
              groupValue: key == "laundry"
                  ? laundry
                  : key == "cleaning"
                  ? cleaning
                  : warden,
              onChanged: (val) {
                setState(() {
                  if (key == "laundry") laundry = val!;
                  if (key == "cleaning") cleaning = val!;
                  if (key == "warden") warden = val!;
                });
              },
            ),
            const Text("No"),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
