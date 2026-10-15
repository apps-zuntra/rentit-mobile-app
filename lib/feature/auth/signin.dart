// signin.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentit/core/api_service.dart';
import 'package:rentit/feature/auth/otp.dart';
import '../../providers/auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF2F3E4D);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loading = ref.read(loadingProvider.notifier);
    final isTermsAccepted = ref.read(termsProvider);

    final phone = phoneController.text.trim();

    /// PHONE VALIDATION
    if (phone.isEmpty || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10 digit mobile number")),
      );
      return;
    }

    /// TERMS VALIDATION
    if (!isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept Terms & Privacy Policy")),
      );
      return;
    }

    try {
      loading.state = true;

      /// API CALL
      await ApiService.sendOtp(phone);

      loading.state = false;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
      );
    } catch (e) {
      loading.state = false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPromoAccepted = ref.watch(promoProvider);
    final isTermsAccepted = ref.watch(termsProvider);
    final isLoading = ref.watch(loadingProvider);

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),

          child: FadeTransition(
            opacity: _fadeAnimation,

            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              child: Column(
                children: [
                  /// TOP SECTION
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 30,
                      bottom: 40,
                    ),

                    decoration: const BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(35),
                        bottomRight: Radius.circular(35),
                      ),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        /// APP LOGO
                        Center(
                          child: Container(
                            height: 90,
                            width: 90,

                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),

                            child: const Icon(
                              Icons.home_work_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        const Center(
                          child: Text(
                            "Welcome to Rentit",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Center(
                          child: Text(
                            "Find your perfect rental property\nfaster and smarter",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// FORM SECTION
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30,
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// TITLE
                        const Text(
                          "Sign in",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Enter your mobile number to continue",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 35),

                        /// MOBILE LABEL
                        const Text(
                          "Mobile Number",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: primaryColor,
                          ),
                        ),

                        const SizedBox(height: 12),

                        /// MOBILE FIELD
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),

                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,

                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],

                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),

                            decoration: InputDecoration(
                              counterText: "",
                              border: InputBorder.none,

                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 20,
                              ),

                              prefixIcon: Container(
                                margin: const EdgeInsets.only(
                                  left: 14,
                                  right: 10,
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "+91",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    Container(
                                      height: 22,
                                      width: 1,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),

                              hintText: "Enter mobile number",

                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// PROMOTIONAL CHECKBOX
                        Container(
                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Transform.scale(
                                scale: 1.05,

                                child: Checkbox(
                                  activeColor: primaryColor,
                                  value: isPromoAccepted,

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),

                                  onChanged: (val) {
                                    ref.read(promoProvider.notifier).state =
                                        val ?? false;
                                  },
                                ),
                              ),

                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 13),

                                  child: Text(
                                    "Receive promotional and advertising messages.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// TERMS CHECKBOX
                        Container(
                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Transform.scale(
                                scale: 1.05,

                                child: Checkbox(
                                  activeColor: primaryColor,
                                  value: isTermsAccepted,

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),

                                  onChanged: (val) {
                                    ref.read(termsProvider.notifier).state =
                                        val ?? false;
                                  },
                                ),
                              ),

                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 13),

                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        height: 1.5,
                                      ),

                                      children: const [
                                        TextSpan(text: "I agree to the "),

                                        TextSpan(
                                          text: "Terms of Service",
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        TextSpan(text: " & "),

                                        TextSpan(
                                          text: "Privacy Policy",
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 35),

                        /// GET OTP BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 60,

                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              elevation: 0,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),

                            onPressed: isLoading ? null : _submit,

                            child: isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,

                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Get OTP",
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),

                                      SizedBox(width: 10),

                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 35),

                        /// BOTTOM TEXT
                        Center(
                          child: Text(
                            "Safe • Secure • Trusted Rentals",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
