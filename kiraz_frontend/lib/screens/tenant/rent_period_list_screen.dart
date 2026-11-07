import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/lease.dart';
import '../../models/rent_period.dart';
import '../../services/payment_service.dart';
import '../../services/rent_period_service.dart';
import '../../utils/constants.dart';
import 'paytr_payment_screen.dart';

class RentPeriodListScreen extends StatefulWidget {
  final int? leaseId;
  final Lease? lease;
  final bool isLandlord;

  const RentPeriodListScreen({
    super.key,
    this.leaseId,
    this.lease,
    this.isLandlord = false,
  });

  int get effectiveLeaseId => leaseId ?? lease?.id ?? 0;
  bool get effectiveIsLandlord => isLandlord || lease != null;

  @override
  State<RentPeriodListScreen> createState() => _RentPeriodListScreenState();
}

class _RentPeriodListScreenState extends State<RentPeriodListScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);
  static const Color legalBurgundy = Color(0xFF881337);
  static const Color legalBurgundyBg = Color(0xFFFFF1F2);
  static const Color legalBurgundyDarkBg = Color(0xFF4C0519);
  static const Color overdueRed = Color(0xFFDC2626);
  static const Color overdueRedBg = Color(0xFFFEF2F2);

  final RentPeriodService _rentPeriodService = RentPeriodService();
  final PaymentService _paymentService = PaymentService();
  List<RentPeriod> _periods = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _uploadingPeriodId;
  int? _payingPeriodId;
  String _userRole = 'LANDLORD';
  int? _currentUserId;

  bool get _isManager =>
      widget.effectiveIsLandlord ||
      _userRole == 'LANDLORD' ||
      _userRole == 'AGENT';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchPeriods();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userRole = prefs.getString('user_role') ?? (widget.isLandlord ? 'LANDLORD' : 'TENANT');
      _currentUserId = prefs.getInt('userId');
    });
  }

  Future<void> _fetchPeriods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final periods = await _rentPeriodService.getPeriodsForLease(widget.effectiveLeaseId);
      if (!mounted) return;
      setState(() {
        _periods = periods.map((p) {
          if (p.expectedAmount <= 0 && widget.lease != null && widget.lease!.rentAmount > 0) {
            return p.copyWith(expectedAmount: widget.lease!.rentAmount);
          }
          return p;
        }).toList();
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

  Future<void> _onUploadReceipt(RentPeriod period) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() => _uploadingPeriodId = period.id);

      try {
        await _rentPeriodService.uploadReceipt(period.id, file);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dekont başarıyla yüklendi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchPeriods();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dekont yüklenemedi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _uploadingPeriodId = null);
        }
      }
    }
  }

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
            title: '${period.periodStartFormatted.isNotEmpty ? period.periodStartFormatted : "Kira"} Ödemesi',
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
                    'Ödeme başarıyla tamamlandı! Kira durumunuz güncellendi.',
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
        _fetchPeriods();
      } else if (success == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Ödeme işlemi tamamlanamadı veya iptal edildi.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _payingPeriodId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Ödeme başlatılamadı: ${e.toString().replaceAll('Exception: ', '')}'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _updatePeriodStatus(RentPeriod period, String status) async {
    try {
      await _rentPeriodService.updatePeriodStatus(period.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'PAID' || status == 'ÖDENDİ'
                ? 'Ödeme onaylandı!'
                : 'Dekont reddedildi.',
          ),
          backgroundColor:
              status == 'PAID' || status == 'ÖDENDİ' ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchPeriods();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showInitiateLegalProcessDialog(RentPeriod period) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: legalBurgundy.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: legalBurgundy,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hukuki Süreci Başlat',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : darkNavy,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bu işlem kira kaydını "Hukuki Süreçte / Avukatta" statüsüne geçirecektir. Kiracıya resmi ihtar ve icra takibi sürecinin başladığı bildirilecektir.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dönem: ${period.periodStartFormatted} - ${period.periodEnd}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                      ),
                    ),
                    if (period.expectedAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kira Tutarı: ₺${period.expectedAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: legalBurgundy,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Hukuki İşlem / İhtar Notu (İsteğe bağlı):',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Örn: Noter aracılığıyla 1. ihtarname gönderildi, icra dosya no: 2026/...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    'Vazgeç',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await _rentPeriodService.initiateLegalProcess(
                              period.id,
                              userId: _currentUserId,
                              notes: notesController.text.trim().isNotEmpty
                                  ? notesController.text.trim()
                                  : null,
                            );
                            if (!dialogCtx.mounted) return;
                            Navigator.of(dialogCtx).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hukuki süreç başarıyla başlatıldı ve dosya takibe alındı.'),
                                backgroundColor: legalBurgundy,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _fetchPeriods();
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (!dialogCtx.mounted) return;
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text('Hata: $e'),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: legalBurgundy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gavel_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Süreci Başlat',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptDialog(RentPeriod period) {
    final isPaid = _isPaid(period.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawUrl = period.receiptImageUrl ?? '';
    final isPdf = rawUrl.toLowerCase().endsWith('.pdf');
    final String fullImageUrl;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      fullImageUrl = rawUrl;
    } else {
      final prefix = rawUrl.startsWith('/') ? '' : '/';
      fullImageUrl = '${ApiConstants.baseUrl}$prefix$rawUrl';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
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
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Kapat',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 350),
                      color: Colors.black.withValues(alpha: 0.04),
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
                          : (rawUrl.isNotEmpty
                              ? Image.network(
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
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: Text('Kayıtlı dekont görseli yok'),
                                  ),
                                )),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isPaid) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Bu ödeme onaylanmıştır',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade200,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Kapat',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ] else if (_isManager) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _updatePeriodStatus(period, 'REJECTED');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Reddet',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _updatePeriodStatus(period, 'PAID');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Onayla',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (period.isOverdue) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _showInitiateLegalProcessDialog(period);
                        },
                        icon: const Icon(Icons.gavel_rounded, size: 16),
                        label: const Text('Hukuki Süreci Başlat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: legalBurgundy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ] else ...[
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade200,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Kapat',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(RentPeriod period, bool isDark) {
    if (period.isInLegalProcess) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? legalBurgundyDarkBg.withValues(alpha: 0.6) : legalBurgundyBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: legalBurgundy,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gavel_rounded, size: 13, color: legalBurgundy),
            const SizedBox(width: 5),
            Text(
              'Hukuki Süreçte / Avukatta',
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFFFDA4AF) : legalBurgundy,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (period.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : overdueRedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: overdueRed,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: overdueRed),
            const SizedBox(width: 4),
            Text(
              'Gecikmede',
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFFFCA5A5) : overdueRed,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (period.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 13,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            ),
            const SizedBox(width: 4),
            Text(
              'Ödendi',
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (period.isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_outlined, size: 13, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              'Reddedildi',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 13,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 4),
          Text(
            'Bekliyor',
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  bool _isPaid(String status) {
    final s = status.toUpperCase();
    return s == 'PAID' || s == 'ÖDENDİ' || s == 'ODENDI';
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
          'Ödeme Dönemleri',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchPeriods,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _periods.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Kayıtlı ödeme dönemi bulunamadı.',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _periods.length,
                      itemBuilder: (context, index) {
                        final period = _periods[index];
                        final isPaid = _isPaid(period.status);
                        final hasReceipt = period.receiptImageUrl != null &&
                            period.receiptImageUrl!.isNotEmpty;
                        final isUploading = _uploadingPeriodId == period.id;
                        final isPaying = _payingPeriodId == period.id;

                        final dateDisplay = period.periodEnd.isNotEmpty
                            ? "${period.periodStartFormatted}  —  ${period.periodEnd}"
                            : period.periodStartFormatted;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: period.isInLegalProcess
                                  ? legalBurgundy.withValues(alpha: 0.6)
                                  : (period.isOverdue
                                      ? overdueRed.withValues(alpha: 0.4)
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : subtleBorder)),
                              width: period.isInLegalProcess || period.isOverdue ? 1.5 : 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_outlined,
                                            size: 20,
                                            color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              dateDisplay,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(period, isDark),
                                  ],
                                ),
                                if (period.expectedAmount > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Kira Tutarı: ',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '₺${period.expectedAmount.toStringAsFixed(0)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: period.isInLegalProcess
                                              ? legalBurgundy
                                              : (period.isOverdue
                                                  ? overdueRed
                                                  : (isDark ? Colors.white : darkNavy)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Status informative notices
                                if (period.isInLegalProcess) ...[
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? legalBurgundyDarkBg.withValues(alpha: 0.4)
                                          : legalBurgundyBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: legalBurgundy.withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: legalBurgundy.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.gavel_rounded,
                                            size: 16,
                                            color: legalBurgundy,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Hukuki Süreç & Avukatlık Takibi',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? const Color(0xFFFDA4AF) : legalBurgundy,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _isManager
                                                    ? 'Bu kira borcu için yasal icra ve avukatlık takibi aktif durumdadır.'
                                                    : 'Bu kira borcunuz için ev sahibi/emlakçı tarafından hukuki süreç ve icra takibi başlatılmıştır. Lütfen kiralayan veya temsilcisiyle ivedilikle iletişime geçiniz.',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (period.isOverdue) ...[
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
                                          : overdueRedBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: overdueRed.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: overdueRed,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _isManager
                                                ? 'Ödeme vadesi geçmiş ve gecikmededir.'
                                                : 'Kira ödemesi gecikmiştir. Lütfen ödemenizi yapıp dekont yükleyiniz.',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: isDark ? const Color(0xFFFCA5A5) : overdueRed,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Action Buttons
                                if (_isManager) ...[
                                  // Manager (Landlord / Agent) Actions
                                  if (period.isOverdue) ...[
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _showInitiateLegalProcessDialog(period),
                                      icon: const Icon(Icons.gavel_rounded, size: 18),
                                      label: const Text('Hukuki Süreci Başlat'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: legalBurgundy,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                  if (isPaid || hasReceipt) ...[
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      onPressed: () => _showReceiptDialog(period),
                                      icon: const Icon(Icons.receipt_long, size: 18),
                                      label: const Text('Dekontu Gör'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: vibrantBlue,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ] else if (!period.isOverdue && !period.isInLegalProcess) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 16, color: Colors.grey.shade500),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Henüz dekont yüklenmedi',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ] else ...[
                                  // Tenant Actions
                                  if (!isPaid && !period.isInLegalProcess) ...[
                                    const SizedBox(height: 14),
                                    if (period.isPending || period.isOverdue) ...[
                                      ElevatedButton.icon(
                                        onPressed: (isPaying || isUploading)
                                            ? null
                                            : () => _payWithCard(period),
                                        icon: isPaying
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.credit_card_rounded, size: 18),
                                        label: Text(
                                          isPaying ? 'Bağlanıyor...' : 'Kredi Kartı ile Öde',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: vibrantBlue,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(double.infinity, 44),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    OutlinedButton.icon(
                                      onPressed: (isUploading || isPaying)
                                          ? null
                                          : () => _onUploadReceipt(period),
                                      icon: isUploading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.upload_file, size: 18),
                                      label: Text(isUploading
                                          ? 'Yükleniyor...'
                                          : (hasReceipt ? 'Dekontu Güncelle' : 'Dekont Yükle')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark ? const Color(0xFF38BDF8) : vibrantBlue,
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFF38BDF8) : vibrantBlue,
                                        ),
                                        minimumSize: const Size(double.infinity, 42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ] else if (hasReceipt) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline,
                                            size: 16, color: Colors.green),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Dekont onaylandı / yüklendi',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
