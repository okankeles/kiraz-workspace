import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/lease.dart';
import '../../models/property.dart';
import '../../services/lease_service.dart';
import '../tenant/rent_period_list_screen.dart';
import 'assign_tenant_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  List<Lease> _leases = [];
  bool _isLoadingLeases = true;

  @override
  void initState() {
    super.initState();
    _fetchLeases();
  }

  Future<void> _fetchLeases() async {
    setState(() => _isLoadingLeases = true);
    try {
      final leases = await LeaseService().getLeasesForProperty(widget.property.id);
      if (!mounted) return;
      setState(() {
        _leases = leases;
        _isLoadingLeases = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingLeases = false);
    }
  }

  Future<void> _onAssignTenant() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignTenantScreen(propertyId: widget.property.id),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kiracı başarıyla atandı!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchLeases();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final textColor = isDark ? Colors.white : darkNavy;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.property.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Property Info Card
            Card(
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : subtleBorder,
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.home_work_outlined,
                            color: vibrantBlue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.property.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mülk Detayları',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: vibrantBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adres',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.property.address.isNotEmpty
                                    ? widget.property.address
                                    : 'Adres belirtilmemiş',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
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
            ),
            const SizedBox(height: 24),

            // Tenant Info Section
            Text(
              'Kiracı Bilgileri',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : subtleBorder,
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: _isLoadingLeases
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _leases.isEmpty
                        ? Column(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 48,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Bu mülke henüz bir kiracı atanmadı.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _onAssignTenant,
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Kiracı Ata'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: vibrantBlue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._leases.map((lease) {
                                final isPending =
                                    lease.status?.toUpperCase() == 'PENDING';
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : subtleBorder,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isPending
                                                ? 'Onay Bekleyen Sözleşme #${lease.id}'
                                                : 'Aktif Sözleşme #${lease.id}',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: textColor,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isPending
                                                  ? (isDark
                                                      ? const Color(0xFF78350F).withValues(alpha: 0.35)
                                                      : const Color(0xFFFEF3C7))
                                                  : Colors.green.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isPending ? 'Onay Bekliyor' : 'Aktif',
                                              style: TextStyle(
                                                color: isPending
                                                    ? (isDark
                                                        ? const Color(0xFFFBBF24)
                                                        : const Color(0xFFD97706))
                                                    : Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.payments_outlined,
                                              size: 16, color: vibrantBlue),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Aylık Kira: ${lease.rentAmount.toStringAsFixed(0)} TL',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Başlangıç: ${lease.startDate}',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RentPeriodListScreen(
                                                leaseId: lease.id,
                                                isLandlord: true,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                        label: const Text('Ödeme Takibi'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: vibrantBlue,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(double.infinity, 40),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _onAssignTenant,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Kiracıyı / Sözleşmeyi Güncelle'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: vibrantBlue,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
