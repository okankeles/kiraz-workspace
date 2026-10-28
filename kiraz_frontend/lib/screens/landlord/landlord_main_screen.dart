import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../menu/menu_screen.dart';
import 'landlord_dashboard_screen.dart';
import 'property_list_screen.dart';
import 'tenant_list_screen.dart';

class LandlordMainScreen extends StatefulWidget {
  const LandlordMainScreen({super.key});

  @override
  State<LandlordMainScreen> createState() => _LandlordMainScreenState();
}

class _LandlordMainScreenState extends State<LandlordMainScreen> {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color accentBlue = Color(0xFF38BDF8);

  int _currentIndex = 0;

  Widget _buildPlaceholderTab({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final bgColor = isDark ? darkBg : Colors.grey[100];
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: isDark ? cardBg : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: vibrantBlue.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 42,
                    color: vibrantBlue,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Yapım Aşamasında',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Özet (Dashboard)
          const LandlordDashboardScreen(),

          // Tab 1: Mülkler (Property List)
          const PropertyListScreen(),

          // Tab 2: Kiracılar (Tenant List Screen)
          const TenantListScreen(),

          // Tab 3: Bakım (Placeholder)
          _buildPlaceholderTab(
            icon: Icons.build_outlined,
            title: 'Bakım ve Onarım',
            subtitle: 'Mülk bakım talepleri, arıza kayıtları ve usta takibi modülü yakında eklenecektir.',
            isDark: isDark,
          ),

          // Tab 4: Menü
          const MenuScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        selectedItemColor: isDark ? accentBlue : vibrantBlue,
        unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Özet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            activeIcon: Icon(Icons.business_rounded),
            label: 'Mülkler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Kiracılar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            activeIcon: Icon(Icons.build_rounded),
            label: 'Bakım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            activeIcon: Icon(Icons.menu_rounded),
            label: 'Menü',
          ),
        ],
      ),
    );
  }
}
