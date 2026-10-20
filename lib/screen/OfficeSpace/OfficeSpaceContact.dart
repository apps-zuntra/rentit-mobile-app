import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'OfficeSpaceVerify.dart';

const String baseUrl = "https://rentit-backend-omega.vercel.app";

class OfficeSpaceContact extends StatefulWidget {
  const OfficeSpaceContact({super.key});

  @override
  State<OfficeSpaceContact> createState() => _OfficeSpaceContactState();
}

class _OfficeSpaceContactState extends State<OfficeSpaceContact> {
  final TextEditingController contactNameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();

  String repliesWithin = "";
  bool whatsapp = false;
  bool loading = false;

  /*
  ==========================
  VERIFY & SAVE CONTACT
  ==========================
  */

  Future<void> handleVerify() async {
    final prefs = await SharedPreferences.getInstance();

    final dynamic propertyRaw = prefs.get("propertyId");
    final String? propertyId = propertyRaw?.toString();

    final dynamic tokenRaw = prefs.get("token");
    final String? token = tokenRaw?.toString();

    if (propertyId == null || propertyId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Property ID missing")));

      return;
    }

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));

      return;
    }

    String contactName = contactNameController.text.trim();
    String mobileNo = mobileController.text.trim();

    if (contactName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Contact Name is required")));

      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileNo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10 digit mobile number")),
      );

      return;
    }

    try {
      setState(() {
        loading = true;
      });

      final response = await http.put(
        Uri.parse("$baseUrl/property/$propertyId/contact"),

        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },

        body: jsonEncode({
          "contactName": contactName,

          "mobileNo": mobileNo,

          "repliesWithin": repliesWithin.isEmpty ? "" : repliesWithin,

          "whatsapp": whatsapp,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OfficeSpaceVerify()),
        );
      } else {
        final data = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Failed to save contact")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  /*
  ==========================
  UI
  ==========================
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Contact Details")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text("Contact Name *"),

            const SizedBox(height: 5),

            TextField(
              controller: contactNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your name",
              ),
            ),

            const SizedBox(height: 20),

            const Text("Mobile No *"),

            const SizedBox(height: 5),

            TextField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your number",
                counterText: "",
              ),
            ),

            const SizedBox(height: 20),

            const Text("Replies within"),

            const SizedBox(height: 5),

            DropdownButtonFormField<String>(
              value: repliesWithin.isEmpty ? null : repliesWithin,

              items: const [
                DropdownMenuItem(
                  value: "Within 1 hour",
                  child: Text("Within 1 hour"),
                ),

                DropdownMenuItem(
                  value: "Within 3 hours",
                  child: Text("Within 3 hours"),
                ),

                DropdownMenuItem(
                  value: "Within 24 hours",
                  child: Text("Within 24 hours"),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  repliesWithin = value ?? "";
                });
              },

              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Select",
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Checkbox(
                  value: whatsapp,
                  onChanged: (val) {
                    setState(() {
                      whatsapp = val ?? false;
                    });
                  },
                ),

                const Text("Get Updates on WhatsApp"),
              ],
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,

              child: ElevatedButton(
                onPressed: loading ? null : handleVerify,

                child: Text(loading ? "Saving..." : "Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
  ==========================
  DISPOSE
  ==========================
  */

  @override
  void dispose() {
    contactNameController.dispose();
    mobileController.dispose();

    super.dispose();
  }
}
