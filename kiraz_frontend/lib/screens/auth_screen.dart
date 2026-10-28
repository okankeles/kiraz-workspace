import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_role.dart';
import '../widgets/cherry_logo.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  final UserRole role;

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = false; // Default to Sign Up to show full form
  bool _obscurePassword = true;

  // Design system colors
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(initialRole: widget.role)),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon, {
    required bool isDark,
    bool isPassword = false,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: darkNavy,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: vibrantBlue,
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? const Color(0xFFFBF8F1) : Colors.white,
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          prefixIcon: Icon(icon, color: vibrantBlue),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: isDark
                ? BorderSide.none
                : const BorderSide(color: subtleBorder, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: isDark
                ? BorderSide.none
                : const BorderSide(color: subtleBorder, width: 1.2),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: vibrantBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final titleColor = isDark ? Colors.white : darkNavy;
    final toggleTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: CherryLogo(size: 60, color: vibrantBlue)),
                const SizedBox(height: 18),
                Text(
                  isLogin ? "Giriş Yap" : "Kayıt Ol",
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: isDark
                          ? null
                          : Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      "${widget.role.roleType == RoleType.landlord ? 'Ev Sahibi' : 'Kiracı'} olarak devam ediyorsunuz",
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.blue.shade300 : vibrantBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Form Fields
                if (!isLogin) ...[
                  _buildTextField(
                    "Ad Soyad",
                    Icons.person_outline,
                    isDark: isDark,
                    controller: _nameController,
                  ),
                  _buildTextField(
                    "E-posta",
                    Icons.email_outlined,
                    isDark: isDark,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildTextField(
                    "Telefon",
                    Icons.phone_outlined,
                    isDark: isDark,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildTextField(
                    "Şifre",
                    Icons.lock_outline,
                    isDark: isDark,
                    isPassword: true,
                    controller: _passwordController,
                  ),
                ] else ...[
                  _buildTextField(
                    "E-posta",
                    Icons.email_outlined,
                    isDark: isDark,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildTextField(
                    "Şifre",
                    Icons.lock_outline,
                    isDark: isDark,
                    isPassword: true,
                    controller: _passwordController,
                  ),
                ],

                const SizedBox(height: 8),

                // Action Button
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLogin ? "Giriş Yap" : "Kayıt Ol",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Toggle between Login & Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin ? "Hesabınız yok mu?" : "Zaten hesabınız var mı?",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: toggleTextColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? "Kayıt Ol" : "Giriş Yap",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: vibrantBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
