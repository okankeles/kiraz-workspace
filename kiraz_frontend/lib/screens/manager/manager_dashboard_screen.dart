import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/managed_property.dart';
import '../../services/auth_service.dart';
import '../../services/delegation_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/cherry_logo.dart';
import '../auth/login_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color subtleBorder = Color(0xFFE5E0D8);
  static const Color darkCardBorder = Color(0xFF334155);

  final DelegationService _delegationService = DelegationService();

  int? _userId;
  String _userName = 'Mülk Yöneticisi';
  String _userEmail = '';
  List<ManagedProperty> _properties = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadManagerData();
  }

  Future<void> _loadManagerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('userId');
      _userName = prefs.getString('fullName') ?? 'Mülk Yöneticisi';
      _userEmail = prefs.getString('email') ?? '';

      final items = await _delegationService.getManagerProperties(managerId: _userId);

      if (!mounted) return;
      setState(() {
        _properties = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // --- MÜLK DETAY MODALI ---
  void _showPropertyDetails(ManagedProperty property) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            property.address,
                            style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        icon: Icons.person_pin_circle_outlined,
                        label: 'Ev Sahibi',
                        value: property.displayLandlord,
                        subValue: property.landlordEmail,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailRow(
                        icon: Icons.description_outlined,
                        label: 'Genel Durum',
                        value: property.displayStatus,
                        isDark: isDark,
                      ),
                      if (property.tenantName != null && property.tenantName!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDetailRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Mevcut Kiracı',
                          value: property.tenantName!,
                          subValue: property.tenantPhone,
                          isDark: isDark,
                        ),
                      ],
                      if (property.referenceCode != null && property.referenceCode!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDetailRow(
                          icon: Icons.vpn_key_outlined,
                          label: 'Yetkilendirme Kodu',
                          value: property.referenceCode!,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${property.name} için işlem menüsü açıldı.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Sözleşme / İşlem Yap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: vibrantBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: vibrantBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (subValue != null && subValue.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final textPrimary = isDark ? Colors.white : darkNavy;

    // Metrikler
    final totalProperties = _properties.length;
    final totalActiveLeases = _properties.fold<int>(
      0,
      (sum, p) => sum + (p.activeLeasesCount > 0 ? p.activeLeasesCount : (p.isOccupied ? 1 : 0)),
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            const CherryLogo(size: 28, color: vibrantBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yönetilen Mülkler',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Mülk Yönetim Portföyü',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: Icon(Icons.logout_rounded, color: textPrimary),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: vibrantBlue))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadManagerData,
                  color: vibrantBlue,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Üst Özet Kartı
                      _buildHeaderCard(isDark, totalProperties, totalActiveLeases),
                      const SizedBox(height: 18),

                      // Başlık
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Yetkili Portföyünüz',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: vibrantBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalProperties Mülk',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: vibrantBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_properties.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _properties.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final property = _properties[index];
                            return _buildPropertyCard(property, isDark);
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  // --- ÜST ÖZET KARTI ---
  Widget _buildHeaderCard(bool isDark, int totalProps, int totalLeases) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            vibrantBlue,
            const Color(0xFF163E9B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: vibrantBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoş Geldiniz,',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PROPERTY MANAGER',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yönetilen Mülk',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalProps',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 34, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktif Sözleşmeler',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalLeases',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  // --- MÜLK KARTI ---
  Widget _buildPropertyCard(ManagedProperty property, bool isDark) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? darkCardBg : Colors.white;
    final cardBorder = isDark ? darkCardBorder : subtleBorder;

    return InkWell(
      onTap: () => _showPropertyDetails(property),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Mülk Adı ve Rozet
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: vibrantBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: vibrantBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              property.address.isNotEmpty ? property.address : 'Adres bilgisi mevcut değil',
                              style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Orta Alan: Ev Sahibi Bilgisi & Genel Durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ev Sahibi Bilgisi
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_pin_circle_outlined, size: 16, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ev Sahibi',
                              style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                            ),
                            Text(
                              property.displayLandlord,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Genel Durum (Örn: "2 aktif sözleşme")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: property.isOccupied
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: property.isOccupied
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        property.isOccupied ? Icons.verified_rounded : Icons.schedule_rounded,
                        size: 13,
                        color: property.isOccupied ? const Color(0xFF10B981) : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        property.displayStatus,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: property.isOccupied ? const Color(0xFF10B981) : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- BOŞ DURUM (EMPTY STATE) ---
  Widget _buildEmptyState(bool isDark) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? darkCardBorder : subtleBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: vibrantBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_work_outlined,
              size: 56,
              color: vibrantBlue,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Henüz Yönetilen Mülk Bulunmuyor',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ev sahipleri mülk yönetim yetkisi devrettiğinde mülkleriniz burada listelenecektir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          if (_userEmail.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email_outlined, size: 16, color: textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _userEmail,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: vibrantBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _userEmail));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('E-posta adresi panoya kopyalandı!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 15, color: vibrantBlue),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loadManagerData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Listeyi Yenile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: vibrantBlue,
              side: const BorderSide(color: vibrantBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // --- HATA GÖRÜNÜMÜ ---
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Bir hata oluştu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadManagerData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: vibrantBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
