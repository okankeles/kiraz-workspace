import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../models/dashboard_stats.dart';
import '../../models/notification_model.dart';
import '../../models/pending_approval_item.dart';
import '../../services/dashboard_service.dart';
import '../../services/lease_service.dart';
import '../../services/notification_service.dart';
import '../../services/rent_period_service.dart';
import '../../utils/constants.dart';
import '../../widgets/cherry_logo.dart';
import '../tenant/rent_period_list_screen.dart';

class LandlordDashboardScreen extends StatefulWidget {
  const LandlordDashboardScreen({super.key});

  @override
  State<LandlordDashboardScreen> createState() => _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color cardBorder = Color(0xFFE5E0D8);
  static const Color darkCardBorder = Color(0xFF334155);

  final DashboardService _dashboardService = DashboardService();
  final LeaseService _leaseService = LeaseService();
  final NotificationService _notificationService = NotificationService();
  final RentPeriodService _rentPeriodService = RentPeriodService();

  String _userName = '';
  DashboardStats? _stats;
  List<AppNotification> _notifications = [];
  int _unreadNotificationsCount = 0;
  List<PendingApprovalItem> _pendingApprovals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLandlordData();
  }

  Future<void> _fetchLandlordData() async {
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('fullName') ?? 'Ev Sahibi';
      final userId = prefs.getInt('userId');

      if (userId != null) {
        final results = await Future.wait([
          _dashboardService.getLandlordStats(userId),
          _notificationService.getUnreadNotifications(userId),
          _rentPeriodService.getPendingApprovalsForLandlord(userId),
        ]);

        if (!mounted) return;
        setState(() {
          _stats = results[0] as DashboardStats;
          _notifications = results[1] as List<AppNotification>;
          _unreadNotificationsCount = _notifications.length;
          _pendingApprovals = results[2] as List<PendingApprovalItem>;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }


  void _showNotificationsDialog(bool isDark) {
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

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
                                color: vibrantBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_outlined, color: vibrantBlue, size: 20),
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
                                  color: vibrantBlue,
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
                                  if (item.type == 'RECEIPT' && item.referenceId != null) {
                                    try {
                                      final lease = await _leaseService.getLeaseById(item.referenceId!);
                                      if (mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RentPeriodListScreen(lease: lease),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Bildirim yönlendirme hatası: $e');
                                    }
                                  }
                                  await _fetchLandlordData();
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
                                          : vibrantBlue.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: vibrantBlue.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.info_outline, color: vibrantBlue, size: 18),
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
    final bgColor = isPrimary
        ? vibrantBlue
        : (isDark ? darkCardBg : Colors.white);
    final primaryTextColor = isPrimary
        ? Colors.white
        : (isDark ? Colors.white : darkNavy);
    final secondaryTextColor = isPrimary
        ? Colors.white.withValues(alpha: 0.85)
        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600);
    final borderColor = isPrimary
        ? Colors.transparent
        : (isDark ? darkCardBorder : cardBorder);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: vibrantBlue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
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
                    color: secondaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  amount,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Icon(
                icon,
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.75)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaskAlertCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DASK Poliçesi Hatırlatması',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : darkNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kadıköy Dairesi Sigortası',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Text(
                  'Bitişe 15 gün kaldı',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Poliçenizi süresi dolmadan yenileyin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('DASK Poliçe Yenileme ekranı yakında açılacaktır.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: vibrantBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Yenile',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog(PendingApprovalItem item) {
    final rawUrl = item.period.receiptImageUrl ?? '';
    if (rawUrl.isEmpty) return;

    final String fullImageUrl;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      fullImageUrl = rawUrl;
    } else {
      final prefix = rawUrl.startsWith('/') ? '' : '/';
      fullImageUrl = '${ApiConstants.baseUrl}$prefix$rawUrl';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPdf = rawUrl.toLowerCase().endsWith('.pdf');
    bool isApproving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContentContext, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kira Dekontu Onayı',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.propertyName} • ${item.tenantName}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ödeme Tutarı:',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '${item.amount.toStringAsFixed(0)} TL',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 340),
                          color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.04),
                        child: isPdf
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf,
                                        size: 52,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'PDF Formatında Dekont',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Dekont belgesini cihazınızda görüntüleyin veya indirin.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          final uri = Uri.parse(fullImageUrl);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } else {
                                            await launchUrl(uri);
                                          }
                                        } catch (e) {
                                          if (!dialogContext.mounted) return;
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                              content: Text('Dosya açılamadı: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.open_in_new, size: 18),
                                      label: const Text('PDF Olarak İndir/Görüntüle'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: vibrantBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.network(
                                fullImageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                            : null,
                                        color: vibrantBlue,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 160,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Dekont görseli yüklenemedi',
                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isApproving ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Kapat'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton(
                              onPressed: isApproving
                                  ? null
                                  : () async {
                                      setDialogState(() => isApproving = true);
                                      try {
                                        await RentPeriodService().updateStatus(item.period.id, 'REJECTED');
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Dekont reddedildi'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        await _fetchLandlordData();
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          setDialogState(() => isApproving = false);
                                        }
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Hata: $e'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Reddet',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isApproving
                                  ? null
                                  : () async {
                                      setDialogState(() => isApproving = true);
                                      try {
                                        await _rentPeriodService.updatePeriodStatus(item.period.id, 'PAID');
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Kira ödemesi başarıyla onaylandı!'),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        await _loadDashboardData();
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          setDialogState(() => isApproving = false);
                                        }
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Hata: $e'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              icon: isApproving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_circle_outline, size: 20),
                              label: Text(
                                isApproving ? 'Onaylanıyor...' : 'Ödemeyi Onayla',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingApprovalsSection(bool isDark) {
    final textColor = isDark ? Colors.white : darkNavy;
    final cardBg = isDark ? darkCardBg : Colors.white;
    final borderColor = isDark ? darkCardBorder : cardBorder;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Onay Bekleyen Dekontlar',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (_pendingApprovals.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pendingApprovals.length}',
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
          ],
        ),
        const SizedBox(height: 12),
        if (_pendingApprovals.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Onay bekleyen kira dekontu bulunmuyor.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingApprovals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _pendingApprovals[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.home_work_outlined, size: 18, color: vibrantBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.propertyName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Dekont Yüklendi',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          item.tenantName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ödeme Tutarı',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.amount.toStringAsFixed(0)} TL',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showReceiptDialog(item),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Dekontu Gör'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vibrantBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final textColor = isDark ? Colors.white : darkNavy;

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
            const SizedBox(width: 8),
            Text(
              'kiraZ',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: textColor,
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
              color: textColor,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: vibrantBlue),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: vibrantBlue,
              backgroundColor: isDark ? darkCardBg : Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting Text
                    Text(
                      'İyi Akşamlar, ${_userName.isNotEmpty ? _userName : "Ev Sahibi"}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mülklerinizin güncel finansal ve operasyonel durumu',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                                  color: textColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadDashboardData,
                              child: const Text('Tekrar Dene', style: TextStyle(color: vibrantBlue)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // 4 Summary Cards Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.25,
                      children: [
                        // 1. Tahsil Edilen (Blue background, white text)
                        _buildSummaryCard(
                          title: 'Tahsil Edilen',
                          amount: '${(_stats?.totalPaid ?? 0).toStringAsFixed(0)} TL',
                          badgeText: 'Toplam',
                          badgeBg: Colors.white.withValues(alpha: 0.2),
                          badgeTextColor: Colors.white,
                          icon: Icons.check_circle_outline,
                          isPrimary: true,
                          isDark: isDark,
                        ),

                        // 2. Yaklaşan (White background)
                        _buildSummaryCard(
                          title: 'Yaklaşan',
                          amount: '${(_stats?.upcoming ?? 0).toStringAsFixed(0)} TL',
                          badgeText: 'Bu Ay',
                          badgeBg: isDark
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFFEFF6FF),
                          badgeTextColor: vibrantBlue,
                          icon: Icons.calendar_today_outlined,
                          isPrimary: false,
                          isDark: isDark,
                        ),

                        // 3. Bekleyen Onay (White background)
                        _buildSummaryCard(
                          title: 'Bekleyen Onay',
                          amount: '${(_stats?.pendingApproval ?? 0).toStringAsFixed(0)} TL',
                          badgeText: 'Dekont',
                          badgeBg: isDark
                              ? const Color(0xFF78350F)
                              : const Color(0xFFFEF3C7),
                          badgeTextColor: const Color(0xFFD97706),
                          icon: Icons.receipt_long_outlined,
                          isPrimary: false,
                          isDark: isDark,
                        ),

                        // 4. Geciken Alacak (White background)
                        _buildSummaryCard(
                          title: 'Geciken Alacak',
                          amount: '${(_stats?.overdue ?? 0).toStringAsFixed(0)} TL',
                          badgeText: 'Geciken',
                          badgeBg: isDark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFEE2E2),
                          badgeTextColor: const Color(0xFFDC2626),
                          icon: Icons.warning_amber_rounded,
                          isPrimary: false,
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // DASK Policy Alert Card
                    _buildDaskAlertCard(isDark),

                    const SizedBox(height: 24),

                    // Onay Bekleyen Dekontlar
                    _buildPendingApprovalsSection(isDark),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
