import 'package:flutter/material.dart';



class VerificationSuccessScreen extends StatelessWidget {

  const VerificationSuccessScreen({super.key});



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xffF3F4F6),



      body: Column(

        children: [



          /// HEADER

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

            child: Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [



                Row(

                  children: [

                    IconButton(

                      icon: const Icon(Icons.arrow_back),

                      onPressed: () => Navigator.pop(context),

                    ),

                    const SizedBox(width: 5),

                    const Text(

                      "Post property",

                      style: TextStyle(

                        fontWeight: FontWeight.w600,

                        fontSize: 16,

                      ),

                    ),

                  ],

                ),



                GestureDetector(

                  onTap: () {

                    Navigator.pushNamed(context, "/account");

                  },

                  child: Container(

                    width: 38,

                    height: 38,

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

                )

              ],

            ),

          ),



          /// CENTER CONTENT

          Expanded(

            child: Column(

              mainAxisAlignment: MainAxisAlignment.center,

              children: [



                /// BIG CHECK ICON

                const Icon(

                  Icons.check_circle,

                  color: Color(0xFF0F766E),

                  size: 120,

                ),



                const SizedBox(height: 30),



                /// TITLE

                const Text(

                  "Your listing is verified!",

                  style: TextStyle(

                    fontSize: 28,

                    fontWeight: FontWeight.bold,

                    color: Color(0xff111827),

                  ),

                ),



                const SizedBox(height: 10),



                /// SUBTITLE

                const Padding(

                  padding: EdgeInsets.symmetric(horizontal: 30),

                  child: Text(

                    "Your property now shows a verified badge, helping it get more views and faster responses.",

                    textAlign: TextAlign.center,

                    style: TextStyle(

                      color: Color(0xff6B7280),

                      fontSize: 15,

                      height: 1.6,

                    ),

                  ),

                ),



                const SizedBox(height: 40),



                /// BUTTONS

                Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 30),

                  child: Column(

                    children: [



                      /// VIEW LISTING

                      SizedBox(

                        width: double.infinity,

                        height: 50,

                        child: ElevatedButton(

                          onPressed: () {

                            Navigator.pushNamed(context, "/listings");

                          },

                          style: ElevatedButton.styleFrom(

                            backgroundColor: const Color(0xFF0F766E),

                            shape: RoundedRectangleBorder(

                              borderRadius: BorderRadius.circular(8),

                            ),

                          ),

                          child: const Text(

                            "View my listing",

                            style: TextStyle(fontWeight: FontWeight.w600),

                          ),

                        ),

                      ),



                      const SizedBox(height: 15),



                      /// DASHBOARD BUTTON

                      SizedBox(

                        width: double.infinity,

                        height: 50,

                        child: ElevatedButton(

                          onPressed: () {

                            Navigator.pushNamed(context, "/userDashboard");

                          },

                          style: ElevatedButton.styleFrom(

                            backgroundColor: const Color(0xFFA7D3CC),

                            foregroundColor: const Color(0xFF064E3B),

                            shape: RoundedRectangleBorder(

                              borderRadius: BorderRadius.circular(8),

                            ),

                          ),

                          child: const Text(

                            "Go Back to Dashboard",

                            style: TextStyle(fontWeight: FontWeight.w600),

                          ),

                        ),

                      ),

                    ],

                  ),

                ),



                const SizedBox(height: 40),



                /// TERMS TEXT

                const Text(

                  "By starting, you agree to our verification terms and privacy policy.",

                  style: TextStyle(

                    fontSize: 12,

                    color: Color(0xff9CA3AF),

                  ),

                  textAlign: TextAlign.center,

                ),

              ],

            ),

          ),



          /// FOOTER

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

            child: Column(

              children: [



                const Text(

                  "© 2024 Real Estate Management Pro. All rights reserved.",

                  style: TextStyle(

                    fontSize: 13,

                    color: Color(0xff9CA3AF),

                  ),

                ),



                const SizedBox(height: 10),



                Row(

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: const [

                    Text("Privacy",

                        style: TextStyle(color: Color(0xff9CA3AF))),

                    SizedBox(width: 20),

                    Text("Terms",

                        style: TextStyle(color: Color(0xff9CA3AF))),

                    SizedBox(width: 20),

                    Text("Help Center",

                        style: TextStyle(color: Color(0xff9CA3AF))),

                  ],

                )

              ],

            ),

          ),

        ],

      ),

    );

  }

}

