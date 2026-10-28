import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../menu/menu_screen.dart';
import 'tenant_contract_screen.dart';
import 'tenant_dashboard_screen.dart';

class TenantMainScreen extends StatefulWidget {
  const TenantMainScreen({super.key});

  @override
  State<TenantMainScreen> createState() => _TenantMainScreenState();
}

class _TenantMainScreenState extends State<TenantMainScreen> {
  static const Color darkBg = Color(0xFF0B1120);
  static const Color navBgDark = Color(0xFF0F172A);
  static const Color navSelectedDark = Color(0xFF38BDF8);
  static const Color navUnselectedDark = Color(0xFF94A3B8);
  static const Color vibrantBlue = Color(0xFF1E50CE);

  int _currentIndex = 0;

  Widget _buildPlaceholderTab({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final bgColor = isDark ? darkBg : Colors.grey[100];
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
                  color: isDark ? navBgDark : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark ? navSelectedDark : vibrantBlue).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 40,
                    color: isDark ? navSelectedDark : vibrantBlue,
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
                  ),
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
    final navBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final navSelected = isDark ? navSelectedDark : vibrantBlue;
    final navUnselected = isDark ? navUnselectedDark : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? darkBg : Colors.grey[100],
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Özet (Tenant Dashboard)
          const TenantDashboardScreen(),

          // Tab 1: Sözleşmem (Tenant Contract Screen)
          const TenantContractScreen(),

          // Tab 2: Ödemeler (Placeholder)
          _buildPlaceholderTab(
            icon: Icons.payment_outlined,
            title: 'Ödemelerim',
            subtitle:
                'Geçmiş ve gelecek tüm kira ve aidat ödeme geçmişinize bu ekrandan ulaşabilirsiniz.',
            isDark: isDark,
          ),

          // Tab 3: Bakım (Placeholder)
          _buildPlaceholderTab(
            icon: Icons.build_outlined,
            title: 'Bakım ve Arıza Talepleri',
            subtitle:
                'Evdeki arıza, tamirat ve bakım taleplerinizi doğrudan ev sahibinize iletebileceksiniz.',
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
        backgroundColor: navBg,
        selectedItemColor: navSelected,
        unselectedItemColor: navUnselected,
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
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'Sözleşmem',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment_outlined),
            activeIcon: Icon(Icons.payment),
            label: 'Ödemeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Bakım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_rounded),
            activeIcon: Icon(Icons.menu),
            label: 'Menü',
          ),
        ],
      ),
    );
  }
}
