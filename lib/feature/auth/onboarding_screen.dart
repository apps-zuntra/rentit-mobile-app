import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentit/feature/auth/signin.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Exact Figma Color Tokens
  static const Color _kCloudBurst = Color(0xFF1D2F45); // rgba(29, 47, 69, 1)
  static const Color _kPaleSky = Color(0xFF667085); // rgba(102, 112, 133, 1)
  static const Color _kAmberOrange = Color(0xFFF59E0B);
  static const Color _kIconBg = Color(0xFFF1F5F9);

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      title: 'Find a place.\nLive better.',
      subtitle:
          'Discover verified properties that fit your lifestyle, location, and budget.',
      imageUrl: 'assets/onboarding_1.png',
      buttonText: 'Explore Rentit',
      imageOffset: Offset.zero,
      imageScale: 1.0,
      borderRadius: BorderRadius.zero,
      features: [
        _FeatureData(
          icon: Icons.verified_outlined,
          title: 'Verified Listings',
          description:
              'Find trusted properties from verified owners and reliable listings.',
        ),
        _FeatureData(
          icon: Icons.link_rounded,
          title: 'Direct Owner Connect',
          description:
              'Connect directly with property owners without unnecessary middlemen.',
        ),
        _FeatureData(
          icon: Icons.home_work_outlined,
          title: 'Easy Property Discovery',
          description:
              'Search apartments, homes, PGs, and commercial spaces with ease.',
        ),
      ],
    ),
    _OnboardingData(
      title: 'Rent smarter.\nMove with confidence.',
      subtitle:
          'From shortlisting to scheduling visits, Rentit makes your rental journey simpler.',
      imageUrl: 'assets/onboarding_2.png',
      buttonText: 'Get Started',
      imageOffset: const Offset(-57, 0),
      imageScale: 1.0,
      borderRadius: BorderRadius.circular(24),
      gapBeforeImage: 12.0,
      gapAfterImage: 36.0,
      features: [
        _FeatureData(
          icon: Icons.credit_card_outlined,
          title: 'Zero Brokerage',
          description:
              'Save money by connecting directly with property owners.',
        ),
        _FeatureData(
          icon: Icons.calendar_today_outlined,
          title: 'Schedule Without the Hassle',
          description:
              'Contact owners and schedule property visits at your convenience.',
        ),
        _FeatureData(
          icon: Icons.article_outlined,
          title: 'Everything You Need',
          description:
              'Compare properties, check amenities, and shortlist your favourites.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigateToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const SignInScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onButtonPressed() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                // Top Header (Logo + Skip)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 14,
                    bottom: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'RENT',
                              style: GoogleFonts.dmSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kCloudBurst,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextSpan(
                              text: 'IT',
                              style: GoogleFonts.dmSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kAmberOrange,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _navigateToLogin,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kPaleSky,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // PageView with Swipable Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _buildPageContent(page);
                    },
                  ),
                ),

                // Bottom Pagination Dots & CTA Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == index ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _kCloudBurst
                                  : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // CTA Action Button (Height: 52px, DM Sans SemiBold 16px)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onButtonPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kCloudBurst,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _pages[_currentPage].buttonText,
                              key: ValueKey<int>(_currentPage),
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingData page) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Headline (DM Sans SemiBold 30px, 120% line-height, -0.4px letter-spacing, Cloud Burst)
          Text(
            page.title,
            style: GoogleFonts.dmSans(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: -0.4,
              color: _kCloudBurst,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle (DM Sans Regular 14px, 21px line-height, Pale Sky)
          Text(
            page.subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _kPaleSky,
              height: 21 / 14,
              letterSpacing: 0,
            ),
          ),

          SizedBox(height: page.gapBeforeImage),

          // Illustration Image (342 Fill with corner radius)
          SizedBox(
            width: double.infinity,
            height: 225,
            child: Transform.translate(
              offset: page.imageOffset,
              child: Transform.scale(
                scale: page.imageScale,
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: page.borderRadius,
                  child: page.imageUrl.startsWith('assets/')
                      ? Image.asset(
                          page.imageUrl,
                          width: double.infinity,
                          height: 225,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              color: const Color(0xFFF8FAFC),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.apartment_rounded,
                                size: 56,
                                color: Color(0xFF94A3B8),
                              ),
                            );
                          },
                        )
                      : Image.network(
                          page.imageUrl,
                          width: double.infinity,
                          height: 225,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _kAmberOrange,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              color: const Color(0xFFF8FAFC),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.apartment_rounded,
                                size: 56,
                                color: Color(0xFF94A3B8),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),

          SizedBox(height: page.gapAfterImage),

          // 3 Feature Rows
          ...page.features.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildFeatureItem(
                icon: feat.icon,
                iconColor: _kCloudBurst,
                bgColor: _kIconBg,
                title: feat.title,
                description: feat.description,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon Container
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),

        // Text Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title (DM Sans SemiBold 14px, 100% line-height, Cloud Burst)
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kCloudBurst,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),

              // Description (DM Sans Regular 12px, 17.5px line-height, Pale Sky)
              Text(
                description,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: _kPaleSky,
                  height: 17.5 / 12,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String buttonText;
  final Offset imageOffset;
  final double imageScale;
  final BorderRadius borderRadius;
  final double gapBeforeImage;
  final double gapAfterImage;
  final List<_FeatureData> features;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.buttonText,
    this.imageOffset = Offset.zero,
    this.imageScale = 1.0,
    this.borderRadius = BorderRadius.zero,
    this.gapBeforeImage = 12.0,
    this.gapAfterImage = 24.0,
    required this.features,
  });
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
