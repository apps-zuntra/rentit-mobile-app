

// Terms&Conditions.dart

import 'package:flutter/material.dart';



void main() {

  runApp(const MyApp());

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'Rentit',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),

        useMaterial3: true,

        fontFamily: 'Roboto',

      ),

      home: const TermsAndConditionsScreen(),

    );

  }

}



// ---------------------------------------------

// DATA MODEL

// ---------------------------------------------



class TermsSection {

  final String title;

  final String body;



  const TermsSection({required this.title, required this.body});

}



const List<TermsSection> kTermsSections = [

  TermsSection(

    title: '1. Acceptance of Terms',

    body:

        'By downloading, installing, or using the Rentit mobile application ("App"), you agree to be bound by these Terms & Conditions ("Terms"). If you do not agree to these Terms, please do not use the App. Rentit reserves the right to update these Terms at any time, and continued use of the App constitutes your acceptance of the revised Terms.',

  ),

  TermsSection(

    title: '2. User Eligibility',

    body:

        'You must be at least 18 years of age to use this App. By using Rentit, you represent and warrant that you are of legal age to form a binding contract and are not barred from using our services under applicable law.',

  ),

  TermsSection(

    title: '3. Account Registration',

    body:

        'To access certain features, you must create an account using a valid mobile number or email address. You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. Notify us immediately at support@rentit.in if you suspect unauthorized use.',

  ),

  TermsSection(

    title: '4. Property Listings',

    body:

        'Rentit acts as an information platform connecting property seekers with owners. We do not own, manage, or control any listed properties. All listing details including price, availability, and amenities are provided by property owners. Rentit does not guarantee the accuracy of listing information and recommends users verify details independently before making any decisions.',

  ),

  TermsSection(

    title: '5. Premium Plans & Payments',

    body:

        'Premium plan subscriptions are billed on a monthly or annual basis. All payments are non-refundable unless stated otherwise. You may cancel your subscription at any time; access continues until the end of the current billing period. Rentit reserves the right to modify pricing with 7 days\' advance notice.',

  ),

  TermsSection(

    title: '6. Zero Brokerage Policy',

    body:

        'The "Zero Brokerage" benefit available to Premium users means Rentit will not charge any brokerage fee to tenants for connecting with property owners on our platform. This does not prevent property owners from independently charging any fees outside the Rentit platform.',

  ),

  TermsSection(

    title: '7. Prohibited Conduct',

    body:

        'You agree not to: (a) post false or misleading listings; (b) harass or abuse other users; (c) use the App for any unlawful purpose; (d) attempt to gain unauthorized access to any part of the App; (e) scrape, crawl, or extract data from the App without written permission. Violation of these rules may result in immediate account termination.',

  ),

  TermsSection(

    title: '8. Privacy & Data',

    body:

        'Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. We collect and process data as described in the Privacy Policy. By using the App, you consent to such collection and processing.',

  ),

  TermsSection(

    title: '9. Limitation of Liability',

    body:

        'To the maximum extent permitted by law, Rentit shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App, including but not limited to loss of data, loss of revenue, or property damage resulting from dealings with owners found on our platform.',

  ),

  TermsSection(

    title: '10. Governing Law',

    body:

        'These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising under these Terms shall be subject to the exclusive jurisdiction of courts in Chennai, Tamil Nadu, India.',

  ),

  TermsSection(

    title: '11. Contact Us',

    body:

        'For any questions about these Terms, please contact: Rentit Technologies Pvt. Ltd. Anna Nagar, Chennai – 600040\nEmail: legal@rentit.in\nPhone: +91 44 1234 5678',

  ),

];



// ---------------------------------------------

// MAIN SCREEN

// ---------------------------------------------



class TermsAndConditionsScreen extends StatefulWidget {

  const TermsAndConditionsScreen({super.key});



  @override

  State<TermsAndConditionsScreen> createState() =>

      _TermsAndConditionsScreenState();

}



class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {

  int _currentNavIndex = 3; // Profile tab selected



  // -- colours (match the design) --------------

  static const Color kPrimary = Color(0xFF1A1A2E);

  static const Color kAccent = Color(0xFF2563EB); // blue CTA

  static const Color kBannerBg = Color(0xFF1E2A4A);

  static const Color kCardBg = Colors.white;

  static const Color kScaffoldBg = Color(0xFFF5F6FA);

  static const Color kDivider = Color(0xFFE5E7EB);

  static const Color kBodyText = Color(0xFF374151);

  static const Color kHeadingText = Color(0xFF111827);

  static const Color kSubText = Color(0xFF6B7280);



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: kScaffoldBg,

      // -- App Bar ------------------------------

      appBar: _buildAppBar(),

      // -- Body ---------------------------------

      body: Column(

        children: [

          Expanded(

            child: SingleChildScrollView(

              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  _buildInfoBanner(),

                  const SizedBox(height: 16),

                  ..._buildSections(),

                  const SizedBox(height: 12),

                  _buildFooter(),

                  const SizedBox(height: 16),

                ],

              ),

            ),

          ),

          // -- Bottom CTA ------------------------

          _buildBottomCTA(),

        ],

      ),

      // -- Bottom Navigation ---------------------

      bottomNavigationBar: _buildBottomNav(),

    );

  }



  // -- AppBar ----------------------------------



  PreferredSizeWidget _buildAppBar() {

    return AppBar(

      backgroundColor: kCardBg,

      elevation: 0.5,

      shadowColor: kDivider,

      leading: IconButton(

        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kHeadingText),

        onPressed: () => Navigator.maybePop(context),

      ),

      title: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: const [

          Text(

            'Terms & Conditions',

            style: TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.w600,

              color: kHeadingText,

            ),

          ),

          Text(

            'Last updated 01 January 2026',

            style: TextStyle(fontSize: 11, color: kSubText),

          ),

        ],

      ),

      actions: [

        IconButton(

          icon: const Icon(Icons.insert_drive_file_outlined,

              size: 20, color: kHeadingText),

          onPressed: () {},

        ),

      ],

    );

  }



  // -- Banner ----------------------------------



  Widget _buildInfoBanner() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      decoration: BoxDecoration(

        color: kBannerBg,

        borderRadius: BorderRadius.circular(12),

      ),

      child: const Text(

        'Please read these terms carefully before using Rentit. By using our app, you agree to these terms in full.',

        style: TextStyle(

          color: Colors.white,

          fontSize: 13.5,

          height: 1.55,

        ),

      ),

    );

  }



  // -- Sections --------------------------------



  List<Widget> _buildSections() {

    return kTermsSections

        .map(

          (section) => Padding(

            padding: const EdgeInsets.only(bottom: 12),

            child: _TermsCard(section: section),

          ),

        )

        .toList();

  }



  // -- Footer ----------------------------------



  Widget _buildFooter() {

    return Center(

      child: Padding(

        padding: const EdgeInsets.symmetric(vertical: 8),

        child: Text(

          '© 2026 Rentit Technologies Pvt. Ltd. All rights reserved.',

          textAlign: TextAlign.center,

          style: TextStyle(

            fontSize: 11,

            color: kSubText.withOpacity(0.8),

          ),

        ),

      ),

    );

  }



  // -- Bottom CTA ------------------------------



  Widget _buildBottomCTA() {

    return Container(

      color: kCardBg,

      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),

      child: SizedBox(

        width: double.infinity,

        height: 50,

        child: ElevatedButton(

          onPressed: _onAccept,

          style: ElevatedButton.styleFrom(

            backgroundColor: kPrimary,

            foregroundColor: Colors.white,

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(10),

            ),

            elevation: 0,

          ),

          child: const Text(

            'I Understand & Accept',

            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),

          ),

        ),

      ),

    );

  }



  void _onAccept() {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: const Text('Terms accepted successfully!'),

        backgroundColor: kPrimary,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      ),

    );

  }



  // -- Bottom Navigation ------------------------



  Widget _buildBottomNav() {

    const items = [

      _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),

      _NavItem(icon: Icons.view_list_outlined, label: 'Listings'),

      _NavItem(icon: Icons.chat_bubble_outline, label: 'Enquiries'),

      _NavItem(icon: Icons.person_outline, label: 'Profile'),

    ];



    return Container(

      decoration: const BoxDecoration(

        color: Colors.white,

        border: Border(top: BorderSide(color: kDivider, width: 1)),

      ),

      child: SafeArea(

        child: SizedBox(

          height: 60,

          child: Row(

            children: List.generate(items.length, (i) {

              final selected = i == _currentNavIndex;

              return Expanded(

                child: GestureDetector(

                  behavior: HitTestBehavior.opaque,

                  onTap: () => setState(() => _currentNavIndex = i),

                  child: Column(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      Icon(

                        items[i].icon,

                        size: 22,

                        color: selected ? kAccent : kSubText,

                      ),

                      const SizedBox(height: 3),

                      Text(

                        items[i].label,

                        style: TextStyle(

                          fontSize: 10.5,

                          color: selected ? kAccent : kSubText,

                          fontWeight: selected

                              ? FontWeight.w600

                              : FontWeight.normal,

                        ),

                      ),

                    ],

                  ),

                ),

              );

            }),

          ),

        ),

      ),

    );

  }

}



// ---------------------------------------------

// TERMS CARD WIDGET

// ---------------------------------------------



class _TermsCard extends StatelessWidget {

  final TermsSection section;



  const _TermsCard({required this.section});



  static const Color kHeadingText = Color(0xFF111827);

  static const Color kBodyText = Color(0xFF374151);



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.04),

            blurRadius: 6,

            offset: const Offset(0, 2),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            section.title,

            style: const TextStyle(

              fontSize: 14.5,

              fontWeight: FontWeight.w700,

              color: kHeadingText,

              height: 1.3,

            ),

          ),

          const SizedBox(height: 8),

          Text(

            section.body,

            style: const TextStyle(

              fontSize: 13.5,

              color: kBodyText,

              height: 1.6,

            ),

          ),

        ],

      ),

    );

  }

}



// ---------------------------------------------

// HELPER MODEL

// ---------------------------------------------



class _NavItem {

  final IconData icon;

  final String label;



  const _NavItem({required this.icon, required this.label});

}

