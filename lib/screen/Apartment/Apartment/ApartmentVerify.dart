import 'package:flutter/material.dart';

class PostPropertyVerifyScreen extends StatelessWidget {
  const PostPropertyVerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),

      body: Column(
        children: [
          /// MAIN CONTENT
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                child: Column(
                  children: [
                    /// HEADER
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),

                        const Text(
                          "Post property",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        /// AVATAR
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F766E),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "JD",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 60),

                    /// ILLUSTRATION PLACEHOLDER
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xffE5E7EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "Illustration Here",
                        style: TextStyle(
                          color: Color(0xff6B7280),
                          fontSize: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    /// TITLE
                    const Text(
                      "Ready to verify your property?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// DESCRIPTION
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "Increase trust and get up to 3x more views by completing our simple verification process. It's fast, secure, and helps protect our community.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff6B7280),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    /// TIME BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Takes less than 5 minutes",
                        style: TextStyle(
                          color: Color(0xff065F46),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// START VERIFICATION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          
                          Navigator.pushNamed(context, "/apartmentVerified");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Start Verification ?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// SHARE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffE0F2F1),
                          foregroundColor: const Color(0xff065F46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "?? Share link with someone else",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// TERMS TEXT
                    const Text(
                      "By starting, you agree to our verification terms and privacy policy.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xff9CA3AF)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// FOOTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xffE5E7EB))),
            ),
            child: Column(
              children: [
                const Text(
                  "© 2024 Real Estate Management Pro. All rights reserved.",
                  style: TextStyle(fontSize: 14, color: Color(0xff6B7280)),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text("Privacy"),
                    SizedBox(width: 20),
                    Text("Terms"),
                    SizedBox(width: 20),
                    Text("Help Center"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
