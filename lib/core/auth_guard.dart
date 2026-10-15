import 'package:flutter/material.dart';
import 'package:rentit/feature/auth/signin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGuard {
  /// Checks if a valid user session exists.
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('userId') ??
        int.tryParse(prefs.getString('userId') ?? '');
    return token != null && token.isNotEmpty && userId != null && userId > 0;
  }

  /// Runs [onAuthenticated] if the user is logged in; otherwise prompts them to sign in.
  static Future<void> protect(
    BuildContext context, {
    required VoidCallback onAuthenticated,
  }) async {
    final authed = await isAuthenticated();
    if (authed) {
      onAuthenticated();
    } else {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    }
  }

  /// Navigates to [screen] if authenticated; otherwise redirects to [SignInScreen].
  static Future<void> protectNavigation(
    BuildContext context, {
    required Widget screen,
  }) async {
    final authed = await isAuthenticated();
    if (!context.mounted) return;
    if (authed) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    }
  }
}
