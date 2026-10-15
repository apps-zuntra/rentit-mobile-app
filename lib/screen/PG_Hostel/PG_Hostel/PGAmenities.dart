import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "https://rentit-backend-yti9.onrender.com";
const Color TEAL = Color(0xFF0D9B8A);

class PGAmenities extends StatefulWidget {
  const PGAmenities({super.key});

  @override
  State<PGAmenities> createState() => _PGAmenitiesState();
}

class _PGAmenitiesState extends State<PGAmenities> {
  bool loading = false;

  String? parking;
  String? food;

  final rulesController = TextEditingController();
  final floorsController = TextEditingController();
  final balconyController = TextEditingController();

  Map<String, bool> restrictions = {
    "smoking": false,
    "alcohol": false,
    "loudMusic": false,
  };

  Map<String, int> furnishing = {"bed": 0, "fan": 0, "wardrobe": 0};

  Map<String, bool> selectedAmenities = {};

  bool petAllowed = false;
  bool nonVegAllowed = false;
  bool gatedCommunity = false;
  bool gateSecurity = false;

  // --------------------------
  // Toggle amenity
  // --------------------------

  void toggleAmenity(String id) {
    setState(() {
      selectedAmenities[id] = !(selectedAmenities[id] ?? false);
    });
  }

  // --------------------------
  // Furnishing counter
  // --------------------------

  void updateFurnishing(String key, int delta) {
    setState(() {
      int current = furnishing[key] ?? 0;

      current += delta;

      if (current < 0) current = 0;

      furnishing[key] = current;
    });
  }

  // --------------------------
  // SnackBar
  // --------------------------

  void showSnack(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : TEAL),
    );
  }

  // --------------------------
  // Submit API
  // --------------------------

  Future<void> handleSubmit() async {
    if (parking == null) {
      showSnack("Select parking option");
      return;
    }

    if (food == null) {
      showSnack("Select food option");
      return;
    }

    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final dynamic propertyRaw = prefs.get("propertyId");
      final String? propertyId = propertyRaw?.toString();

      final dynamic tokenRaw = prefs.get("token");
      final String? token = tokenRaw?.toString();

      print("PROPERTY ID : $propertyId");
      print("TOKEN : $token");

      if (propertyId == null || propertyId.isEmpty) {
        showSnack("Property ID missing");
        return;
      }

      if (token == null || token.isEmpty) {
        showSnack("User not logged in");
        return;
      }

      final payload = {
        "parking": {"available": parking == "yes"},

        "restrictions": restrictions,

        "rules": rulesController.text.trim(),

        "furnishing": furnishing,

        "societyAmenities": selectedAmenities,

        "foodIncluded": food == "yes",

        "petAllowed": petAllowed,

        "nonVegAllowed": nonVegAllowed,

        "gatedCommunity": gatedCommunity,

        "gateSecurity": gateSecurity,

        "noOfFloors": int.tryParse(floorsController.text),

        "noOfBalcony": int.tryParse(balconyController.text),
      };

      final url = "$baseUrl/property/$propertyId/amenities";

      final res = await http.put(
        Uri.parse(url),

        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },

        body: jsonEncode(payload),
      );

      print("STATUS : ${res.statusCode}");
      print("BODY : ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Navigator.push(
        //   // context,
        //   // MaterialPageRoute(builder: (_) => PGPhotos()),
        // );
      } else {
        showSnack("Server error: ${res.body}");
      }
    } catch (e) {
      showSnack("Something went wrong: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    rulesController.dispose();
    floorsController.dispose();
    balconyController.dispose();

    super.dispose();
  }

  // --------------------------
  // UI
  // --------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Amenities"), backgroundColor: TEAL),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Parking",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Row(
              children: [
                Radio(
                  value: "yes",
                  groupValue: parking,
                  onChanged: (v) {
                    setState(() {
                      parking = v;
                    });
                  },
                ),

                const Text("Yes"),

                Radio(
                  value: "no",
                  groupValue: parking,
                  onChanged: (v) {
                    setState(() {
                      parking = v;
                    });
                  },
                ),

                const Text("No"),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Food Included",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Row(
              children: [
                Radio(
                  value: "yes",
                  groupValue: food,
                  onChanged: (v) {
                    setState(() {
                      food = v;
                    });
                  },
                ),

                const Text("Yes"),

                Radio(
                  value: "no",
                  groupValue: food,
                  onChanged: (v) {
                    setState(() {
                      food = v;
                    });
                  },
                ),

                const Text("No"),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Restrictions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            ...restrictions.keys.map((key) {
              return CheckboxListTile(
                title: Text(key),

                value: restrictions[key],

                onChanged: (v) {
                  setState(() {
                    restrictions[key] = v!;
                  });
                },
              );
            }),

            const SizedBox(height: 20),

            const Text(
              "Rules",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            TextField(
              controller: rulesController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 20),

            const Text(
              "Furnishing",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            ...furnishing.keys.map((key) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(key),

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          updateFurnishing(key, -1);
                        },
                      ),

                      Text("${furnishing[key]}"),

                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          updateFurnishing(key, 1);
                        },
                      ),
                    ],
                  ),
                ],
              );
            }),

            const SizedBox(height: 20),

            const Text(
              "Society Amenities",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            ...[
              "Water Supply",
              "Power Backup",
              "Gym",
              "Playground",
              "Swimming Pool",
            ].map((item) {
              final id = item.replaceAll(" ", "").toLowerCase();

              return CheckboxListTile(
                title: Text(item),

                value: selectedAmenities[id] ?? false,

                onChanged: (v) {
                  toggleAmenity(id);
                },
              );
            }),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TEAL,
                  padding: const EdgeInsets.all(15),
                ),

                onPressed: loading ? null : handleSubmit,

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Next Step"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
