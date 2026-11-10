import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/lease.dart';
import '../../models/rent_period.dart';
import '../../services/payment_service.dart';
import '../../utils/error_handler.dart';

class EftPaymentScreen extends StatefulWidget {
  final RentPeriod period;
  final Lease? lease;

  const EftPaymentScreen({
    super.key,
    required this.period,
    this.lease,
  });

  @override
  State<EftPaymentScreen> createState() => _EftPaymentScreenState();
}

class _EftPaymentScreenState extends State<EftPaymentScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  final PaymentService _paymentService = PaymentService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  int? _selectedFileSize;
  bool _isUploading = false;

  // Ev sahibi / Sistem IBAN Bilgileri
  String get _recipientName {
    final name = widget.lease?.landlordName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'KiraZ Gayrimenkul Yönetim A.Ş.';
  }

  String get _bankName {
    return 'Türkiye İş Bankası';
  }

  String get _ibanFormatted {
    return 'TR33 0006 1005 1978 9012 3456 78';
  }

  String get _ibanClean {
    return _ibanFormatted.replaceAll(' ', '');
  }

  String get _descriptionText {
    final tenantName = widget.lease?.tenantName ?? 'Kiraci';
    return 'Kira - ${widget.period.periodStartFormatted} - $tenantName - #${widget.period.id}';
  }

  double get _payableAmount {
    if (widget.period.expectedAmount > 0) return widget.period.expectedAmount;
    if (widget.lease != null && widget.lease!.rentAmount > 0) return widget.lease!.rentAmount;
    return 15000;
  }

  String _formatAmount(double amount) {
    final rounded = amount.toStringAsFixed(0);
    return rounded.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label kopyalandı!'),
          ],
        ),
        backgroundColor: const Color(0xFF161F33),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int>? bytes = file.bytes;
        if ((bytes == null || bytes.isEmpty) && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            _selectedFileName = file.name;
            _selectedFileBytes = bytes;
            _selectedFileSize = file.size;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçilirken hata oluştu: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final name = image.name.isNotEmpty ? image.name : 'dekont_${DateTime.now().millisecondsSinceEpoch}.jpg';
        setState(() {
          _selectedFileName = name;
          _selectedFileBytes = bytes;
          _selectedFileSize = bytes.length;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Görsel seçilirken hata oluştu: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showFileSourcePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dekont Kaynağını Seçin',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : darkNavy,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: vibrantBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: vibrantBlue),
                ),
                title: Text(
                  'Belge / PDF / Dosya Seç',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Cihazınızdaki PDF veya görsel dosyası',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.green),
                ),
                title: Text(
                  'Galeriden Fotoğraf Seç',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Ekran görüntüsü veya dekont fotoğrafı',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.purple),
                ),
                title: Text(
                  'Kamera ile Çek',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Basılı dekontu doğrudan fotoğraflayın',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReceipt() async {
    if (_selectedFileName == null || _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce dekont belgenizi seçiniz.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _paymentService.uploadReceipt(
        periodId: widget.period.id,
        fileName: _selectedFileName!,
        fileBytes: _selectedFileBytes!,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dekont başarıyla yüklendi! Ödemeniz onay için iletildi.',
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

      // Başarılı yüklemede sayfayı kapatıp true döndür
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Dekont yüklenemedi: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final cardBorder = isDark ? const Color(0xFF334155) : subtleBorder;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Havale / EFT ile Öde',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
            Text(
              '${_formatMonthTitle(widget.period.periodStart)} Kira Dönemi',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Tutar Bilgisi Kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: vibrantBlue.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ödenecek Tutar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₺${_formatAmount(_payableAmount)}',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Vade: ${widget.period.periodStartFormatted}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Banka Hesap Bilgileri Kartı
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: vibrantBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Banka Hesap Bilgileri',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banka Adı
                  _buildCopyableField(
                    label: 'Banka',
                    value: _bankName,
                    icon: Icons.account_balance_rounded,
                    isDark: isDark,
                  ),
                  const Divider(height: 24),

                  // Alıcı Adı
                  _buildCopyableField(
                    label: 'Alıcı / Hesap Sahibi',
                    value: _recipientName,
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                  ),
                  const Divider(height: 24),

                  // IBAN
                  _buildCopyableField(
                    label: 'IBAN Numarası',
                    value: _ibanFormatted,
                    copyValue: _ibanClean,
                    icon: Icons.credit_card_outlined,
                    isDark: isDark,
                    isPrimary: true,
                  ),
                  const Divider(height: 24),

                  // Açıklama / Referans Kodu
                  _buildCopyableField(
                    label: 'Havale / EFT Açıklaması',
                    value: _descriptionText,
                    icon: Icons.description_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Açıklama Uyarısı
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: vibrantBlue.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, size: 18, color: vibrantBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ödemenizin otomatik eşleşebilmesi için bankanızın açıklama kısmına lütfen yukarıdaki metni kopyalayıp yapıştırınız.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.blue.shade200 : const Color(0xFF1E40AF),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Dekont Yükleme Alanı
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: vibrantBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ödeme Dekontu Yükle',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Havale/EFT işleminiz tamamlandıktan sonra dekontu yükleyerek onay sürecini başlatabilirsiniz.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),

            // Belge Seçici Dropzone
            if (_selectedFileName == null)
              InkWell(
                onTap: _showFileSourcePicker,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: vibrantBlue.withValues(alpha: 0.4),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: vibrantBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: vibrantBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dekont Dosyası Seç veya Fotoğrafla',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF, JPG veya PNG formatı desteklenir (Maks 10MB)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _showFileSourcePicker,
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: const Text('Dosya Seç'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: vibrantBlue,
                          side: const BorderSide(color: vibrantBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Seçili Belge Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedFileName!.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: const Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF064E3B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedFileSize != null ? _formatFileSize(_selectedFileSize!) : 'Seçildi',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.green.shade300 : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                      tooltip: 'Kaldır',
                      onPressed: () {
                        setState(() {
                          _selectedFileName = null;
                          _selectedFileBytes = null;
                          _selectedFileSize = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // 4. Gönder Butonu
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _submitReceipt,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isUploading ? 'Dekont Yükleniyor...' : 'Dekontu Gönder ve Onaya İlet',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: vibrantBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyableField({
    required String label,
    required String value,
    String? copyValue,
    required IconData icon,
    required bool isDark,
    bool isPrimary = false,
  }) {
    final effectiveCopy = copyValue ?? value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isPrimary ? vibrantBlue : (isDark ? Colors.grey.shade800 : Colors.grey.shade200))
                .withValues(alpha: isPrimary ? 0.12 : 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isPrimary ? vibrantBlue : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: GoogleFonts.inter(
                  fontSize: isPrimary ? 14 : 13,
                  fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                  color: isPrimary
                      ? (isDark ? const Color(0xFF60A5FA) : vibrantBlue)
                      : (isDark ? Colors.white : darkNavy),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: vibrantBlue,
          tooltip: 'Kopyala',
          onPressed: () => _copyToClipboard(effectiveCopy, label),
        ),
      ],
    );
  }
}
