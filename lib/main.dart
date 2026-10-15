// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:rentit/core/deep_link_handler.dart';
import 'package:google_fonts/google_fonts.dart';

// Auth
import 'package:rentit/feature/auth/auth_wrapper.dart';
import 'package:rentit/feature/auth/signin.dart';
import 'package:rentit/feature/auth/onboarding_screen.dart';
import 'package:rentit/pg_page/pg_page/pg_post/PGPhotos.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentAmenities.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentLocationDetails.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentPhotos.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentPricedetails.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentPropertydetails.dart';
import 'package:rentit/screen/Apartment/Apartment/ApartmentSchedule.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialAmenities.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialLocationDetails.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialPhotos.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialPropertydetails.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialProvideRentalDetails.dart';
import 'package:rentit/screen/Commercial/Commercial/CommercialSchedule.dart';
import 'package:rentit/screen/PG_Hostel/PG_Hostel/PGRoomDetailsScreen.dart';
import 'package:rentit/screen/PG_Hostel/PG_Hostel/ProvideAdditionalDetails.dart';

// Navigation
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:rentit/screen/nav/pg_owner_navigation_screen.dart';

// Dashboard
import 'package:rentit/main/DashboardScreen.dart';
import 'package:rentit/main/ViewAllpropertys.dart';

// Visit Scheduler
import 'package:rentit/screen/visit_scheduler_screen.dart';

// Apartment Post Flow

// Commercial Post Flow

// View Details Pages
import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/ApartmentViewDetails.dart';
import 'package:rentit/ViewDetailsPages/Commercial/CommercialViewDetails.dart';
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/FlatmateViewDetails.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _handleDeepLink(Uri uri) {
    int? id;

    if (uri.host == 'property') {
      // Handles rentit://property/5
      if (uri.pathSegments.isNotEmpty) {
        id = int.tryParse(uri.pathSegments.first);
      }
    } else if (uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'property') {
      // Handles http://192.168.1.37/property/5
      id = int.tryParse(uri.pathSegments[1]);
    } else if (uri.pathSegments.length == 1) {
      // Handles fallback /5
      id = int.tryParse(uri.pathSegments.first);
    }

    if (id != null) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DeepLinkHandlerScreen(propertyId: id!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'RentIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: GoogleFonts.dmSans().fontFamily),

      // Initial Screen
      home: const AuthWrapper(),

      // Static Routes
      routes: {
        // ─────────────────────────────
        // Authentication & Onboarding
        // ─────────────────────────────
        '/onboarding': (_) => const OnboardingScreen(),
        '/login': (_) => const SignInScreen(),

        // ─────────────────────────────
        // Dashboard & Navigation
        // ─────────────────────────────
        '/dashboard': (_) => const DashboardPage(),
        '/mainNavigation': (_) => const MainNavigationScreen(),
        '/PgOwnerNavigationScreen': (_) => const PgOwnerNavigationScreen(),

        // ─────────────────────────────
        // Generic Property Listing
        // ─────────────────────────────
        '/all-properties': (_) => const AllPropertiesScreen(queryParams: {}),

        // ─────────────────────────────
        // Apartment Listings (Full House)
        // ─────────────────────────────
        '/properties': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, String>? ??
              {};
          return ApartmentPropertiesScreen(queryParams: args);
        },

        // ─────────────────────────────
        // PG Listings
        // ─────────────────────────────
        '/pg-properties': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, String>? ??
              {};
          return AllPropertiesScreen(queryParams: args);
        },

        // ─────────────────────────────
        // Flatmate Listings
        // ─────────────────────────────
        '/flatmates': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, String>? ??
              {};
          return FlatmateViewDetailsScreen(queryParams: args);
        },

        // ─────────────────────────────
        // Commercial Listings
        // ─────────────────────────────
        '/commercial-properties': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, String>? ??
              {};
          return CommercialPropertiesScreen(queryParams: args);
        },

        // ─────────────────────────────
        // Apartment Post Flow
        // ─────────────────────────────
        '/apartmentpropertydetails': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          final apartmentId = args?['apartmentId'] as int?;

          if (apartmentId == null) {
            return const _MissingArgumentScreen(
              message: 'Apartment ID is missing',
            );
          }

          return ApartmentPropertyDetailsScreen(apartmentId: apartmentId);
        },

        '/apartmentRentalDetails': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          final apartmentId = args?['apartmentId'] as int?;

          if (apartmentId == null) {
            return const _MissingArgumentScreen(
              message: 'Apartment ID is missing',
            );
          }

          return ApartmentRentalDetailsScreen(apartmentId: apartmentId);
        },

        '/apartmentlocationdetails': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          final apartmentId = args?['apartmentId'] as int? ?? 0;

          return ApartmentLocationDetailsScreen(
            selectedCity: 'Chennai',
            apartmentId: apartmentId,
          );
        },

        '/apartmentAmenities': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          final apartmentId = args?['apartmentId'] as int?;

          if (apartmentId == null) {
            return const _MissingArgumentScreen(
              message: 'Apartment ID is missing',
            );
          }

          return ApartmentAmenitiesScreen(apartmentId: apartmentId);
        },

        '/apartmentphotos': (_) => const ApartmentPhotosScreen(),

        '/apartmentScheduleViewing': (_) => const ApartmentScheduleForm(),

        // ─────────────────────────────
        // PG Post Flow
        // ─────────────────────────────
        '/pgRoomDetails': (_) => const PGRoomDetailsScreen(),

        '/pgAdditionalDetails': (_) => const PGAdditionalDetails(),

        '/pgPhotos': (_) => const PGPhotosScreen(),

        // ─────────────────────────────
        // Commercial Post Flow
        // ─────────────────────────────
        '/commercialDetails': (_) => const CommercialPropertyDetailsScreen(),

        '/commercialProvideRentalDetails': (_) =>
            const CommercialProvideRentalDetails(),

        '/commercialLocationDetails': (_) =>
            const CommercialLocationDetailsScreen(),

        '/commercialAmenities': (_) => const CommercialAmenities(),

        '/commercialPhotos': (_) => const CommercialPhotosScreen(),

        '/commercialSchedule': (_) => const CommercialSchedule(),
      },

      // Dynamic Routes
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/visitScheduler':
            final args = settings.arguments as Map<String, dynamic>?;

            final propertyId = args?['propertyId'];
            final propertyType = args?['propertyType'] ?? 'PG'; // ✅ default PG

            if (propertyId == null) {
              return MaterialPageRoute(
                builder: (_) => const _MissingArgumentScreen(
                  message: 'Property ID is missing',
                ),
              );
            }

            return MaterialPageRoute(
              builder: (_) => VisitSchedulerScreen(
                propertyId: propertyId,
                propertyType: propertyType, // ✅ pass property type
              ),
            );
        }

        return null;
      },

      // Unknown Route
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(
              child: Text(
                'No route defined for ${settings.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Missing Argument Screen
// ─────────────────────────────────────────────
class _MissingArgumentScreen extends StatelessWidget {
  final String message;

  const _MissingArgumentScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
