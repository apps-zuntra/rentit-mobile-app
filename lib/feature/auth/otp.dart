// otp.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rentit/core/api_service.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF2F3E4D);

  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  late final List<FocusNode> focusNodes = List.generate(
    6,
    (index) => FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (controllers[index].text.isEmpty && index > 0) {
            focusNodes[index - 1].requestFocus();
            controllers[index - 1].selection = TextSelection.collapsed(
              offset: controllers[index - 1].text.length,
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    ),
  );

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int secondsRemaining = 15;

  Timer? timer;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    startTimer();

    focusNodes[0].requestFocus();
  }

  void startTimer() {
    timer?.cancel();

    setState(() {
      secondsRemaining = 15;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();

    _animationController.dispose();

    for (var c in controllers) {
      c.dispose();
    }

    for (var f in focusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  String getOtp() {
    return controllers.map((e) => e.text).join();
  }

  /// VERIFY OTP
  Future<void> verifyOtp() async {
    if (isLoading) return;

    final otp = getOtp();

    if (otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter complete OTP")));

      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final res = await ApiService.verifyOtp(widget.phone, otp);

      final token = res["token"];
      final user = res["user"];

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString("token", token);

      await prefs.setString("phone", widget.phone);

      await prefs.setInt("userId", user["id"]);

      if (user["email"] != null) {
        await prefs.setString("email", user["email"]);
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${e.toString()}")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// RESEND OTP
  Future<void> resendOtp() async {
    try {
      await ApiService.sendOtp(widget.phone);

      startTimer();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("OTP resent successfully")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to resend OTP")));
    }
  }

  Widget otpBox(int index) {
    return SizedBox(
      width: 52,
      height: 62,
      child: TextField(
        controller: controllers[index],
        focusNode: focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.only(top: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        onTap: () {
          // Highlight text on tap so typing replaces it
          if (controllers[index].text.isNotEmpty) {
            controllers[index].selection = TextSelection(
              baseOffset: 0,
              extentOffset: controllers[index].text.length,
            );
          }
        },
        onChanged: (value) {
          if (value.isEmpty) {
            return;
          }

          if (value.length > 1) {
            // Paste scenario
            for (int i = 0; i < value.length; i++) {
              if (index + i < 6) {
                controllers[index + i].text = value[i];
              }
            }
            int nextIdx = index + value.length;
            if (nextIdx > 5) nextIdx = 5;
            focusNodes[nextIdx].requestFocus();
            if (controllers[nextIdx].text.isNotEmpty) {
              controllers[nextIdx].selection = TextSelection(
                baseOffset: 0,
                extentOffset: controllers[nextIdx].text.length,
              );
            }
          } else {
            // Length is exactly 1
            if (index < 5) {
              focusNodes[index + 1].requestFocus();
              if (controllers[index + 1].text.isNotEmpty) {
                controllers[index + 1].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controllers[index + 1].text.length,
                );
              }
            } else {
              controllers[index].selection = const TextSelection.collapsed(
                offset: 1,
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },

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
                      top: 24,
                      bottom: 45,
                    ),

                    decoration: const BoxDecoration(
                      color: primaryColor,

                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(35),
                        bottomRight: Radius.circular(35),
                      ),
                    ),

                    child: Column(
                      children: [
                        /// BACK BUTTON
                        Align(
                          alignment: Alignment.centerLeft,

                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),

                            child: IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },

                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        /// OTP ICON
                        Container(
                          height: 90,
                          width: 90,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),

                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),

                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),

                        const SizedBox(height: 28),

                        const Text(
                          "OTP Verification",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "Enter the 6-digit code sent to",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                          ),

                          child: Text(
                            "+91 ${widget.phone}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// CONTENT
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 35,
                    ),

                    child: Column(
                      children: [
                        /// TITLE
                        const Align(
                          alignment: Alignment.centerLeft,

                          child: Text(
                            "Enter OTP",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerLeft,

                          child: Text(
                            "Please enter the verification code to continue your rental journey.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 35),

                        /// OTP BOXES
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) => otpBox(index)),
                        ),

                        const SizedBox(height: 35),

                        /// TIMER / RESEND
                        secondsRemaining > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),

                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(18),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                      color: primaryColor,
                                    ),

                                    const SizedBox(width: 10),

                                    Text(
                                      "Resend OTP in 00:${secondsRemaining.toString().padLeft(2, '0')}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : TextButton(
                                onPressed: resendOtp,

                                child: const Text(
                                  "Resend OTP",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                        const SizedBox(height: 40),

                        /// VERIFY BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 60,

                          child: ElevatedButton(
                            onPressed: isLoading ? null : verifyOtp,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              elevation: 0,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),

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
                                        "Verify & Login",
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
                        Text(
                          "Safe • Secure • Trusted Rental App",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
