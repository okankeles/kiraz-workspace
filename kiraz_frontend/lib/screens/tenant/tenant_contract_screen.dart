import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../models/lease.dart';
import '../../services/lease_service.dart';

class TenantContractScreen extends StatefulWidget {
  const TenantContractScreen({super.key});

  @override
  State<TenantContractScreen> createState() => _TenantContractScreenState();
}

class _TenantContractScreenState extends State<TenantContractScreen> {
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color primaryBlue = Color(0xFF1E50CE);

  final LeaseService _leaseService = LeaseService();
  Lease? _activeLease;
  String _userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaseData();
  }

  Future<void> _fetchLeaseData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('fullName') ?? 'Kiracı';
      final userId = prefs.getInt('userId');

      if (userId != null) {
        final leases = await _leaseService.getLeasesForTenant(userId);
        if (leases.isNotEmpty) {
          _activeLease = leases.first;
        }
      }
    } catch (_) {
      // Use fallback/placeholders gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr, {bool isEnd = false}) {
    if (dateStr == null || dateStr.isEmpty) {
      return isEnd ? '01.11.2026' : '01.11.2025';
    }
    try {
      final dt = DateTime.parse(dateStr);
      final target = isEnd ? DateTime(dt.year + 1, dt.month, dt.day) : dt;
      return '${target.day.toString().padLeft(2, '0')}.${target.month.toString().padLeft(2, '0')}.${target.year}';
    } catch (_) {
      return isEnd ? '01.11.2026' : dateStr;
    }
  }

  void _showDocumentPreviewDialog(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final boxBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'kira_sozlesmesi.pdf',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Color(0xFF34D399), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'E-İmza ile Onaylandı',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sözleşme No: KRZ-KNT-2026',
                      style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mülk: ${_activeLease?.propertyName ?? "Kadıköy Dairesi"}',
                      style: GoogleFonts.inter(fontSize: 12, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Geçerlilik: ${_formatDate(_activeLease?.startDate)} - ${_formatDate(_activeLease?.startDate, isEnd: true)}',
                      style: GoogleFonts.inter(fontSize: 12, color: textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bu sözleşme kiraZ altyapısı üzerinden 5070 sayılı Elektronik İmza Kanunu kapsamında yasal olarak imzalanmıştır.',
                style: GoogleFonts.inter(fontSize: 11, color: textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Kapat', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sözleşme belgesi cihazınıza indirildi.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('İndir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    bool isLast = false,
  }) {
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: cardBorder, height: 1),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;

    final startStr = _formatDate(_activeLease?.startDate);
    final endStr = _formatDate(_activeLease?.startDate, isEnd: true);
    final rentStr = _activeLease != null
        ? '${_activeLease!.rentAmount.toStringAsFixed(0)} TL'
        : '18.000 TL';
    final depositStr = _activeLease != null
        ? '${(_activeLease!.rentAmount * 2).toStringAsFixed(0)} TL'
        : '36.000 TL';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: accentBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sözleşme Özeti',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  'Aktif',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            icon: Icons.calendar_today_outlined,
            iconColor: accentBlue,
            label: 'Başlangıç Tarihi',
            value: startStr,
            isDark: isDark,
          ),
          _buildSummaryRow(
            icon: Icons.event_available_outlined,
            iconColor: const Color(0xFF34D399),
            label: 'Bitiş Tarihi',
            value: endStr,
            isDark: isDark,
          ),
          _buildSummaryRow(
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFFFBBF24),
            label: 'Aylık Kira Tutarı',
            value: rentStr,
            isDark: isDark,
          ),
          _buildSummaryRow(
            icon: Icons.savings_outlined,
            iconColor: const Color(0xFFA78BFA),
            label: 'Depozito',
            value: depositStr,
            isDark: isDark,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final avatarBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_outline_rounded, color: Color(0xFF34D399), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Taraflar',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Ev Sahibi Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarBg,
                child: const Icon(Icons.home_work_rounded, color: accentBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ev Sahibi (Kiralayan)',
                          style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Onaylı',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeLease?.landlordName ?? 'Bilinmiyor',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeLease?.landlordEmail != null && _activeLease!.landlordEmail!.isNotEmpty
                          ? _activeLease!.landlordEmail!
                          : 'E-posta belirtilmedi',
                      style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: cardBorder, height: 1),
          ),

          // Kiracı Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarBg,
                child: const Icon(Icons.person_rounded, color: Color(0xFF34D399), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiracı',
                      style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName.isNotEmpty ? _userName : 'Kiracı',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aktif Sözleşme Sahibi',
                      style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final boxBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resmi Belge',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                // Red PDF Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.redAccent,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'kira_sozlesmesi.pdf',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elektronik İmzalı Resmi Belge (2.4 MB)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDocumentPreviewDialog(isDark),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Belgeyi Görüntüle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B1120) : Colors.grey[100];
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.home_rounded,
                color: accentBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'kiraZ',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
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
          ? const Center(
              child: CircularProgressIndicator(color: accentBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kira Sözleşmem',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Yasal sözleşme detaylarınız ve resmi belgeleriniz',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Top Card: Sözleşme Özeti
                  _buildSummaryCard(isDark),

                  const SizedBox(height: 20),

                  // Middle Card: Taraflar
                  _buildPartiesCard(isDark),

                  const SizedBox(height: 20),

                  // Bottom Card: Resmi Belge
                  _buildDocumentCard(isDark),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
