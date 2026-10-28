import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/lease.dart';
import '../../models/rent_period.dart';
import '../../services/rent_period_service.dart';
import '../../utils/constants.dart';

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

  final RentPeriodService _rentPeriodService = RentPeriodService();
  List<RentPeriod> _periods = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _uploadingPeriodId;

  @override
  void initState() {
    super.initState();
    _fetchPeriods();
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

  void _showReceiptDialog(RentPeriod period) {
    final isPaid = _isPaid(period.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawUrl = period.receiptImageUrl ?? '';
    final String fullImageUrl;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      fullImageUrl = rawUrl;
    } else {
      fullImageUrl = '${ApiConstants.baseUrl}$rawUrl';
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
                          child: rawUrl.isNotEmpty
                              ? Image.network(
                                  fullImageUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    final total =
                                        loadingProgress.expectedTotalBytes;
                                    final loaded = loadingProgress
                                        .cumulativeBytesLoaded;
                                    return Container(
                                      height: 200,
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        value: total != null
                                            ? loaded / total
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 160,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                ),
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
                            foregroundColor:
                                isDark ? Colors.white : Colors.black87,
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
                      ] else if (widget.effectiveIsLandlord) ...[
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
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
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
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : Colors.grey.shade200,
                            foregroundColor:
                                isDark ? Colors.white : Colors.black87,
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

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'ODENDI':
      case 'ÖDENDİ':
        return 'ÖDENDİ';
      case 'PENDING':
      case 'BEKLIYOR':
      case 'BEKLİYOR':
        return 'BEKLİYOR';
      case 'REJECTED':
      case 'REDDEDILDI':
      case 'REDDEDİLDİ':
        return 'Reddedildi';
      case 'OVERDUE':
      case 'GECIKTI':
      case 'GECİKTİ':
        return 'GECİKTİ';
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'ODENDI':
      case 'ÖDENDİ':
        return Colors.green;
      case 'PENDING':
      case 'BEKLIYOR':
      case 'BEKLİYOR':
        return Colors.orange.shade800;
      case 'REJECTED':
      case 'REDDEDILDI':
      case 'REDDEDİLDİ':
        return Colors.red;
      case 'OVERDUE':
      case 'GECIKTI':
      case 'GECİKTİ':
        return Colors.red;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toUpperCase();
    if (s == 'REJECTED' || s == 'REDDEDİLDİ' || s == 'REDDEDILDI') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Reddedildi',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    final statusColor = _getStatusColor(status);
    final statusLabel = _formatStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : subtleBorder,
                              width: 1.2,
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
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_outlined,
                                          size: 20,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          dateDisplay,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildStatusBadge(period.status),
                                  ],
                                ),
                                if (!widget.effectiveIsLandlord) ...[
                                  if (!isPaid) ...[
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: isUploading
                                          ? null
                                          : () => _onUploadReceipt(period),
                                      icon: isUploading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.upload_file, size: 18),
                                      label: Text(isUploading
                                          ? 'Yükleniyor...'
                                          : 'Dekont Yükle'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: vibrantBlue,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
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
                                ] else ...[
                                  if (isPaid || hasReceipt) ...[
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: () => _showReceiptDialog(period),
                                      icon: const Icon(Icons.receipt_long, size: 18),
                                      label: const Text('Dekontu Gör'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: vibrantBlue,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ] else ...[
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
