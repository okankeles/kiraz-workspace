import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color circleBlueBg = Color(0xFFEFF6FF);
  static const Color circleBlueBorder = Color(0xFFDBEAFE);
  static const Color indicatorInactive = Color(0xFFE2E8F0);

  final List<Map<String, dynamic>> _pages = const [
    {
      'icon': Icons.apartment_rounded,
      'title': "kiraZ'a Hoş Geldiniz!",
      'subtitle':
          'Kiralama, bakım ve yasal süreçler — tüm mülk yönetiminiz tek platformda.',
    },
    {
      'icon': Icons.pie_chart_outline_rounded,
      'title': 'Ev Sahipleri İçin',
      'subtitle':
          'Finansal durumunuzu anlık takip edin, mülklerinizin verimini artırın.',
    },
    {
      'icon': Icons.shield_outlined,
      'title': 'Kiracılar İçin',
      'subtitle': 'Kira takibi, şeffaf süreçler ve kolay iletişim bir arada.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ivoryBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip ("Atla") Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: vibrantBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    'Atla',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: vibrantBlue,
                    ),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),

                        // Centered Blue Circular Icon
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: circleBlueBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: circleBlueBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              page['icon'] as IconData,
                              size: 76,
                              color: vibrantBlue,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Title
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: darkNavy,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Subtitle
                        Text(
                          page['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Row
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicator (Row of small circular containers)
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? vibrantBlue
                              : indicatorInactive,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // "İleri" or "Kullanmaya Başla" Button
                  _currentPage == _pages.length - 1
                      ? ElevatedButton(
                          onPressed: _completeOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vibrantBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Kullanmaya Başla',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: vibrantBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'İleri',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: vibrantBlue,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: vibrantBlue,
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
