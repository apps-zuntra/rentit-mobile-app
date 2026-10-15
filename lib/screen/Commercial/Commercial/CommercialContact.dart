import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:rentit/screen/Commercial/Commercial/CommercialSchedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -- Design Tokens (consistent with CommercialProvideRentalDetails) ----------
const Color kScaffoldBg = Color(0xFFF4F6F9);
const Color kCardBg = Colors.white;
const Color kPrimaryText = Color(0xFF1A2332);
const Color kSecondaryText = Color(0xFF8A97A8);
const Color kBorderColor = Color(0xFFE4E9F0);
const Color kAccentBlue = Color(0xFF2C3E50);
const Color kInputBg = Color(0xFFF8FAFC);
const Color kLabelText = Color(0xFF8A97A8);
const Color kDivider = Color(0xFFEEF2F7);

class CommercialContactDetailsScreen extends StatefulWidget {
  const CommercialContactDetailsScreen({super.key});

  @override
  State<CommercialContactDetailsScreen> createState() =>
      _CommercialContactDetailsScreenState();
}

class _CommercialContactDetailsScreenState
    extends State<CommercialContactDetailsScreen> {
  final String API_BASE = "https://rentit-backend-yti9.onrender.com";

  // -- Controllers -------------------------------------------------------------
  late TextEditingController nameController;
  late TextEditingController mobileController;

  // -- State --------------------------------------------------------------------
  bool whatsappUpdates = true;
  bool isLoading = false;
  bool dataLoading = true;
  String? whoShowsProperty;

  // -- Lifecycle -----------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    mobileController = TextEditingController();
    loadExistingData();
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  // -- Load Existing Data --------------------------------------------------------
  Future<void> loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final propertyId = prefs.getInt("commercialId");
      final token = prefs.getString("token");

      if (propertyId == null || token == null) {
        if (mounted) setState(() => dataLoading = false);
        return;
      }

      final res = await http.get(
        Uri.parse("$API_BASE/commercial/$propertyId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      debugPrint("?? CONTACT RESPONSE => ${res.body}");

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => dataLoading = false);
        return;
      }

      final data = jsonDecode(res.body);

      setState(() {
        nameController.text = data["contactName"]?.toString() ?? "";
        mobileController.text = data["mobileNo"]?.toString() ?? "";
        whatsappUpdates = data["whatsapp"] ?? true;
        dataLoading = false;
      });
    } catch (e) {
      debugPrint("? Contact load error => $e");
      if (mounted) setState(() => dataLoading = false);
    }
  }

  // -- Helpers -------------------------------------------------------------------
  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: kAccentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // -- Save ----------------------------------------------------------------------
  Future<void> saveContact() async {
    if (nameController.text.trim().isEmpty) {
      showSnack("Please enter contact name");
      return;
    }
    if (mobileController.text.trim().length < 10) {
      showSnack("Please enter a valid 10-digit mobile number");
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommercialSchedule()),
    );
  }
  // -------------------------------------------------------------------------------
  // UI HELPERS
  // -------------------------------------------------------------------------------

  /// Card wrapper � consistent with CommercialProvideRentalDetails
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Section label � same style as CommercialProvideRentalDetails
  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: kLabelText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          if (required)
            const Text(
              " *",
              style: TextStyle(
                color: Color(0xFF9AA0AC),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  /// Input decoration � same as CommercialProvideRentalDetails
  InputDecoration _inputDec({String? hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
      filled: true,
      fillColor: kInputBg,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAccentBlue, width: 1.5),
      ),
    );
  }

  /// Progress bar � 7/8 filled segments
  Widget _progressBar() {
    const total = 8;
    const current = 7;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Row(
        children: List.generate(total, (i) {
          final active = i < current;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? kAccentBlue : kBorderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  // -- WhatsApp Toggle Card ----------------------------------------------------
  Widget _whatsappToggleCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // WhatsApp icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Image.network(
                  "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6b/WhatsApp.svg/120px-WhatsApp.svg.png",
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "GET UPDATES ON WHATSAPP",
                    style: TextStyle(
                      color: kLabelText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Receive enquiries & booking alerts",
                    style: TextStyle(
                      color: kSecondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: whatsappUpdates,
                onChanged: (val) => setState(() => whatsappUpdates = val),
                activeColor: kAccentBlue,
                activeTrackColor: kAccentBlue.withOpacity(0.25),
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Info Banner -------------------------------------------------------------
  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E0EC), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: kAccentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Your contact details will only be shared with verified tenants.",
              style: TextStyle(
                color: kAccentBlue.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Build -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kInputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderColor),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: kPrimaryText,
              size: 22,
            ),
          ),
        ),
        title: const Text(
          "Contact Details",
          style: TextStyle(
            color: kPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "7 / 8",
                style: TextStyle(
                  color: kSecondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _progressBar(),
          ),
        ),
      ),
      body: dataLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: kAccentBlue,
                strokeWidth: 2,
              ),
            )
          : Column(
              children: [
                // -- Scrollable Form -----------------------------------------
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        _infoBanner(),

                        // -- Contact Name ----------------------------------
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label("Contact Name", required: true),
                              TextField(
                                controller: nameController,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(
                                  color: kPrimaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDec(hint: "Enter Name"),
                              ),
                            ],
                          ),
                        ),

                        // -- Mobile Number ---------------------------------
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label("Mobile Number", required: true),

                              Container(
                                height: 58,
                                decoration: BoxDecoration(
                                  color: kInputBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: kBorderColor,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // -- Country Code -----------------------
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4F8),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(14),
                                          bottomLeft: Radius.circular(14),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "+91",
                                          style: TextStyle(
                                            color: kAccentBlue,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Divider
                                    Container(
                                      height: 24,
                                      width: 1,
                                      color: const Color(0xFFDCE3EB),
                                    ),

                                    // -- Mobile Input -----------------------
                                    Expanded(
                                      child: TextField(
                                        controller: mobileController,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                        cursorColor: kAccentBlue,
                                        style: const TextStyle(
                                          color: kPrimaryText,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              "Enter 10-digit mobile number",
                                          hintStyle: TextStyle(
                                            color: kSecondaryText.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 18,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // -- Who Shows the Property -------------------------

                        // -- WhatsApp Toggle --------------------------------
                        _whatsappToggleCard(),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // -- Sticky Save & Continue Button -------------------------
                Container(
                  color: kCardBg,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isLoading ? null : saveContact,
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Save & Continue",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
