import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'OfficeSpacePhotos.dart';

const String API_BASE = "https://rentit-backend-omega.vercel.app";

class OfficeSpacePricedetails extends StatefulWidget {
  const OfficeSpacePricedetails({super.key});

  @override
  State<OfficeSpacePricedetails> createState() =>
      _OfficeSpacePricedetailsState();
}

class _OfficeSpacePricedetailsState extends State<OfficeSpacePricedetails> {
  bool loading = false;
  bool rentNegotiable = false;

  final TextEditingController rentController = TextEditingController();
  final TextEditingController maintenanceController = TextEditingController();
  final TextEditingController depositController = TextEditingController();

  @override
  void dispose() {
    rentController.dispose();
    maintenanceController.dispose();
    depositController.dispose();
    super.dispose();
  }

  /*
  ===============================
  SAVE PRICE DETAILS
  ===============================
  */

  Future<void> handleNext() async {
    final prefs = await SharedPreferences.getInstance();

    final propertyId = prefs.get("propertyId")?.toString();
    final token = prefs.get("token")?.toString();

    if (propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Property ID missing. Please complete Basic step."),
        ),
      );
      return;
    }

    if (rentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Rent is required")));
      return;
    }

    int? rent = int.tryParse(rentController.text.trim());

    int? maintenance = maintenanceController.text.trim().isEmpty
        ? null
        : int.tryParse(maintenanceController.text.trim());

    int? deposit = depositController.text.trim().isEmpty
        ? null
        : int.tryParse(depositController.text.trim());

    if (rent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid rent value")));
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      Map<String, dynamic> payload = {
        "rent": rent,
        "maintenance": maintenance,
        "deposit": deposit,
        "rentNegotiable": rentNegotiable,
      };

      final res = await http.put(
        Uri.parse("$API_BASE/property/$propertyId/price"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        /// ? NAVIGATION FIX
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OfficeSpacePhotos()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save price details")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Server error")));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  /*
  ===============================
  UI
  ===============================
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Office Space Price Details")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text("Rent *"),

            const SizedBox(height: 5),

            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter Rent",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            const Text("Maintenance"),

            const SizedBox(height: 5),

            TextField(
              controller: maintenanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter Maintenance",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            const Text("Deposit"),

            const SizedBox(height: 5),

            TextField(
              controller: depositController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter Deposit",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Checkbox(
                  value: rentNegotiable,
                  onChanged: (val) {
                    setState(() {
                      rentNegotiable = val ?? false;
                    });
                  },
                ),

                const Text("Rent Negotiable"),
              ],
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,

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
}
