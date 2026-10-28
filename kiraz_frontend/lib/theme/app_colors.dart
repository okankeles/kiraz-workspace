import 'package:flutter/material.dart';

/// Clean, trustworthy fintech & proptech color palette.
/// Restrained to 2 blue tones + crisp white and cool slate neutrals.
class AppColors {
  // Primary Trust Blue (Deep Sapphire / Royal Cobalt)
  static const Color primary = Color(
    0xFF1D4ED8,
  ); // Blue 700 - calm, solid, trustworthy
  static const Color primaryLight = Color(
    0xFF2563EB,
  ); // Blue 600 - active buttons & highlights
  static const Color primaryDark = Color(
    0xFF1E3A8A,
  ); // Blue 900 - deep navy for splash & hero

  // Secondary Sky / Accent Blue
  static const Color secondary = Color(
    0xFF0EA5E9,
  ); // Sky 500 - vibrant accent & indicators
  static const Color secondaryLight = Color(
    0xFF38BDF8,
  ); // Sky 400 - bright badge accent

  // Soft Ice Blue (replaces dated muddy greys)
  static const Color iceBlue = Color(
    0xFFEFF6FF,
  ); // Blue 50 - fresh pill/icon backgrounds
  static const Color iceBlueBorder = Color(
    0xFFDBEAFE,
  ); // Blue 100 - crisp border

  // Premium Ivory Palette (Fildişi)
  static const Color ivoryBg = Color(0xFFFBF8F1); // Ivory Light canvas
  static const Color ivoryBorder = Color(0xFFE5E0D8); // Sharpened ivory border

  // Pure White
  static const Color white = Color(0xFFFFFFFF);

  // Modern Neutrals (Light Mode - Ivory Canvas & Crisp White Cards)
  static const Color bgLight = Color(0xFFFBF8F1); // Ivory Light
  static const Color cardLight = Color(0xFFFFFFFF); // Pure white cards to pop
  static const Color borderLight = Color(0xFFE5E0D8); // Sharpened subtle border
  static const Color textPrimaryLight = Color(
    0xFF0F172A,
  ); // Slate 900 - rich deep navy-black
  static const Color textSecondaryLight = Color(
    0xFF475569,
  ); // Slate 600 - calm secondary text
  static const Color textMutedLight = Color(
    0xFF94A3B8,
  ); // Slate 400 - captions & unselected items

  // Deep Midnight Slate (Dark Mode)
  static const Color bgDark = Color(0xFF0B1120); // Slate 950 deep navy canvas
  static const Color cardDark = Color(
    0xFF111D33,
  ); // Slate 900 elevated navy card surface
  static const Color borderDark = Color(0xFF1E293B); // Slate 800 dark border
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color iceBlueDark = Color(0xFF1E293B); // Dark chip background

  // Minimal Status Accents (Restrained and modern, not loud)
  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFE11D48); // Rose 600
  static const Color dangerBg = Color(0xFFFFF1F2);
}
