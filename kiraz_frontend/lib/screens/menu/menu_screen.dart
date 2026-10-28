import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../auth/login_screen.dart';
import '../splash_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color primaryBlue = Color(0xFF1E50CE);

  String _userName = '';
  String _userRole = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('fullName') ?? 'Kullanıcı';
      final role = prefs.getString('role') ?? '';
      if (role.toUpperCase().contains('LANDLORD') || role.toUpperCase().contains('EV_SAHIBI')) {
        _userRole = 'Ev Sahibi';
      } else if (role.toUpperCase().contains('TENANT') || role.toUpperCase().contains('KIRACI')) {
        _userRole = 'Kiracı';
      } else {
        _userRole = role.isNotEmpty ? role : 'Kullanıcı';
      }
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Çıkış Yap',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('role');
      await prefs.remove('fullName');
      await prefs.remove('token');

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.delete_forever, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(
                'Uygulamayı Sıfırla',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Tüm yerel veriler silinecek ve uygulama ilk kurulum haline dönecek. Emin misiniz?',
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('Sıfırla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDark,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = textColor ?? (isDark ? Colors.white : Colors.black87);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title yakında hizmetinizde.'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? accentBlue).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? (isDark ? accentBlue : primaryBlue),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B1120) : Colors.grey[100];
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Text(
          'Menü ve Ayarlar',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Açık Tema' : 'Koyu Tema',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: textPrimary,
            ),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentBlue))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: (isDark ? accentBlue : primaryBlue).withValues(alpha: 0.15),
                        child: Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: isDark ? accentBlue : primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark ? accentBlue : primaryBlue).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _userRole,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? accentBlue : primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Hesap & Güvenlik
                _buildSectionHeader('HESAP & GÜVENLİK', textSecondary),
                _buildMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Profil Bilgileri',
                  subtitle: 'Kişisel bilgilerinizi güncelleyin',
                  isDark: isDark,
                ),
                _buildMenuItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'Şifre ve Güvenlik',
                  subtitle: 'Giriş güvenliği ve şifre değişikliği',
                  isDark: isDark,
                ),
                _buildMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Bildirim Tercihleri',
                  subtitle: 'Kira hatırlatmaları ve duyurular',
                  isDark: isDark,
                ),

                // Uygulama Ayarları
                _buildSectionHeader('UYGULAMA', textSecondary),
                _buildMenuItem(
                  icon: Icons.language_rounded,
                  title: 'Dil / Language',
                  subtitle: 'Türkçe',
                  isDark: isDark,
                ),
                _buildMenuItem(
                  icon: Icons.description_outlined,
                  title: 'Kullanım Koşulları & Gizlilik',
                  subtitle: 'KVKK ve kullanıcı sözleşmesi',
                  isDark: isDark,
                ),
                _buildMenuItem(
                  icon: Icons.support_agent_rounded,
                  title: 'Yardım ve Destek',
                  subtitle: 'Sıkça sorulan sorular ve iletişim',
                  isDark: isDark,
                ),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'kiraZ Hakkında',
                  subtitle: 'Versiyon 1.0.0 (A Plus Kira Yönetimi)',
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Logout Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: _logout,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    ),
                    title: Text(
                      'Çıkış Yap',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: Text(
                      'Oturumu sonlandır',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.redAccent, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  )),
                ),

                const SizedBox(height: 12),

                // Debug Reset Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: _resetApp,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    ),
                    title: Text(
                      'Uygulamayı Sıfırla (Test İçin)',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Text(
                      'Tüm yerel verileri ve oturumu sıfırla',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  )),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
