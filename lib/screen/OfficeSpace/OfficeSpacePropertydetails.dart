import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class OfficeSpacePropertydetails extends StatefulWidget {
  const OfficeSpacePropertydetails({super.key});

  @override
  State<OfficeSpacePropertydetails> createState() =>
      _OfficeSpacePropertydetailsState();
}

class _OfficeSpacePropertydetailsState
    extends State<OfficeSpacePropertydetails> {
  final String baseUrl = "https://rentit-backend-omega.vercel.app";

  final dio = Dio();

  String? token = "YOUR_TOKEN_HERE";
  String? propertyId = "YOUR_PROPERTY_ID";

  Map<String, dynamic> form = {
    "propertyType2": "",
    "buildingType": "",
    "propertyAge": "",
    "floor": "",
    "totalFloor": "",
    "builtUpArea": "",
    "furnishing": "",
  };

  List<String> features = [];

  void handleChange(String key, String value) {
    setState(() {
      form[key] = value;
    });
  }

  void toggleFeature(String feature) {
    setState(() {
      if (features.contains(feature)) {
        features.remove(feature);
      } else {
        features.add(feature);
      }
    });
  }

  Future<void> handleSubmit() async {
    try {
      final payload = {
        "propertyType2": form["propertyType2"] != ""
            ? form["propertyType2"]
            : null,

        "buildingType": form["buildingType"] != ""
            ? form["buildingType"]
            : null,

        "propertyAge": form["propertyAge"] != "" ? form["propertyAge"] : null,

        "floor": form["floor"] != "" ? int.parse(form["floor"]) : null,

        "totalFloor": form["totalFloor"] != ""
            ? int.parse(form["totalFloor"])
            : null,

        "builtUpArea": form["builtUpArea"] != ""
            ? int.parse(form["builtUpArea"])
            : null,

        "furnishing": form["furnishing"] != ""
            ? {"type": form["furnishing"]}
            : null,

        "otherFeatures": {"features": features.isNotEmpty ? features : []},
      };

      print("PAYLOAD: $payload");

      final response = await dio.put(
        "$baseUrl/property/$propertyId/details",
        data: payload,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved successfully macha ??")),
      );
    } catch (e) {
      print("ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error saving details")));
    }
  }

  Widget buildDropdown(String label, String key, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButton<String>(
          isExpanded: true,
          value: form[key] == "" ? null : form[key],
          hint: const Text("Select"),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: (value) {
            handleChange(key, value!);
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget buildInput(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => handleChange(key, value),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget buildFeatureButton(String text) {
    final isActive = features.contains(text);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey,
      ),
      onPressed: () => toggleFeature(text),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Property Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildDropdown("Property Type2", "propertyType2", [
              "Showroom",
              "Office",
              "Shop",
            ]),

            buildDropdown("Building Type", "buildingType", [
              "Residential",
              "Commercial",
            ]),

            buildDropdown("Property Age", "propertyAge", [
              "0-1 years",
              "1-5 years",
              "5+ years",
            ]),

            buildInput("Floor", "floor"),
            buildInput("Total Floor", "totalFloor"),
            buildInput("Built Up Area", "builtUpArea"),

            buildDropdown("Furnishing", "furnishing", [
              "Fully Furnished",
              "Semi Furnished",
              "Unfurnished",
            ]),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Other Features"),
            ),

            Wrap(
              spacing: 10,
              children: [
                buildFeatureButton("On Main Road"),
                buildFeatureButton("Corner Property"),
              ],
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: handleSubmit,
              child: const Text("Save & Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
