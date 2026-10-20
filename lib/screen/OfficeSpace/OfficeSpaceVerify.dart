import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rentit/main/DashboardScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfficeSpaceVerify extends StatelessWidget {
  const OfficeSpaceVerify({super.key});

  /*
  ==========================
  GO TO DASHBOARD
  ==========================
  */

  void goToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
    );
  }

  /*
  ==========================
  COPY PROPERTY LINK
  ==========================
  */

  Future<void> copyLink(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.get("propertyId")?.toString();

    if (propertyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Property ID not found")));

      return;
    }

    String link =
        "https://rentit-backend-omega.vercel.app/property/$propertyId";

    await Clipboard.setData(ClipboardData(text: link));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Property link copied")));
  }

  /*
  ==========================
  SHARE PROPERTY LINK
  ==========================
  */

  Future<void> shareLink(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final propertyId = prefs.get("propertyId")?.toString();

    if (propertyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Property ID missing")));

      return;
    }

    String link =
        "https://rentit-backend-omega.vercel.app/property/$propertyId";

    await Clipboard.setData(ClipboardData(text: link));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Link copied. Share it anywhere.")),
    );
  }

  /*
  ==========================
  UI
  ==========================
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7f9),

      appBar: AppBar(
        title: const Text("Post Property"),

        backgroundColor: const Color(0xff0f766e),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            children: [
              const SizedBox(height: 40),

              /*
              ======================
              ILLUSTRATION
              ======================
              */
              Container(
                height: 250,

                width: double.infinity,

                decoration: BoxDecoration(
                  color: Colors.grey[300],

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Center(
                  child: Icon(Icons.verified, size: 80, color: Colors.green),
                ),
              ),

              const SizedBox(height: 40),

              /*
              ======================
              TITLE
              ======================
              */
              const Text(
                "Ready to verify your property?",

                textAlign: TextAlign.center,

                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              /*
              ======================
              DESCRIPTION
              ======================
              */
              const Text(
                "Increase trust and get up to 3x more views by completing our simple verification process.",

                textAlign: TextAlign.center,

                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 25),

              /*
              ======================
              BADGE
              ======================
              */
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,

                  vertical: 8,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xffd1fae5),

                  borderRadius: BorderRadius.circular(20),
                ),

                child: const Text(
                  "Takes less than 5 minutes",

                  style: TextStyle(color: Color(0xff065f46)),
                ),
              ),

              const SizedBox(height: 30),

              /*
              ======================
              START VERIFY BUTTON
              ======================
              */
              SizedBox(
                width: double.infinity,

                height: 50,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0f766e),
                  ),

                  onPressed: () {
                    goToDashboard(context);
                  },

                  child: const Text(
                    "Start Verification ?",

                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /*
              ======================
              SHARE BUTTON
              ======================
              */
              SizedBox(
                width: double.infinity,

                height: 50,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffe0f2f1),
                  ),

                  onPressed: () {
                    shareLink(context);
                  },

                  child: const Text(
                    "Share link with someone else",

                    style: TextStyle(color: Color(0xff065f46)),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /*
              ======================
              COPY LINK BUTTON
              ======================
              */
              SizedBox(
                width: double.infinity,

                height: 50,

                child: OutlinedButton(
                  onPressed: () {
                    copyLink(context);
                  },

                  child: const Text("Copy Property Link"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
