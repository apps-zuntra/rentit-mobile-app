import 'package:flutter/material.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/feature/auth/onboarding_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<Map<String, dynamic>> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString("token");
    final userId = prefs.getInt("userId");
    final hasSeenOnboarding = prefs.getBool("has_seen_onboarding") ?? false;

    debugPrint("TOKEN: $token");
    debugPrint("USER ID: $userId");
    debugPrint("HAS SEEN ONBOARDING: $hasSeenOnboarding");

    return {
      "isLoggedIn": token != null && userId != null,
      "hasSeenOnboarding": hasSeenOnboarding,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAuthState(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final isLoggedIn = data["isLoggedIn"] == true;

        // 1. Logged in -> Home
        if (isLoggedIn) {
          return const MainNavigationScreen();
        }

        // 2. Non-logged in -> Onboarding Flow (Page 1 -> Page 2 -> Sign In)
        return const OnboardingScreen();
      },
    );
  }
}
