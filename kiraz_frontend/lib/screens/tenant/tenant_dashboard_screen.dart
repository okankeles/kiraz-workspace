import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../models/dashboard_stats.dart';
import '../../models/lease.dart';
import '../../models/notification_model.dart';
import '../../models/rent_period.dart';
import '../../services/dashboard_service.dart';
import '../../services/lease_service.dart';
import '../../services/notification_service.dart';
import '../../services/rent_period_service.dart';
import '../../utils/constants.dart';
import '../auth/invite_code_screen.dart';

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color vibrantBlue = Color(0xFF2563EB);

  final LeaseService _leaseService = LeaseService();
  final RentPeriodService _rentPeriodService = RentPeriodService();
  final DashboardService _dashboardService = DashboardService();
  final NotificationService _notificationService = NotificationService();

  String _userName = '';
  DashboardStats? _stats;
  Lease? _activeLease;
  List<RentPeriod> _periods = [];
  List<AppNotification> _notifications = [];
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;
  String? _errorMessage;
  int? _uploadingPeriodId;
  bool _isActivatingLease = false;
  int _selectedTabIndex = 0; // 0: All, 1: PAID, 2: OVERDUE, 3: PENDING

  @override
  void initState() {
    super.initState();
    _fetchTenantData();
  }

  Future<void> _fetchTenantData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('fullName') ?? 'Kiracı';
      final userId = prefs.getInt('userId');

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final statsFuture = _dashboardService.getTenantStats(userId);
      final leasesFuture = _leaseService.getLeasesForTenant(userId);
      final notifsFuture = _notificationService.getUnreadNotifications(userId);

      final stats = await statsFuture;
      _stats = stats;

      try {
        final notifs = await notifsFuture;
        _notifications = notifs;
        _unreadNotificationsCount = notifs.length;
      } catch (_) {}

      final leases = await leasesFuture;
      if (leases.isNotEmpty) {
        _activeLease = leases.first;
        final periods = await _rentPeriodService.getPeriodsForLease(_activeLease!.id);
        _periods = periods;
      } else {
        _activeLease = null;
        _periods = [];
      }

      if (!mounted) return;
      setState(() {
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


  void _showNotificationsDialog(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accentBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_outlined, color: accentBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Bildirimler',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            if (_unreadNotificationsCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentBlue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_unreadNotificationsCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: Icon(Icons.close, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: _notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 48, color: textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'Okunmamış bildiriminiz bulunmuyor.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            shrinkWrap: true,
                            itemCount: _notifications.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final item = _notifications[index];
                              return InkWell(
                                onTap: () async {
                                  await _notificationService.markAsRead(item.id);
                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                  }
                                  await _fetchTenantData();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: item.isRead
                                        ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                                        : (isDark
                                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                                            : const Color(0xFFEFF6FF)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: item.isRead
                                          ? cardBorderColor
                                          : accentBlue.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentBlue.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.info_outline, color: accentBlue, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.message,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: textSecondary,
                                              ),
                                            ),
                                            if (item.createdAt != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                '${item.createdAt!.day.toString().padLeft(2, '0')}.${item.createdAt!.month.toString().padLeft(2, '0')}.${item.createdAt!.year} ${item.createdAt!.hour.toString().padLeft(2, '0')}:${item.createdAt!.minute.toString().padLeft(2, '0')}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onUploadReceipt(RentPeriod period) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() => _uploadingPeriodId = period.id);

      try {
        await _rentPeriodService.uploadReceipt(period.id, file);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dekont başarıyla yüklendi! Ev sahibi onayı bekleniyor.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchTenantData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _uploadingPeriodId = null);
      }
    }
  }

  Future<void> _activateLease() async {
    if (_activeLease == null) return;
    setState(() => _isActivatingLease = true);

    try {
      await _leaseService.activateLease(_activeLease!.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sözleşme başarıyla onaylandı!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchTenantData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActivatingLease = false);
    }
  }

  void _showReceiptViewer(RentPeriod period) {
    final rawUrl = period.receiptImageUrl ?? '';
    if (rawUrl.isEmpty) return;

    final String fullImageUrl;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      fullImageUrl = rawUrl;
    } else {
      final prefix = rawUrl.startsWith('/') ? '' : '/';
      fullImageUrl = '${ApiConstants.baseUrl}$prefix$rawUrl';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ödeme Dekontu',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 380),
                      color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.04),
                      child: Image.network(
                        fullImageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          final total = loadingProgress.expectedTotalBytes;
                          final loaded = loadingProgress.cumulativeBytesLoaded;
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: total != null ? loaded / total : null,
                              color: accentBlue,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 160,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Görsel yüklenemedi',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatMonthYear(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatEndDate(String startStr) {
    try {
      final dt = DateTime.parse(startStr);
      final endDt = DateTime(dt.year + 1, dt.month, dt.day);
      return '${endDt.day.toString().padLeft(2, '0')}.${endDt.month.toString().padLeft(2, '0')}.${endDt.year}';
    } catch (_) {
      return '1 Yıl';
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required String badgeText,
    required Color badgeBg,
    required Color badgeTextColor,
    required IconData icon,
    bool isPrimary = false,
    required bool isDark,
  }) {
    final cardBg = isPrimary
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFF1E50CE))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final cardBorder = isPrimary
        ? accentBlue.withValues(alpha: 0.5)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final titleColor = isPrimary
        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFFDBEAFE))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    final amountColor = isPrimary
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final iconColor = isPrimary
        ? (isDark ? accentBlue : Colors.white70)
        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? (isDark
                    ? vibrantBlue.withValues(alpha: 0.25)
                    : const Color(0xFF1E50CE).withValues(alpha: 0.3))
                : (isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05)),
            blurRadius: isPrimary ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  amount,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContractCard(Lease lease, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final propTitle = lease.propertyName ?? 'Kadıköy Dairesi';
    final propAddr = lease.propertyAddress ?? 'Moda Cad. No: 12 Kadıköy / İstanbul';
    final rentStr = '${lease.rentAmount.toStringAsFixed(0)} TL';
    final endStr = _formatEndDate(lease.startDate);

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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: accentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kira Sözleşmesi',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      propTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  'Aktif',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 18),
          Row(
            children: [
              // Monthly Rent
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aylık Kira',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rentStr,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Contract End Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sözleşme Bitiş',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endStr,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  propAddr,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLeaseCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.vpn_key_outlined,
              color: accentBlue,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Aktif Sözleşmeniz Yok',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ev sahibiniz kiraZ kullanıyorsa, size ilettiği davet kodunu girerek kiraladığınız mülke ve sözleşmenize otomatik olarak bağlanabilirsiniz.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InviteCodeScreen(),
                ),
              ).then((_) => _fetchTenantData());
            },
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: const Text('Davet Kodu Gir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vibrantBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<RentPeriod> get _filteredPeriods {
    switch (_selectedTabIndex) {
      case 1:
        // PAID
        return _periods.where((p) {
          final s = p.status.toUpperCase();
          return s == 'PAID' || s == 'ÖDENDİ';
        }).toList();
      case 2:
        // OVERDUE or REJECTED
        return _periods.where((p) {
          final s = p.status.toUpperCase();
          return s == 'OVERDUE' ||
              s == 'GECİKTİ' ||
              s == 'GECİKEN' ||
              s == 'REJECTED' ||
              s == 'REDDEDİLDİ';
        }).toList();
      case 3:
        // PENDING with receipt uploaded (Awaiting landlord approval)
        return _periods.where((p) {
          final s = p.status.toUpperCase();
          final isPending = s == 'PENDING' ||
              s == 'BEKLİYOR' ||
              s == 'BEKLEMEDE' ||
              s == 'ONAY BEKLİYOR';
          final hasReceipt = p.receiptImageUrl != null && p.receiptImageUrl!.trim().isNotEmpty;
          return isPending && hasReceipt;
        }).toList();
      case 0:
      default:
        final now = DateTime.now();
        final threshold = now.add(const Duration(days: 15));
        return _periods.where((p) {
          final s = p.status.toUpperCase();
          final isPaid = s == 'PAID' || s == 'ÖDENDİ';
          final isOverdueOrRejected = s == 'OVERDUE' ||
              s == 'GECİKTİ' ||
              s == 'GECİKEN' ||
              s == 'REJECTED' ||
              s == 'REDDEDİLDİ';
          final hasReceipt = p.receiptImageUrl != null && p.receiptImageUrl!.trim().isNotEmpty;

          if (isPaid || isOverdueOrRejected) {
            return true;
          }

          final isPending = s == 'PENDING' ||
              s == 'BEKLİYOR' ||
              s == 'BEKLEMEDE' ||
              s == 'ONAY BEKLİYOR';

          if (isPending) {
            if (hasReceipt) {
              return true;
            }
            try {
              final startDt = DateTime.parse(p.periodStart);
              return startDt.isBefore(threshold);
            } catch (_) {
              return true;
            }
          }

          return false;
        }).toList();
    }
  }

  String _getSubtitleText(RentPeriod period) {
    final s = period.status.toUpperCase();
    final isPaid = s == 'PAID' || s == 'ÖDENDİ';
    final isOverdueOrRejected = s == 'OVERDUE' ||
        s == 'GECİKTİ' ||
        s == 'GECİKEN' ||
        s == 'REJECTED' ||
        s == 'REDDEDİLDİ';
    final hasReceipt = period.receiptImageUrl != null && period.receiptImageUrl!.trim().isNotEmpty;

    if (isPaid) {
      return 'Kira ödemesi başarıyla tamamlanmıştır.';
    } else if (isOverdueOrRejected) {
      final dueDate = period.paymentDate ?? period.periodEnd;
      return 'Kira ödemesi gecikmiştir. (Son ödeme tarihi: $dueDate)';
    } else if (hasReceipt) {
      return 'Dekont yüklendi, ev sahibinin onayı bekleniyor.';
    } else {
      return 'Ödeme dönemi aktif, dekont yüklenmesi bekleniyor.';
    }
  }

  Widget _buildPeriodTile(RentPeriod period, bool isDark) {
    final statusUpper = period.status.toUpperCase();
    final isPaid = statusUpper == 'PAID' || statusUpper == 'ÖDENDİ';
    final isOverdue = statusUpper == 'OVERDUE' ||
        statusUpper == 'GECİKTİ' ||
        statusUpper == 'GECİKEN' ||
        statusUpper == 'REJECTED' ||
        statusUpper == 'REDDEDİLDİ';
    final hasReceipt = period.receiptImageUrl != null && period.receiptImageUrl!.trim().isNotEmpty;
    final isPendingApproval = !isPaid && hasReceipt;
    final isUploading = _uploadingPeriodId == period.id;

    final monthTitle = _formatMonthYear(period.periodStart);
    final rentAmountStr = _activeLease != null
        ? '${_activeLease!.rentAmount.toStringAsFixed(0)} TL'
        : '15.000 TL';

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Date Badge Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPaid
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                  : (isOverdue
                      ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                      : (isPendingApproval
                          ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)))),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPaid
                    ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                    : (isOverdue
                        ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA))
                        : (isPendingApproval
                            ? (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A))
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)))),
              ),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : (isOverdue
                      ? Icons.warning_amber_rounded
                      : (isPendingApproval
                          ? Icons.hourglass_bottom_rounded
                          : Icons.calendar_today_rounded)),
              color: isPaid
                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                  : (isOverdue
                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                      : (isPendingApproval
                          ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                          : (isDark ? accentBlue : const Color(0xFF1E50CE)))),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Period Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rentAmountStr,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSubtitleText(period),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: subtitleColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action / Status Badge & Buttons
          if (isPaid) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ödendi',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasReceipt) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showReceiptViewer(period),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14),
                    label: Text(
                      'Dekontu Gör',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? accentBlue : const Color(0xFF1E50CE),
                      side: BorderSide(
                        color: isDark ? accentBlue : const Color(0xFF1E50CE),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status badge
                if (isOverdue) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Text(
                      'Gecikti',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ] else if (isPendingApproval) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      'Onay Bekliyor',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      'Bekliyor',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],

                // Dekontu Gör Button
                if (hasReceipt) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showReceiptViewer(period),
                    icon: const Icon(Icons.receipt_long_rounded, size: 14),
                    label: Text(
                      'Dekontu Gör',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? accentBlue : const Color(0xFF1E50CE),
                      side: BorderSide(
                        color: isDark ? accentBlue : const Color(0xFF1E50CE),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],

                // Dekont Yükle Button (appears for unpaid/pending periods without a receipt)
                if (!hasReceipt) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: isUploading ? null : () => _onUploadReceipt(period),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: vibrantBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Dekont Yükle',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingLeaseWarningCard(bool isDark) {
    const orangeBorder = Color(0xFFF59E0B);
    final orangeBg = isDark ? const Color(0xFF26190B) : const Color(0xFFFFFBEB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF78350F);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF92400E);
    final innerBoxBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final innerBorder = isDark ? const Color(0xFF475569) : const Color(0xFFFDE68A);

    final propName = _activeLease?.propertyName ?? 'Atanan Mülk';
    final rentStr = _activeLease != null ? '${_activeLease!.rentAmount.toStringAsFixed(0)} TL' : '-';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: orangeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: orangeBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: orangeBorder.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: orangeBorder.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: orangeBorder,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sözleşme Onayı Bekleniyor',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Ev sahibiniz sizi bir mülke atadı. Devam etmek için sözleşmenizi onaylamanız gerekmektedir.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: innerBoxBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: innerBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: orangeBorder, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        propName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Aylık Kira: $rentStr',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isActivatingLease ? null : _activateLease,
              icon: _isActivatingLease
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                'Sözleşmeyi Onayla',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: orangeBorder,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final isLeasePending = _activeLease != null &&
        (_activeLease!.status?.toUpperCase() == 'PENDING' ||
            _activeLease!.status?.toUpperCase() == 'BEKLEMEDE' ||
            _activeLease!.status?.toUpperCase() == 'ONAY BEKLİYOR');

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
          Badge(
            isLabelVisible: _unreadNotificationsCount > 0,
            label: Text('$_unreadNotificationsCount'),
            child: IconButton(
              tooltip: 'Bildirimler',
              icon: Icon(
                Icons.notifications,
                color: _unreadNotificationsCount > 0 ? Colors.red : null,
              ),
              onPressed: () => _showNotificationsDialog(isDark),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: (_isLoading || (_stats == null && _errorMessage == null))
          ? const Center(
              child: CircularProgressIndicator(color: accentBlue),
            )
          : RefreshIndicator(
              color: accentBlue,
              backgroundColor: cardBg,
              onRefresh: _fetchTenantData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting Header
                    Text(
                      'İyi Akşamlar, ${_userName.isNotEmpty ? _userName : "Kiracı"}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kira ödemeleriniz ve sözleşme durumunuz',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDC2626)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _fetchTenantData,
                              child: const Text('Tekrar Dene', style: TextStyle(color: accentBlue)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Enforce PENDING State or Normal Dashboard
                    if (isLeasePending) ...[
                      _buildPendingLeaseWarningCard(isDark),
                    ] else ...[
                      // 4 Summary Cards Grid
                      if (_stats != null)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.25,
                          children: [
                            _buildSummaryCard(
                              title: 'Ödenen Kira',
                              amount: '${_stats!.totalPaid.toStringAsFixed(0)} TL',
                              badgeText: 'Toplam',
                              badgeBg: isDark ? const Color(0xFF064E3B) : const Color(0xFF047857),
                              badgeTextColor: Colors.white,
                              icon: Icons.check_circle_outline_rounded,
                              isPrimary: true,
                              isDark: isDark,
                            ),
                            _buildSummaryCard(
                              title: 'Sıradaki Ödeme',
                              amount: '${_stats!.upcoming.toStringAsFixed(0)} TL',
                              badgeText: 'Bu Ay',
                              badgeBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                              badgeTextColor: isDark ? accentBlue : const Color(0xFF1E50CE),
                              icon: Icons.schedule_rounded,
                              isDark: isDark,
                            ),
                            _buildSummaryCard(
                              title: 'Toplam Borç',
                              amount: '${(_stats!.upcoming + _stats!.overdue).toStringAsFixed(0)} TL',
                              badgeText: 'Aktif',
                              badgeBg: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              badgeTextColor: textSecondary,
                              icon: Icons.receipt_long_rounded,
                              isDark: isDark,
                            ),
                            _buildSummaryCard(
                              title: 'Geciken Borç',
                              amount: '${_stats!.overdue.toStringAsFixed(0)} TL',
                              badgeText: 'Geciken',
                              badgeBg: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                              badgeTextColor: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                              icon: Icons.warning_amber_rounded,
                              isDark: isDark,
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // Contract Card
                      if (_activeLease != null)
                        _buildContractCard(_activeLease!, isDark)
                      else
                        _buildEmptyLeaseCard(isDark),

                      const SizedBox(height: 28),

                      // Payment Flow Header (Kiracı Ödeme Akışı)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kiracı Ödeme Akışı',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          if (_activeLease != null && _periods.isNotEmpty)
                            Text(
                              '${_periods.length} Dönem',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Horizontal Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            {'label': 'Tümü', 'index': 0},
                            {'label': 'Ödenen', 'index': 1},
                            {'label': 'Geciken', 'index': 2},
                            {'label': 'Bekleyen', 'index': 3},
                          ].map((tabItem) {
                            final idx = tabItem['index'] as int;
                            final label = tabItem['label'] as String;
                            final isSelected = _selectedTabIndex == idx;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _selectedTabIndex = idx);
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? accentBlue.withValues(alpha: 0.15)
                                      : cardBg,
                                  foregroundColor: isSelected
                                      ? (isDark ? accentBlue : const Color(0xFF1E50CE))
                                      : textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? (isDark ? accentBlue : const Color(0xFF1E50CE))
                                          : cardBorder,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rent Periods List
                      if (_filteredPeriods.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 40,
                                  color: textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _activeLease == null
                                      ? 'Sözleşme bulunamadığı için ödeme dönemi listelenemiyor.'
                                      : 'Bu filtreye uygun ödeme dönemi bulunamadı.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredPeriods.length,
                          itemBuilder: (context, index) {
                            return _buildPeriodTile(_filteredPeriods[index], isDark);
                          },
                        ),

                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
