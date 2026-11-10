import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/token_storage.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color brandBlue = Color(0xFF1E50CE);

  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // 1. JWT öncesi legacy shared_preferences temizliği (ilk açılışta bir kez)
    await AuthService.migrateLegacySession();

    // 2. Açılışta oturumun açık sayılması YALNIZCA secure storage'da refresh token bulunmasına bağlıdır.
    final tokenStorage = TokenStorage();
    final hasSession = await tokenStorage.hasRefreshToken();

    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (!mounted) return;

    if (hasSession) {
      // Secure storage'daki profil bilgilerini SharedPreferences ile senkronize et
      final role = await tokenStorage.getUserRole();
      final fullName = await tokenStorage.getUserFullName();
      final userId = await tokenStorage.getUserId();
      final email = await tokenStorage.getUserEmail();
      if (role != null) await prefs.setString('role', role);
      if (fullName != null) await prefs.setString('fullName', fullName);
      if (userId != null) await prefs.setInt('userId', userId);
      if (email != null) await prefs.setString('email', email);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (isFirstLaunch) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_rounded,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'kiraZ',
              style: GoogleFonts.poppins(
                fontSize: 46,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ars A Plus Kira Uygulaması',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
