import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/lease.dart';
import '../../models/payment_summary.dart';
import '../../models/rent_period.dart';
import '../../services/lease_service.dart';
import '../../services/payment_service.dart';
import '../../services/rent_period_service.dart';
import '../../utils/constants.dart';
import 'eft_payment_screen.dart';
import 'paytr_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  final PaymentService _paymentService = PaymentService();
  final RentPeriodService _rentPeriodService = RentPeriodService();
  final LeaseService _leaseService = LeaseService();

  PaymentSummary? _summary;
  List<RentPeriod> _periods = [];
  Lease? _activeLease;
  bool _isLoading = true;
  String? _errorMessage;
  int? _payingPeriodId;

  @override
  void initState() {
    super.initState();
    _loadAllPaymentData();
  }

  Future<void> _loadAllPaymentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Oturum bilgisi bulunamadı. Lütfen tekrar giriş yapınız.';
        });
        return;
      }

      // 1. Finansal Özeti Çek (GET /api/payments/summary)
      PaymentSummary? summary;
      try {
        summary = await _paymentService.getPaymentSummary(tenantId: userId);
      } catch (e) {
        debugPrint('Finansal özet çekilirken hata: $e');
      }

      // 2. Kiracının Sözleşmesini ve Kira Periyotlarını Çek
      List<RentPeriod> periods = [];
      Lease? lease;
      try {
        final leases = await _leaseService.getLeasesForTenant(userId);
        if (leases.isNotEmpty) {
          lease = leases.first;
          final fetchedPeriods = await _rentPeriodService.getPeriodsForLease(lease.id);
          periods = fetchedPeriods.map((p) {
            if (p.expectedAmount <= 0 && lease!.rentAmount > 0) {
              return p.copyWith(expectedAmount: lease.rentAmount);
            }
            return p;
          }).toList();
        }
      } catch (e) {
        debugPrint('Kira periyotları çekilirken hata: $e');
      }

      // Eğer summary servisi henüz backend'de veri üretmemişse dinamik özet oluştur (fallback)
      if (summary == null) {
        double calcDebt = 0;
        double calcPaid = 0;
        String? nextDate;
        double nextAmount = 0;

        for (final p in periods) {
          final amt = p.expectedAmount > 0 ? p.expectedAmount : (lease?.rentAmount ?? 0);
          if (p.isPaid) {
            calcPaid += amt;
          } else {
            calcDebt += amt;
            if (nextDate == null && p.periodStartFormatted.isNotEmpty) {
              nextDate = p.periodStartFormatted;
              nextAmount = amt;
            }
          }
        }

        summary = PaymentSummary(
          totalDebt: calcDebt,
          totalPaid: calcPaid,
          nextPaymentDate: nextDate,
          nextPaymentAmount: nextAmount,
        );
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _activeLease = lease;
        _periods = periods;
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

  // --- Filtrelenmiş Periyot Listeleri ---

  /// Sekme 1: Ödeme Geçmişi (Statüsü PAID, OVERDUE, WAITING_APPROVAL, IN_LEGAL_PROCESS olanlar)
  List<RentPeriod> get _historyPeriods {
    final list = _periods.where((p) {
      final s = p.status.toUpperCase();
      final isWaiting = p.isWaitingApproval ||
          s == 'WAITING_APPROVAL' ||
          s == 'ONAY BEKLİYOR' ||
          (p.receiptImageUrl != null && p.receiptImageUrl!.trim().isNotEmpty);
      return p.isPaid || p.isOverdue || isWaiting || p.isInLegalProcess;
    }).toList();

    // Tarihe göre ters kronolojik (en yeni dönem en üstte)
    list.sort((a, b) {
      final aDate = a.periodStart ?? DateTime(1970);
      final bDate = b.periodStart ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  /// Sekme 2: Ödeme Planı (Statüsü PENDING olan, vadesi gelmemiş gelecek dönemler)
  List<RentPeriod> get _planPeriods {
    final list = _periods.where((p) {
      final s = p.status.toUpperCase();
      final isWaiting = p.isWaitingApproval ||
          s == 'WAITING_APPROVAL' ||
          s == 'ONAY BEKLİYOR' ||
          (p.receiptImageUrl != null && p.receiptImageUrl!.trim().isNotEmpty);
      return !p.isPaid && !p.isOverdue && !isWaiting && !p.isInLegalProcess;
    }).toList();

    // Vade tarihine göre kronolojik (en yakın dönem en üstte)
    list.sort((a, b) {
      final aDate = a.periodStart ?? DateTime(2099);
      final bDate = b.periodStart ?? DateTime(2099);
      return aDate.compareTo(bDate);
    });
    return list;
  }

  // --- Ödeme Akışları & Bottom Sheet ---

  /// Modern Bottom Sheet: Ödeme Yöntemi Seçimi
  void _openPaymentOptionsBottomSheet(RentPeriod period) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;

    final amountStr = period.expectedAmount > 0
        ? '₺${_formatAmount(period.expectedAmount)}'
        : (_activeLease != null ? '₺${_formatAmount(_activeLease!.rentAmount)}' : '₺15.000');

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık & Kapat İkonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ödeme Yöntemi Seçin',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatMonthTitle(period.periodStart)} Kira Dönemi • $amountStr',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: vibrantBlue,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Seçenek A: Kredi Kartı ile Öde
              _buildPaymentOptionTile(
                isDark: isDark,
                icon: Icons.credit_card_rounded,
                iconBg: vibrantBlue.withValues(alpha: 0.12),
                iconColor: vibrantBlue,
                title: 'Kredi Kartı ile Öde',
                subtitle: 'PayTR 3D Secure ile anında güvenli ödeme (Tek çekim / Taksit)',
                badgeText: 'Anında Onay',
                badgeColor: Colors.green,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _payWithCard(period);
                },
              ),
              const SizedBox(height: 12),

              // Seçenek B: Havale / EFT ile Öde
              _buildPaymentOptionTile(
                isDark: isDark,
                icon: Icons.account_balance_rounded,
                iconBg: Colors.amber.withValues(alpha: 0.15),
                iconColor: const Color(0xFFD97706),
                title: 'Havale / EFT ile Öde',
                subtitle: 'Banka IBAN hesabına transfer yapın ve dekont yükleyin',
                badgeText: 'Komisyonsuz',
                badgeColor: vibrantBlue,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _payWithEft(period);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final cardBorder = isDark ? const Color(0xFF334155) : subtleBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// Kredi Kartı Akışı (PayTR)
  Future<void> _payWithCard(RentPeriod period) async {
    setState(() => _payingPeriodId = period.id);

    try {
      final token = await _paymentService.initializePayment(period.id);

      if (!mounted) return;
      setState(() => _payingPeriodId = null);

      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PayTrPaymentScreen(
            token: token,
            title: '${_formatMonthTitle(period.periodStart)} Kira Ödemesi',
          ),
        ),
      );

      if (!mounted) return;

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ödeme başarıyla tamamlandı! Finansal özetiniz güncellendi.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadAllPaymentData();
      } else if (success == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ödeme işlemi tamamlanamadı veya iptal edildi.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _payingPeriodId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ödeme başlatılamadı: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Havale / EFT Akışı
  Future<void> _payWithEft(RentPeriod period) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EftPaymentScreen(
          period: period,
          lease: _activeLease,
        ),
      ),
    );

    if (!mounted) return;

    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dekontunuz iletildi! Kira durumu "Onay Bekliyor" olarak güncellendi.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      _loadAllPaymentData();
    }
  }

  void _onViewReceipt(RentPeriod period) {
    if (period.receiptImageUrl == null || period.receiptImageUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu döneme ait kayıtlı dekont belgesi bulunmuyor.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String url = period.receiptImageUrl!.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final prefix = url.startsWith('/') ? '' : '/';
      url = '${ApiConstants.baseUrl}$prefix$url';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: vibrantBlue, size: 22),
            const SizedBox(width: 8),
            Text(
              'Ödeme Dekontu',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_formatMonthTitle(period.periodStart)} dönemine ait ödeme belgesi:',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Dekont Belgesini Aç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: vibrantBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final rounded = amount.toStringAsFixed(0);
    return rounded.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatTurkishDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return 'Planlanan ödeme yok';
    }
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = int.tryParse(parts[1]) ?? 1;
        final day = int.tryParse(parts[2]) ?? 1;
        const months = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        final monthName = (month >= 1 && month <= 12) ? months[month - 1] : '$month';
        return '$day $monthName $year';
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatMonthTitle(DateTime? date) {
    if (date == null) return 'Kira Dönemi';
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    final monthName = (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '${date.month}';
    return '$monthName ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final textPrimary = isDark ? Colors.white : darkNavy;

    final historyList = _historyPeriods;
    final planList = _planPeriods;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ödemelerim',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: textPrimary,
              ),
            ),
            Text(
              'Finansal durum ve kira hareketleriniz',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton(isDark)
          : _errorMessage != null
              ? _buildErrorView(isDark)
              : DefaultTabController(
                  length: 2,
                  child: RefreshIndicator(
                    onRefresh: _loadAllPaymentData,
                    color: vibrantBlue,
                    child: NestedScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          // 1. Üst Özet Kartları
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: _buildSummaryDashboard(isDark),
                            ),
                          ),
                          // 2. Sekmeler (TabBar - Pinned)
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverTabBarDelegate(
                              tabBar: TabBar(
                                indicator: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: vibrantBlue,
                                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.history_rounded, size: 17),
                                        const SizedBox(width: 6),
                                        const Text('Ödeme Geçmişi'),
                                        if (historyList.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          _buildCountBadge(historyList.length, isDark),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.calendar_month_rounded, size: 17),
                                        const SizedBox(width: 6),
                                        const Text('Ödeme Planı'),
                                        if (planList.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          _buildCountBadge(planList.length, isDark),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: scaffoldBg,
                            ),
                          ),
                        ];
                      },
                      // 3. Sekme İçerikleri (TabBarView)
                      body: TabBarView(
                        children: [
                          // Sekme 1: Ödeme Geçmişi
                          _buildHistoryTab(historyList, isDark),
                          // Sekme 2: Ödeme Planı (Timeline)
                          _buildPlanTab(planList, isDark),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildCountBadge(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: vibrantBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: vibrantBlue,
        ),
      ),
    );
  }

  // --- Üst Finansal Özet Kartları ---
  Widget _buildSummaryDashboard(bool isDark) {
    final summary = _summary ??
        PaymentSummary(
          totalDebt: 0,
          totalPaid: 0,
          nextPaymentDate: null,
          nextPaymentAmount: 0,
        );

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Column(
      children: [
        // 1. ve 2. Kart Yan Yana
        Row(
          children: [
            // Kart 1: Toplam Borç (Kırmızı Tonlarda)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D1517) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.05),
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
                        Text(
                          'Toplam Borç',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFFE11D48) : Colors.red.shade600)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₺${_formatAmount(summary.totalDebt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF881337),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.totalDebt > 0 ? 'Ödenmesi gereken borç' : 'Tüm ödemeler güncel',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Kart 2: Toplam Ödenen (Yeşil Tonlarda)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.05),
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
                        Text(
                          'Toplam Ödenen',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF10B981) : Colors.green.shade600)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₺${_formatAmount(summary.totalPaid)}',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF064E3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kira hareketleri toplamı',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Kart 3: Sıradaki Ödeme (Geniş Yatay Kart)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : subtleBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: vibrantBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: vibrantBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: vibrantBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sıradaki Ödeme',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTurkishDate(summary.nextPaymentDate),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Tutar',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.nextPaymentAmount > 0
                        ? '₺${_formatAmount(summary.nextPaymentAmount)}'
                        : (_activeLease != null ? '₺${_formatAmount(_activeLease!.rentAmount)}' : '₺0'),
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: vibrantBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SEKME 1: Ödeme Geçmişi Listesi ---
  Widget _buildHistoryTab(List<RentPeriod> periods, bool isDark) {
    if (periods.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildEmptyState(
          isDark: isDark,
          icon: Icons.history_rounded,
          title: 'Henüz Ödeme Geçmişi Bulunmuyor',
          subtitle: 'Tamamlanan kira ödemeleriniz, onay bekleyen işlemleriniz ve geciken dönemler burada listelenecektir.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        return _buildHistoryPeriodCard(period, isDark);
      },
    );
  }

  Widget _buildHistoryPeriodCard(RentPeriod period, bool isDark) {
    final isPaid = period.isPaid;
    final isOverdue = period.isOverdue;
    final isWaiting = period.isWaitingApproval;
    final isLegal = period.isInLegalProcess;
    final hasReceipt = period.receiptImageUrl != null && period.receiptImageUrl!.trim().isNotEmpty;
    final isPaying = _payingPeriodId == period.id;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : subtleBorder;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final amountStr = period.expectedAmount > 0
        ? '₺${_formatAmount(period.expectedAmount)}'
        : (_activeLease != null ? '₺${_formatAmount(_activeLease!.rentAmount)}' : '₺15.000');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol İkon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isPaid
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                      : isWaiting
                          ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                          : isOverdue
                              ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : isWaiting
                          ? Icons.hourglass_top_rounded
                          : isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.access_time_rounded,
                  color: isPaid
                      ? const Color(0xFF10B981)
                      : isWaiting
                          ? const Color(0xFFD97706)
                          : isOverdue
                              ? const Color(0xFFEF4444)
                              : vibrantBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Dönem ve Tutar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMonthTitle(period.periodStart),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amountStr,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vade: ${_formatTurkishDate(period.periodStartFormatted)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Durum Rozeti
              if (isLegal) ...[
                _buildStatusBadge(
                  label: 'Hukuki Süreçte',
                  icon: Icons.gavel_rounded,
                  bgColor: isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2),
                  borderColor: const Color(0xFF881337),
                  textColor: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF881337),
                ),
              ] else if (isWaiting) ...[
                // Sarı Rozet: Onay Bekliyor (WAITING_APPROVAL)
                _buildStatusBadge(
                  label: 'Onay Bekliyor',
                  icon: Icons.hourglass_top_rounded,
                  bgColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                  borderColor: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
                  textColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                ),
              ] else if (isPaid) ...[
                _buildStatusBadge(
                  label: 'Ödendi',
                  icon: Icons.check_rounded,
                  bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                  borderColor: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                  textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
              ] else if (isOverdue) ...[
                _buildStatusBadge(
                  label: 'Gecikmede',
                  icon: Icons.warning_amber_rounded,
                  bgColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                  borderColor: isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA),
                  textColor: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                ),
              ],
            ],
          ),

          // Alt Aksiyon Butonları
          if (isPaid || hasReceipt) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _onViewReceipt(period),
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: Text(
                'Dekontu Gör',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? accentBlue : vibrantBlue,
                side: BorderSide(color: isDark ? accentBlue : vibrantBlue),
                minimumSize: const Size(double.infinity, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else if (isOverdue && !isWaiting) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isPaying ? null : () => _openPaymentOptionsBottomSheet(period),
              icon: isPaying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.payment_rounded, size: 18),
              label: Text(
                isPaying ? 'Bağlanıyor...' : 'Ödeme Yap',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: vibrantBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- SEKME 2: Ödeme Planı (Takvim / Timeline Görünümü) ---
  Widget _buildPlanTab(List<RentPeriod> periods, bool isDark) {
    if (periods.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildEmptyState(
          isDark: isDark,
          icon: Icons.event_available_rounded,
          title: 'Planlanan Ödeme Bulunmuyor',
          subtitle: 'Aktif sözleşmenize ait gelecek kira vadeleri burada zaman çizelgesi formatında listelenir.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        final isFirst = index == 0;
        final isLast = index == periods.length - 1;
        return _buildTimelineItem(period, index, isFirst, isLast, isDark);
      },
    );
  }

  Widget _buildTimelineItem(RentPeriod period, int index, bool isFirst, bool isLast, bool isDark) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isFirst
        ? vibrantBlue
        : (isDark ? const Color(0xFF334155) : subtleBorder);

    final amountStr = period.expectedAmount > 0
        ? '₺${_formatAmount(period.expectedAmount)}'
        : (_activeLease != null ? '₺${_formatAmount(_activeLease!.rentAmount)}' : '₺15.000');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sol Timeline Çizgisi & Düğüm (Node)
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Üst Çizgi
                Container(
                  width: 2,
                  height: 12,
                  color: isFirst ? Colors.transparent : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                ),
                // Timeline Düğümü
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isFirst ? vibrantBlue : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFirst ? vibrantBlue.withValues(alpha: 0.3) : Colors.transparent,
                      width: 4,
                    ),
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: vibrantBlue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: isFirst ? Colors.white : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
                    ),
                  ),
                ),
                // Alt Çizgi
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Sağ Kart İçeriği
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cardBorder,
                  width: isFirst ? 1.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık & Rozet
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatMonthTitle(period.periodStart),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      if (isFirst)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: vibrantBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: vibrantBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.trending_up_rounded, size: 12, color: vibrantBlue),
                              const SizedBox(width: 4),
                              Text(
                                'Sıradaki Dönem',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: vibrantBlue,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Gelecek Dönem',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tutar ve Vade
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Vade: ${_formatTurkishDate(period.periodStartFormatted)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        amountStr,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: vibrantBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Aksiyon Butonu ("Ödeme Yap" / Erken Ödeme)
                  OutlinedButton.icon(
                    onPressed: () => _openPaymentOptionsBottomSheet(period),
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(
                      'Ödeme Yap',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: vibrantBlue,
                      side: const BorderSide(color: vibrantBlue),
                      minimumSize: const Size(double.infinity, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(vibrantBlue),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Finansal veriler yükleniyor...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Bir hata oluştu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : darkNavy),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllPaymentData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: vibrantBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : subtleBorder),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : darkNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky Segmented TabBar Delegate
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height + 12;

  @override
  double get maxExtent => tabBar.preferredSize.height + 12;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar || oldDelegate.backgroundColor != backgroundColor;
  }
}
