import 'package:flutter/material.dart';



// ----------------------------------------------------------------------

// 1. MODEL

// ----------------------------------------------------------------------



class KnowledgeArticle {

  final IconData icon;

  final Color iconBg;

  final String title;

  final String subtitle;

  final List<KnowledgeSection> sections;



  const KnowledgeArticle({

    required this.icon,

    required this.iconBg,

    required this.title,

    required this.subtitle,

    required this.sections,

  });

}



class KnowledgeSection {

  final String heading;

  final String body;



  const KnowledgeSection({required this.heading, required this.body});

}



// ----------------------------------------------------------------------

// 2. CONTENT DATA (edit/expand freely)

// ----------------------------------------------------------------------



class KnowledgeData {

  static const occupancyCertificate = KnowledgeArticle(

    icon: Icons.info_outline,

    iconBg: Color(0xFFEEF0FF),

    title: "Occupancy Certificate (OC)",

    subtitle: "Meaning, Importance & Process",

    sections: [

      KnowledgeSection(

        heading: "What is an Occupancy Certificate?",

        body:

            "An Occupancy Certificate (OC) is a legal document issued by the "

            "local municipal authority confirming that a building has been "

            "constructed according to the approved plan and sanctioned "

            "building bye-laws, and that it is fit for people to live in.",

      ),

      KnowledgeSection(

        heading: "Why it matters",

        body:

            "Without an OC, a property is technically not authorized for "

            "occupation. Many banks refuse to sanction home loans, utility "

            "connections (water, electricity, sewage) may be denied, and "

            "resale or transfer of the property can run into legal trouble.",

      ),

      KnowledgeSection(

        heading: "Who issues it",

        body:

            "The OC is issued by the local development authority, municipal "

            "corporation, or panchayat, depending on the jurisdiction where "

            "the property is located.",

      ),

      KnowledgeSection(

        heading: "Documents typically required",

        body:

            "• Sanctioned building plan\n"

            "• Commencement certificate\n"

            "• Completion certificate from a licensed architect/engineer\n"

            "• NOC from fire department (for larger buildings)\n"

            "• Structural stability certificate\n"

            "• Property tax receipts",

      ),

      KnowledgeSection(

        heading: "Process to obtain",

        body:

            "1. Builder/owner applies to the local authority after "

            "construction completion.\n"

            "2. Authority conducts a site inspection to verify compliance "

            "with the approved plan.\n"

            "3. If compliant, the OC is issued, usually within a few weeks "

            "to a couple of months depending on the city.",

      ),

      KnowledgeSection(

        heading: "Buyer's checklist",

        body:

            "Always ask for the OC before making the final payment or "

            "moving in. If a project is sold as 'ready to move in' without "

            "an OC, treat it as a red flag and consult a legal expert.",

      ),

    ],

  );



  static const saleDeed = KnowledgeArticle(

    icon: Icons.description_outlined,

    iconBg: Color(0xFFFFF4EC),

    title: "Sale Deed Explained",

    subtitle: "Documents, Format & Registration",

    sections: [

      KnowledgeSection(

        heading: "What is a Sale Deed?",

        body:

            "A Sale Deed is the primary legal document that records the "

            "actual transfer of ownership of a property from the seller to "

            "the buyer. It is executed after all terms in the sale "

            "agreement have been fulfilled.",

      ),

      KnowledgeSection(

        heading: "Sale Agreement vs Sale Deed",

        body:

            "A sale agreement is a promise to sell in the future, subject to "

            "conditions. A sale deed is the final document that actually "

            "conveys ownership and is legally binding immediately upon "

            "registration.",

      ),

      KnowledgeSection(

        heading: "Key contents of a Sale Deed",

        body:

            "• Details of buyer and seller\n"

            "• Full description of the property (survey number, "

            "boundaries, area)\n"

            "• Sale consideration (price) and mode of payment\n"

            "• Details of prior ownership/title\n"

            "• Indemnity clause\n"

            "• Delivery of possession clause",

      ),

      KnowledgeSection(

        heading: "Documents required for registration",

        body:

            "• Original sale agreement\n"

            "• Identity and address proof of both parties\n"

            "• PAN card\n"

            "• Property tax receipts\n"

            "• Encumbrance certificate\n"

            "• No Objection Certificate (if applicable)\n"

            "• Passport-size photographs",

      ),

      KnowledgeSection(

        heading: "Registration process",

        body:

            "1. Draft the sale deed on non-judicial stamp paper of "

            "appropriate value.\n"

            "2. Pay stamp duty and registration fees (varies by state).\n"

            "3. Both parties and two witnesses appear before the "

            "Sub-Registrar.\n"

            "4. Biometric verification and document signing.\n"

            "5. The registered deed is returned after processing.",

      ),

      KnowledgeSection(

        heading: "Why registration matters",

        body:

            "An unregistered sale deed has no legal validity for transfer of "

            "ownership. Registration creates a public record and protects "

            "the buyer's title against future disputes.",

      ),

    ],

  );



  static const realEstateInvestment = KnowledgeArticle(

    icon: Icons.bar_chart,

    iconBg: Color(0xFFF0FFF7),

    title: "Why Real Estate Investment Still Matters",

    subtitle: "2026 outlook & returns",

    sections: [

      KnowledgeSection(

        heading: "Long-term wealth creation",

        body:

            "Real estate has historically been a reliable way to build "

            "wealth over time, offering both capital appreciation and, in "

            "the case of rental properties, a steady income stream.",

      ),

      KnowledgeSection(

        heading: "Inflation hedge",

        body:

            "Property values and rents tend to rise along with inflation, "

            "which helps preserve purchasing power better than idle cash.",

      ),

      KnowledgeSection(

        heading: "Portfolio diversification",

        body:

            "Real estate often moves differently from stocks and bonds, so "

            "adding it to an investment portfolio can reduce overall "

            "volatility.",

      ),

      KnowledgeSection(

        heading: "Tangible, usable asset",

        body:

            "Unlike many financial instruments, real estate is a physical "

            "asset that can be used, rented, or improved to increase its "

            "value.",

      ),

      KnowledgeSection(

        heading: "Things to watch in 2026",

        body:

            "• Interest rate movements affecting home loan EMIs\n"

            "• Infrastructure development in emerging micro-markets\n"

            "• Rising demand for larger homes and integrated townships\n"

            "• Growing interest in REITs for more liquid real estate "

            "exposure",

      ),

      KnowledgeSection(

        heading: "Key takeaway",

        body:

            "Real estate remains a solid long-term investment, but returns "

            "vary significantly by location, property type, and timing, so "

            "thorough research and financial planning are essential before "

            "investing.",

      ),

    ],

  );



  static const propertyTax = KnowledgeArticle(

    icon: Icons.work_outline,

    iconBg: Color(0xFFF3EEFF),

    title: "Property Tax Guide for Homeowners",

    subtitle: "Calculations & exemptions explained",

    sections: [

      KnowledgeSection(

        heading: "What is Property Tax?",

        body:

            "Property tax is an annual amount paid by property owners to "

            "the local municipal authority. The revenue collected funds "

            "civic amenities such as roads, water supply, sanitation, and "

            "public infrastructure.",

      ),

      KnowledgeSection(

        heading: "How it's calculated",

        body:

            "Most municipalities use one of these methods:\n"

            "• Annual Rental Value (ARV) — based on expected annual rent\n"

            "• Capital Value System (CVS) — based on the market value of "

            "the property\n"

            "• Unit Area Value (UAV) — based on per-unit price of built-up "

            "area, adjusted for usage and location",

      ),

      KnowledgeSection(

        heading: "Factors affecting the amount",

        body:

            "• Location and zone of the property\n"

            "• Built-up area and type of construction\n"

            "• Age of the building\n"

            "• Usage (residential, commercial, or mixed)\n"

            "• Amenities provided",

      ),

      KnowledgeSection(

        heading: "Common exemptions & rebates",

        body:

            "• Senior citizens, ex-servicemen, and differently-abled owners "

            "often get concessional rates\n"

            "• Early or online payment discounts in many cities\n"

            "• Properties used exclusively for charitable or religious "

            "purposes may be exempt",

      ),

      KnowledgeSection(

        heading: "How to pay",

        body:

            "Most municipal corporations now offer online payment portals "

            "where owners can look up their property using a unique "

            "property ID and pay via card, net banking, or UPI.",

      ),

      KnowledgeSection(

        heading: "Consequences of non-payment",

        body:

            "Unpaid property tax accumulates interest and penalties, and "

            "prolonged non-payment can lead to legal notices or, in extreme "

            "cases, attachment of the property.",

      ),

    ],

  );



  static const reraRegistration = KnowledgeArticle(

    icon: Icons.shield_outlined,

    iconBg: Color(0xFFEFFFEC),

    title: "RERA Registration Explained",

    subtitle: "Rights, compliance & buyer protection",

    sections: [

      KnowledgeSection(

        heading: "What is RERA?",

        body:

            "The Real Estate (Regulation and Development) Act establishes "

            "state-level regulatory authorities to bring transparency and "

            "accountability to the real estate sector, and to protect the "

            "interests of homebuyers.",

      ),

      KnowledgeSection(

        heading: "What needs to be registered",

        body:

            "Any real estate project where the land area exceeds a "

            "specified threshold (commonly 500 sq. m. or more than 8 "

            "units) must be registered with the state RERA authority before "

            "it can be advertised, marketed, or sold.",

      ),

      KnowledgeSection(

        heading: "What developers must disclose",

        body:

            "• Project layout and approved plans\n"

            "• Land title status\n"

            "• Timeline for completion\n"

            "• Details of past projects\n"

            "• 70% of buyer funds must be kept in a separate escrow account "

            "for construction costs",

      ),

      KnowledgeSection(

        heading: "Buyer protections under RERA",

        body:

            "• Right to timely possession, with compensation for delays\n"

            "• Right to accurate project information before booking\n"

            "• Right to a refund with interest if the project is "

            "abandoned or misrepresented\n"

            "• Structural defect liability for 5 years after possession",

      ),

      KnowledgeSection(

        heading: "How to verify RERA registration",

        body:

            "Every registered project gets a unique RERA registration "

            "number, which can be verified on the respective state's RERA "

            "website. Always check this before booking a unit.",

      ),

      KnowledgeSection(

        heading: "What to do in case of a dispute",

        body:

            "Buyers can file a complaint with the state RERA authority, "

            "which is empowered to resolve disputes faster than "

            "traditional courts, typically within 60 days.",

      ),

    ],

  );



  static const List<KnowledgeArticle> all = [

    occupancyCertificate,

    saleDeed,

    realEstateInvestment,

    propertyTax,

    reraRegistration,

  ];

}



// ----------------------------------------------------------------------

// 3. DETAIL PAGE (generic — works for any article)

// ----------------------------------------------------------------------



class KnowledgeDetailPage extends StatelessWidget {

  final KnowledgeArticle article;



  const KnowledgeDetailPage({super.key, required this.article});



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: AppBar(

        elevation: 0,

        backgroundColor: Colors.white,

        foregroundColor: Colors.black87,

        scrolledUnderElevation: 0,

        surfaceTintColor: Colors.white,

        title: Text(

          article.title,

          style: const TextStyle(

            fontSize: 18,

            fontWeight: FontWeight.w600,

            color: Colors.black87,

          ),

        ),

      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Header card

            Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(

                    color: article.iconBg,

                    borderRadius: BorderRadius.circular(14),

                  ),

                  child: Icon(article.icon, color: Colors.black87, size: 28),

                ),

                const SizedBox(width: 14),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        article.title,

                        style: const TextStyle(

                          fontSize: 18,

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                      const SizedBox(height: 4),

                      Text(

                        article.subtitle,

                        style: TextStyle(

                          fontSize: 13,

                          color: Colors.grey.shade600,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

            const SizedBox(height: 24),



            // Sections

            for (final section in article.sections) ...[

              Text(

                section.heading,

                style: const TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.w700,

                ),

              ),

              const SizedBox(height: 8),

              Text(

                section.body,

                style: TextStyle(

                  fontSize: 14.5,

                  height: 1.55,

                  color: Colors.grey.shade800,

                ),

              ),

              const SizedBox(height: 20),

            ],

          ],

        ),

      ),

    );

  }

}



// ----------------------------------------------------------------------

// 4. UPDATED CARD LIST — wire this into your existing widget tree

// ----------------------------------------------------------------------

//

// Replace your current buildKnowledgeCard(...) calls with these onTap

// handlers. Everything else (icon, title, subtitle, iconBg) stays the same.



class KnowledgeCardsExample extends StatelessWidget {

  const KnowledgeCardsExample({super.key});



  void _openArticle(BuildContext context, KnowledgeArticle article) {

    Navigator.push(

      context,

      MaterialPageRoute(builder: (_) => KnowledgeDetailPage(article: article)),

    );

  }



  @override

  Widget build(BuildContext context) {

    // Assuming buildKnowledgeCard is defined elsewhere in your widget tree.

    return Column(

      children: [

        buildKnowledgeCard(

          icon: KnowledgeData.occupancyCertificate.icon,

          title: KnowledgeData.occupancyCertificate.title,

          subtitle: KnowledgeData.occupancyCertificate.subtitle,

          iconBg: KnowledgeData.occupancyCertificate.iconBg,

          onTap: () =>

              _openArticle(context, KnowledgeData.occupancyCertificate),

        ),

        buildKnowledgeCard(

          icon: KnowledgeData.saleDeed.icon,

          title: KnowledgeData.saleDeed.title,

          subtitle: KnowledgeData.saleDeed.subtitle,

          iconBg: KnowledgeData.saleDeed.iconBg,

          onTap: () => _openArticle(context, KnowledgeData.saleDeed),

        ),

        buildKnowledgeCard(

          icon: KnowledgeData.realEstateInvestment.icon,

          title: KnowledgeData.realEstateInvestment.title,

          subtitle: KnowledgeData.realEstateInvestment.subtitle,

          iconBg: KnowledgeData.realEstateInvestment.iconBg,

          onTap: () =>

              _openArticle(context, KnowledgeData.realEstateInvestment),

        ),

        buildKnowledgeCard(

          icon: KnowledgeData.propertyTax.icon,

          title: KnowledgeData.propertyTax.title,

          subtitle: KnowledgeData.propertyTax.subtitle,

          iconBg: KnowledgeData.propertyTax.iconBg,

          onTap: () => _openArticle(context, KnowledgeData.propertyTax),

        ),

        buildKnowledgeCard(

          icon: KnowledgeData.reraRegistration.icon,

          title: KnowledgeData.reraRegistration.title,

          subtitle: KnowledgeData.reraRegistration.subtitle,

          iconBg: KnowledgeData.reraRegistration.iconBg,

          onTap: () => _openArticle(context, KnowledgeData.reraRegistration),

        ),

      ],

    );

  }

}



// Placeholder signature — remove this if buildKnowledgeCard already exists

// in your file, this is just here so the example above type-checks.

Widget buildKnowledgeCard({

  required IconData icon,

  required String title,

  required String subtitle,

  required Color iconBg,

  required VoidCallback onTap,

}) {

  throw UnimplementedError('Use your existing buildKnowledgeCard widget');

}

