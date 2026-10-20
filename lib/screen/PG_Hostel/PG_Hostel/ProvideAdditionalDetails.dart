import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PGAdditionalDetails extends StatefulWidget {
  const PGAdditionalDetails({super.key});

  @override
  State<PGAdditionalDetails> createState() => _PGAdditionalDetailsState();
}

class _PGAdditionalDetailsState extends State<PGAdditionalDetails> {
  final String API_BASE = "https://rentit-backend-omega.vercel.app";

  String laundry = "";
  String cleaning = "";
  String warden = "";
  String parking = "";
  String directions = "";

  Map<String, bool> amenities = {
    "wifi": false,
    "tv": false,
    "lift": false,
    "powerBackup": false,
    "mess": false,
    "fridge": false,
    "cooking": false,
  };

  bool loading = false;

  Future<void> handleSubmit() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId")?.toString();
    final token = prefs.getString("token");

    if (propertyId == null) return;

    setState(() => loading = true);

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

    final res = await http.put(
      Uri.parse("$API_BASE/property/$propertyId/amenities"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    setState(() => loading = false);

    if (res.statusCode == 200) {
      Navigator.pushNamed(context, "/pgPhotos");
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Provide Additional Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _title("Available Services"),

            _radioBlock("Laundry", laundry, (v) => setState(() => laundry = v)),
            _radioBlock(
              "Room Cleaning",
              cleaning,
              (v) => setState(() => cleaning = v),
            ),
            _radioBlock("Warden", warden, (v) => setState(() => warden = v)),

            _title("Amenities"),
            ...amenities.keys.map(
              (k) => CheckboxListTile(
                title: Text(k),
                value: amenities[k],
                onChanged: (v) => setState(() => amenities[k] = v ?? false),
              ),
            ),

            _title("Parking"),
            DropdownButtonFormField(
              value: parking.isNotEmpty ? parking : null,
              items: [
                "None",
                "Car",
                "Bike",
                "Car & Bike",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => parking = v!),
            ),

            _title("Directions"),
            TextField(
              maxLines: 3,
              onChanged: (v) => directions = v,
              decoration: const InputDecoration(
                hintText: "Eg: Near XYZ temple...",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : handleSubmit,
              child: Text(loading ? "Saving..." : "Save & Continue"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text),
  );

  Widget _radioBlock(String label, String group, Function(String) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            Expanded(
              child: RadioListTile(
                title: const Text("Yes"),
                value: "Yes",
                groupValue: group,
                onChanged: (v) => onChange(v!),
              ),
            ),
            Expanded(
              child: RadioListTile(
                title: const Text("No"),
                value: "No",
                groupValue: group,
                onChanged: (v) => onChange(v!),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
