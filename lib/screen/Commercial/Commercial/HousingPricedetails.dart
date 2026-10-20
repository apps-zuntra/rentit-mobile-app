import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "https://rentit-backend-omega.vercel.app";

class HousingPriceDetails extends StatefulWidget {
  const HousingPriceDetails({super.key});

  @override
  State<HousingPriceDetails> createState() => _HousingPriceDetailsState();
}

class _HousingPriceDetailsState extends State<HousingPriceDetails> {
  final rentController = TextEditingController();
  final maintenanceController = TextEditingController();
  final depositController = TextEditingController();

  bool rentNegotiable = false;
  bool loading = false;

  Future<void> savePrice() async {
    final prefs = await SharedPreferences.getInstance();

    final propertyId = prefs.getString("propertyId");
    final token = prefs.getString("token");

    if (propertyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Property ID missing")));

      return;
    }

    try {
      setState(() {
        loading = true;
      });

      final response = await http.put(
        Uri.parse("$baseUrl/property/$propertyId/price"),

        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },

        body: jsonEncode({
          "rent": rentController.text.isNotEmpty
              ? int.parse(rentController.text)
              : null,

          "maintenance": maintenanceController.text.isNotEmpty
              ? int.parse(maintenanceController.text)
              : null,

          "deposit": depositController.text.isNotEmpty
              ? int.parse(depositController.text)
              : null,

          "rentNegotiable": rentNegotiable,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Price details saved successfully")),
        );

        // Navigator.push(
        // context,
        // MaterialPageRoute(
        //   builder: (context) =>
        //       HousingPhotos(propertyId: int.parse(propertyId)),
        // ),
        // );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save property details")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Server Error")));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Widget inputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(label),

        const SizedBox(height: 6),

        TextField(
          controller: controller,

          keyboardType: TextInputType.number,

          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7f9),

      appBar: AppBar(title: const Text("Post Property - Price Details")),

      body: Center(
        child: Container(
          width: 500,

          padding: const EdgeInsets.all(30),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(12),

            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              inputField("Rent", rentController),

              inputField("Maintenance", maintenanceController),

              inputField("Deposit", depositController),

              Row(
                children: [
                  Checkbox(
                    value: rentNegotiable,

                    onChanged: (v) {
                      setState(() {
                        rentNegotiable = v!;
                      });
                    },
                  ),

                  const Text("Rent Negotiable"),
                ],
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    "Save as Draft",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  ElevatedButton(
                    onPressed: loading ? null : savePrice,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0f766e),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                    ),

                    child: Text(loading ? "Saving..." : "Next Step"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
