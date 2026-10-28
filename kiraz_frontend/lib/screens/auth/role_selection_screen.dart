import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/cherry_logo.dart';
import 'invite_code_screen.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color cardBorder = Color(0xFFE5E0D8);
  static const Color iconBg = Color(0xFFEFF6FF);
  static const Color iconBorder = Color(0xFFDBEAFE);

  void _navigateToAuth(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialRole: role),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: cardBorder, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iconBorder, width: 1.2),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 28,
                    color: vibrantBlue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ivoryBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CherryLogo(size: 68, color: vibrantBlue),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Hesap Türünüzü Seçin',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: darkNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kira işlemlerinizi yönetmek için profilinizi seçiniz.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Card 1: Ev Sahibi
                  _buildRoleCard(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Ev Sahibi',
                    subtitle: 'Mülklerimi ve finansal durumumu yönetmek istiyorum.',
                    onTap: () => _navigateToAuth(context, 'LANDLORD'),
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Kiracı
                  _buildRoleCard(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'Kiracı',
                    subtitle: 'Kiralarımı takip etmek ve ödeme yapmak istiyorum.',
                    onTap: () => _navigateToAuth(context, 'TENANT'),
                  ),

                  const SizedBox(height: 32),

                  // Invite Code Quick Access
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        final email = await Navigator.push<dynamic>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InviteCodeScreen(),
                          ),
                        );
                        if (email != null &&
                            email is String &&
                            email.isNotEmpty &&
                            context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(
                                email: email,
                                initialRole: 'TENANT',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Ev sahibinizden davet kodu mu aldınız? Tıklayın.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: vibrantBlue,
                          decoration: TextDecoration.underline,
                          decorationColor: vibrantBlue,
                        ),
                      ),
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
