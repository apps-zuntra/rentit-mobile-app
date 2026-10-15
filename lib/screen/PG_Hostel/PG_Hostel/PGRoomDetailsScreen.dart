import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PGRoomDetailsScreen extends StatefulWidget {
  const PGRoomDetailsScreen({super.key});

  @override
  State<PGRoomDetailsScreen> createState() => _PGRoomDetailsScreenState();
}

class _PGRoomDetailsScreenState extends State<PGRoomDetailsScreen> {
  final String API_BASE = "https://rentit-backend-yti9.onrender.com";

  List<Map<String, dynamic>> rooms = [];
  bool loading = false;

  final List<String> amenitiesList = [
    "Cupboard",
    "AC",
    "Bedding",
    "TV",
    "Geyser",
    "Attached Bathroom",
  ];

  @override
  void initState() {
    super.initState();
    loadRoomTypes();
  }

  Future<void> loadRoomTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    final res = await http.get(
      Uri.parse("$API_BASE/property/$propertyId"),
      headers: {"Authorization": "Bearer $token"},
    );

    final data = jsonDecode(res.body);
    final types = data["roomType"] ?? [];

    setState(() {
      rooms = types
          .map<Map<String, dynamic>>(
            (t) => {"type": t, "rent": "", "deposit": "", "amenities": []},
          )
          .toList();
    });
  }

  void updateField(int index, String field, String value) {
    setState(() {
      rooms[index][field] = value;
    });
  }

  void toggleAmenity(int index, String item) {
    setState(() {
      if (rooms[index]["amenities"].contains(item)) {
        rooms[index]["amenities"].remove(item);
      } else {
        rooms[index]["amenities"].add(item);
      }
    });
  }

  Future<void> handleNext() async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.getInt("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null) return;

    final payload = {
      "roomType": rooms
          .map(
            (r) => {
              "type": r["type"],
              "rent": r["rent"].toString().isNotEmpty
                  ? int.parse(r["rent"])
                  : null,
              "deposit": r["deposit"].toString().isNotEmpty
                  ? int.parse(r["deposit"])
                  : null,
              "amenities": r["amenities"],
            },
          )
          .toList(),
    };

    try {
      setState(() => loading = true);

      await http.put(
        Uri.parse("$API_BASE/property/$propertyId/amenities"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      Navigator.pushNamed(context, "/pgLocationDetails");
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        title: const Text("Room Details"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: rooms.map((room) {
            int index = rooms.indexOf(room);

            return Container(
              margin: const EdgeInsets.only(bottom: 25),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${room['type']} Room",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Rent
                  const Text("Rent"),
                  TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (v) => updateField(index, "rent", v),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Deposit
                  const Text("Deposit"),
                  TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (v) => updateField(index, "deposit", v),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Amenities
                  const Text("Amenities:"),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: amenitiesList.map((a) {
                      bool active = room["amenities"].contains(a);
                      return GestureDetector(
                        onTap: () => toggleAmenity(index, a),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xff0f766e)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Text(
                            a,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: loading ? null : handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff0f766e),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            loading ? "Saving..." : "Next",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
