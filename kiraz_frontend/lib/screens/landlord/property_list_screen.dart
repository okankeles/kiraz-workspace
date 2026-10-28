import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/property.dart';
import '../../services/property_service.dart';
import 'add_property_screen.dart';
import 'property_detail_screen.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color primaryBlue = Color(0xFF1E50CE);

  final PropertyService _propertyService = PropertyService();
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final properties = await _propertyService.getProperties();
      if (!mounted) return;
      setState(() {
        _properties = properties;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddProperty() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddPropertyScreen(),
      ),
    );

    if (result == true) {
      _fetchProperties();
    }
  }

  Widget _buildInfoBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String extra,
    Color? valueColor,
    required bool isDark,
  }) {
    final infoBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : Colors.black87;
    final subTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final extraTextCol = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: subTextCol,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? textCol,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            extra,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: extraTextCol,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconBoxBg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetailScreen(property: property),
              ),
            );
            _fetchProperties();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: House Icon, Property Name, and "Aylık" Badge
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBoxBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.home_work_rounded,
                          color: accentBlue,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        property.name,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Text(
                        'Aylık',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Second Row: Location Pin Icon and Address
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        property.address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: cardBorder, height: 1, thickness: 1),
                ),

                // 2x2 Grid of 4 info containers
                Row(
                  children: [
                    Builder(
                      builder: (_) {
                        final bool hasTenant = property.tenantName != null &&
                            property.tenantName!.trim().isNotEmpty;
                        final String tenantDisplayName =
                            hasTenant ? property.tenantName!.trim() : 'Kiracı Atanmadı';
                        final String tenantExtra = hasTenant
                            ? (property.tenantPhone != null && property.tenantPhone!.trim().isNotEmpty
                                ? property.tenantPhone!.trim()
                                : (property.tenantEmail != null && property.tenantEmail!.trim().isNotEmpty
                                    ? property.tenantEmail!.trim()
                                    : 'Kayıtlı Kiracı'))
                            : 'Atamak için dokunun';
                        return Expanded(
                          child: _buildInfoBox(
                            icon: Icons.person_outline_rounded,
                            iconColor: hasTenant ? accentBlue : textSecondary,
                            label: 'Kiracı',
                            value: tenantDisplayName,
                            extra: tenantExtra,
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInfoBox(
                        icon: Icons.payments_outlined,
                        iconColor: const Color(0xFF34D399),
                        label: 'Kira Tutarı',
                        value: 'Aylık Takip',
                        extra: 'Detaylar için dokunun',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final String daskValue;
                    final String daskExtra;
                    final Color? daskColor;
                    if (property.daskEndDate != null) {
                      final days = property.daskEndDate!.difference(DateTime.now()).inDays;
                      if (days > 0) {
                        daskValue = '$days gün kaldı';
                        daskExtra = '${property.daskEndDate!.day.toString().padLeft(2, '0')}.${property.daskEndDate!.month.toString().padLeft(2, '0')}.${property.daskEndDate!.year}';
                        daskColor = days <= 30 ? const Color(0xFFFBBF24) : const Color(0xFF34D399);
                      } else {
                        daskValue = 'Süresi Doldu';
                        daskExtra = 'Poliçe Yenilenmeli';
                        daskColor = const Color(0xFFF87171);
                      }
                    } else {
                      daskValue = 'Belirtilmedi';
                      daskExtra = 'Poliçe Kaydı Yok';
                      daskColor = null;
                    }

                    final String depositValue;
                    final String depositExtra;
                    if (property.depositAmount != null && property.depositAmount! > 0) {
                      depositValue = '${property.depositAmount!.toStringAsFixed(0)} TL';
                      depositExtra = 'Güvence Bedeli';
                    } else {
                      depositValue = 'Belirtilmedi';
                      depositExtra = 'Depozito Yok';
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _buildInfoBox(
                            icon: Icons.shield_outlined,
                            iconColor: daskColor ?? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            label: 'DASK Durumu',
                            value: daskValue,
                            extra: daskExtra,
                            valueColor: daskColor,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInfoBox(
                            icon: Icons.savings_outlined,
                            iconColor: const Color(0xFFA78BFA),
                            label: 'Depozito',
                            value: depositValue,
                            extra: depositExtra,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder),
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 38,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Henüz Bir Mülk Eklenmedi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mülklerinizi ekleyerek kira sözleşmelerini ve kiracı ödemelerini anlık takip edebilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _navigateToAddProperty,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('İlk Mülkünüzü Ekleyin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.grey[100];
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: accentBlue,
          backgroundColor: cardBg,
          onRefresh: _fetchProperties,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Row Sliver
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kayıtlı Mülklerim',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toplam ${_properties.length} bağımsız bölüm',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _navigateToAddProperty,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ Mülk Ekle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Sliver
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: accentBlue),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _fetchProperties,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_properties.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(isDark),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildPropertyCard(_properties[index], isDark);
                      },
                      childCount: _properties.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
