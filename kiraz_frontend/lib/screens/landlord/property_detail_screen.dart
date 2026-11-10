import '../../utils/file_viewer.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lease.dart';
import '../../models/property.dart';
import '../../models/property_delegation.dart';
import '../../services/api_client.dart';
import '../../services/delegation_service.dart';
import '../../services/lease_service.dart';
import '../../utils/error_handler.dart';
import '../tenant/rent_period_list_screen.dart';
import 'assign_tenant_screen.dart';
import 'edit_property_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);
  static const Color darkCardBorder = Color(0xFF334155);

  final LeaseService _leaseService = LeaseService();
  final DelegationService _delegationService = DelegationService();

  late Property _currentProperty;
  List<Lease> _leases = [];
  List<PropertyDelegation> _delegations = [];
  bool _isLoading = true;
  int? _uploadingLeaseId;
  int? _regeneratingLeaseId;
  String _userRole = 'LANDLORD';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentProperty = widget.property;
    _loadAllData();
  }

  Future<void> _onEditProperty() async {
    final updated = await Navigator.push<Property>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPropertyScreen(property: _currentProperty),
      ),
    );
    if (updated != null) {
      setState(() {
        _currentProperty = updated;
      });
      _loadAllData();
    }
  }

  Future<void> _regenerateInviteCode(Lease lease) async {
    setState(() => _regeneratingLeaseId = lease.id);
    try {
      final response = await _leaseService.regenerateInviteCode(lease.id);

      if (!mounted) return;
      setState(() => _regeneratingLeaseId = null);

      await _showInviteCodeDialog(response.inviteCode, response.inviteCodeExpiresAt);
      await _loadAllData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _regeneratingLeaseId = null);

      String errorMsg;
      if (e is ApiException) {
        if (e.statusCode == 409) {
          errorMsg = 'Kiracı zaten bağlanmış veya sözleşme artık aktif değil. Yeni davet kodu üretilemez.';
        } else if (e.statusCode == 404) {
          errorMsg = 'Sözleşme bulunamadı veya bu işlem için yetkiniz yok.';
        } else {
          errorMsg = e.message;
        }
      } else {
        errorMsg = ErrorHandler.getUserFriendlyMessage(e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showInviteCodeDialog(String code, DateTime? expiresAt) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : darkNavy;

    String expiryStr = '';
    if (expiresAt != null) {
      final day = expiresAt.day.toString().padLeft(2, '0');
      final month = expiresAt.month.toString().padLeft(2, '0');
      final year = expiresAt.year;
      final hour = expiresAt.hour.toString().padLeft(2, '0');
      final minute = expiresAt.minute.toString().padLeft(2, '0');
      expiryStr = '$day.$month.$year $hour:$minute';
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.mark_email_read_rounded, color: vibrantBlue, size: 48),
        title: Text(
          'Yeni Davet Kodu Oluşturuldu',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Eski davet kodu geçersiz kılındı. Kiracınız sisteme kaydolurken bu yeni kodu kullanmalıdır:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vibrantBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      code,
                      style: GoogleFonts.sourceCodePro(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: vibrantBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: vibrantBlue),
                    tooltip: 'Kodu Kopyala',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Davet kodu panoya kopyalandı!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (expiryStr.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Son Kullanma: $expiryStr',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Davet kodu kopyalandı!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Kopyala'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vibrantBlue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _userRole = (prefs.getString('role') ?? 'LANDLORD').toUpperCase();
    _currentUserId = prefs.getInt('userId');

    try {
      final results = await Future.wait<dynamic>([
        _leaseService.getLeasesForProperty(widget.property.id).catchError((_) => <Lease>[]),
        _delegationService.getDelegationsForProperty(widget.property.id).catchError((_) => <PropertyDelegation>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _leases = results[0] as List<Lease>;
        _delegations = results[1] as List<PropertyDelegation>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  PropertyDelegation? get _activeDelegation {
    try {
      return _delegations.firstWhere((d) => d.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadContract(Lease lease) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png'],
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        setState(() => _uploadingLeaseId = lease.id);
        final file = File(result.files.single.path!);
        await _leaseService.uploadContract(lease.id, file);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sözleşme başarıyla yüklendi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadAllData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sözleşme yüklenemedi: ${ErrorHandler.getUserFriendlyMessage(e)}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingLeaseId = null);
      }
    }
  }

  Future<void> _viewContract(String rawUrl) async {
    await FileViewer.open(
      context: context,
      fileUrl: rawUrl,
      title: 'Kira Sözleşmesi',
    );
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
      _loadAllData();
    }
  }

  // Maker-Checker: Approve Lease
  Future<void> _approveLease(Lease lease) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sözleşmeyi Onayla'),
        content: Text(
          'Emlakçı (${lease.createdByName ?? 'Agent'}) tarafından hazırlanan bu sözleşmeyi onaylayıp aktif duruma getirmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _leaseService.approveLease(lease.id, landlordId: _currentUserId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sözleşme başarıyla onaylandı ve aktifleşti!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Maker-Checker: Reject Lease
  Future<void> _rejectLease(Lease lease) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sözleşmeyi Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu sözleşmeyi reddetmek istediğinize emin misiniz?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Ret Gerekçesi (Zorunlu)',
                hintText: 'Örn: Kira bedeli veya başlangıç tarihi hatalı',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _leaseService.rejectLease(
          lease.id,
          landlordId: _currentUserId,
          reason: reasonController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sözleşme reddedildi.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Delegation: Open Assign Agent Modal
  void _openAssignAgentSheet(bool isDark) {
    final emailOrIdController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedEndDate;
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cardBg = isDark ? darkCardBg : Colors.white;
            final textPrimary = isDark ? Colors.white : darkNavy;
            final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: vibrantBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.real_estate_agent_rounded, color: vibrantBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emlakçı Ata / Yetkilendir',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Bu mülkü yönetecek emlak danışmanını belirleyin',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: emailOrIdController,
                        decoration: InputDecoration(
                          labelText: 'Emlakçı E-posta Adresi veya ID',
                          hintText: 'ornek@emlak.com veya 2',
                          prefixIcon: const Icon(Icons.person_search_outlined),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: now.add(const Duration(days: 365)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedEndDate =
                                  "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : subtleBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 20, color: vibrantBlue),
                                  const SizedBox(width: 10),
                                  Text(
                                    selectedEndDate != null
                                        ? 'Yetki Bitiş: $selectedEndDate'
                                        : 'Yetki Bitiş Tarihi (İsteğe bağlı)',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: selectedEndDate != null ? textPrimary : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedEndDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setModalState(() => selectedEndDate = null),
                                )
                              else
                                const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Yetki Notu (İsteğe bağlı)',
                          hintText: 'Örn: Tek yetkili kiralama ve tahsilat takibi sözleşmesi',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isAssigning
                            ? null
                            : () => _assignAgent(
                                  modalCtx: modalCtx,
                                  setLoading: (loading) {
                                    if (modalCtx.mounted) {
                                      setModalState(() => isAssigning = loading);
                                    }
                                  },
                                  input: emailOrIdController.text.trim(),
                                  selectedEndDate: selectedEndDate,
                                  notes: notesController.text.trim(),
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: vibrantBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isAssigning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Yetki Ver ve Portföye Ata',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
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

  // Delegation: Assign Agent action with robust modal closing, reference code popup and error handling
  Future<void> _assignAgent({
    required BuildContext modalCtx,
    required void Function(bool) setLoading,
    required String input,
    required String? selectedEndDate,
    required String notes,
  }) async {
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen emlakçı e-posta veya ID giriniz.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(modalCtx).unfocus();
    setLoading(true);

    try {
      final parsedId = int.tryParse(input);
      final agentEmail = parsedId == null ? input : null;
      final agentId = parsedId;

      final delegation = await _delegationService.assignAgent(
        propertyId: widget.property.id,
        agentId: agentId,
        agentEmail: agentEmail,
        landlordId: _currentUserId,
        endDate: selectedEndDate,
        notes: notes,
      );

      // 1. Yetkilendirme Başarılı: BottomSheet'i (Navigator.pop) kesinlikle kapat
      if (modalCtx.mounted) {
        Navigator.of(modalCtx).pop();
      } else if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      // 2. Mülk ve atama detaylarını tazele
      _loadAllData();

      // 3. Backend'den dönen yanıtta referenceCode varsa Dialog çıkar
      final refCode = delegation.referenceCode;
      if (refCode != null && refCode.trim().isNotEmpty) {
        _showAgentInviteSuccessDialog(
          refCode.trim(),
          agentEmail: delegation.agentEmail ?? agentEmail,
          agentName: delegation.agentName,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emlakçı başarıyla yetkilendirildi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // 4. Hata Yakalama: BottomSheet'i kapatmadan butondaki loading statüsünü kaldır ve kırmızı SnackBar göster
      setLoading(false);
      final errorMsg = ErrorHandler.getUserFriendlyMessage(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showAgentInviteSuccessDialog(
    String referenceCode, {
    String? agentEmail,
    String? agentName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: cardBg,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Emlakçı Başarıyla Davet Edildi',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (agentEmail != null && agentEmail.isNotEmpty)
                      ? '$agentEmail adresine yetkilendirme daveti oluşturuldu. Emlakçı aşağıdaki referans kodunu kullanarak sisteme kaydolabilir veya mülkü portföyüne ekleyebilir.'
                      : 'Emlakçı yetkilendirmesi oluşturuldu. Aşağıdaki referans kodunu emlakçınız ile paylaşabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: vibrantBlue.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: vibrantBlue, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REFERANS KODU',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: vibrantBlue,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              referenceCode,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: vibrantBlue),
                        tooltip: 'Kopyala',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: referenceCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Referans kodu panoya kopyalandı: $referenceCode'),
                                ],
                              ),
                              backgroundColor: Colors.green.shade700,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Tamam',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Delegation: Revoke Agent Action
  Future<void> _revokeDelegation(PropertyDelegation delegation) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emlakçı Yetkisini İptal Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${delegation.agentName ?? 'Emlakçı'} danışmanının bu mülk üzerindeki temsil yetkisi sonlandırılacaktır. Geçmiş kayıtlar tarihçede saklanacaktır.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'İptal Sebebi (İsteğe bağlı)',
                hintText: 'Örn: Sözleşme süresi bitti veya anlaşma feshedildi',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yetkiyi İptal Et'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _delegationService.revokeDelegation(
          delegation.id,
          landlordId: _currentUserId,
          reason: reasonController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emlakçı yetkisi başarıyla iptal edildi.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAllData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildAgentDelegationSection({
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final active = _activeDelegation;
    final isLandlord = _userRole == 'LANDLORD';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Yetkili Emlakçı / Danışman',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (active != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Aktif Yetki',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (active != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: vibrantBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.real_estate_agent_rounded, color: vibrantBlue, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active.agentName ?? 'Yetkili Danışman',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active.agentEmail ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Başlangıç: ${active.startDate ?? '-'}',
                              style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              active.endDate != null ? 'Bitiş: ${active.endDate}' : 'Süresiz',
                              style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isLandlord) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _revokeDelegation(active),
                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                    label: const Text('Yetkiyi İptal Et (Revoke)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (isLandlord)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Icon(Icons.real_estate_agent_outlined, size: 40, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  'Bu mülk için atanmış aktif bir emlakçı bulunmuyor.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openAssignAgentSheet(isDark),
                  icon: const Icon(Icons.add_moderator_rounded, size: 18),
                  label: const Text('Emlakçı Ata / Yetkilendir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
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
    final textColor = isDark ? Colors.white : darkNavy;
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? darkCardBorder : subtleBorder;
    final isLandlord = _userRole == 'LANDLORD';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _currentProperty.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          if (isLandlord)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: vibrantBlue),
              tooltip: 'Mülkü Düzenle',
              onPressed: _onEditProperty,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      side: BorderSide(color: borderColor, width: 1.2),
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
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.home_work_outlined, color: vibrantBlue, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentProperty.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currentProperty.city != null && _currentProperty.city!.isNotEmpty
                                          ? 'Mülk Detayları • ${_currentProperty.city}'
                                          : 'Mülk Detayları',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLandlord)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: vibrantBlue),
                                  tooltip: 'Düzenle',
                                  onPressed: _onEditProperty,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 20, color: vibrantBlue),
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
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentProperty.address.isNotEmpty
                                          ? _currentProperty.address
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

                  // Item 2: Agent Delegation Section
                  _buildAgentDelegationSection(
                    isDark: isDark,
                    cardBg: cardBg,
                    textColor: textColor,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),

                  const SizedBox(height: 24),

                  // Tenant & Leases Info Section (With Maker-Checker)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sözleşmeler ve Kiracılar',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (_leases.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: vibrantBlue),
                          tooltip: 'Yeni Sözleşme Ekle',
                          onPressed: _onAssignTenant,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 0,
                    color: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: _leases.isEmpty
                          ? Column(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 48,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bu mülke henüz bir kiracı veya sözleşme eklenmedi.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _onAssignTenant,
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Kiracı / Sözleşme Ekle'),
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
                                  final isPendingApproval = lease.isPendingLandlordApproval;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: isPendingApproval
                                          ? (isDark
                                              ? const Color(0xFF78350F).withValues(alpha: 0.15)
                                              : const Color(0xFFFEF3C7).withValues(alpha: 0.5))
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isPendingApproval
                                            ? const Color(0xFFD97706)
                                            : borderColor,
                                        width: isPendingApproval ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header row with Badge
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                lease.tenantName != null && lease.tenantName!.isNotEmpty
                                                    ? lease.tenantName!
                                                    : 'Sözleşme #${lease.id}',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isPendingApproval
                                                    ? const Color(0xFFD97706).withValues(alpha: 0.15)
                                                    : (lease.isApprovedOrActive
                                                        ? Colors.green.withValues(alpha: 0.15)
                                                        : Colors.red.withValues(alpha: 0.15)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isPendingApproval
                                                    ? 'Onay Bekliyor'
                                                    : (lease.isApprovedOrActive ? 'Aktif' : (lease.status ?? 'Bekliyor')),
                                                style: TextStyle(
                                                  color: isPendingApproval
                                                      ? const Color(0xFFD97706)
                                                      : (lease.isApprovedOrActive ? Colors.green : Colors.red),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (isPendingApproval) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Emlakçı (${lease.createdByName ?? 'Agent'}) tarafından eklendi. Ev sahibi onayı bekleniyor.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(Icons.payments_outlined, size: 16, color: vibrantBlue),
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
                                            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Başlangıç: ${lease.startDate}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Davet Kodu ve Durumu Bölümü (Kiracı henüz bağlanmamışken)
                                        if (lease.canRegenerateInvite || (lease.inviteCode != null && lease.inviteCode!.isNotEmpty)) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: lease.isInviteExpired
                                                    ? Colors.red.withValues(alpha: 0.5)
                                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.vpn_key_outlined,
                                                          size: 16,
                                                          color: lease.isInviteExpired ? Colors.red : vibrantBlue,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Kiracı Davet Kodu',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: lease.isInviteExpired ? Colors.red : textColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (lease.isInviteExpired)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'Süresi Dolmuş',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      )
                                                    else if (lease.inviteCodeExpiresAt != null)
                                                      Text(
                                                        'Son: ${lease.inviteCodeExpiresAt!.day.toString().padLeft(2, '0')}.${lease.inviteCodeExpiresAt!.month.toString().padLeft(2, '0')}.${lease.inviteCodeExpiresAt!.year}',
                                                        style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: SelectableText(
                                                        lease.inviteCode ?? 'Kod oluşturulmamış',
                                                        style: GoogleFonts.sourceCodePro(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: lease.isInviteExpired ? Colors.grey : (isDark ? Colors.white : darkNavy),
                                                        ),
                                                      ),
                                                    ),
                                                    if (lease.inviteCode != null && lease.inviteCode!.isNotEmpty)
                                                      IconButton(
                                                        icon: const Icon(Icons.copy, size: 18, color: vibrantBlue),
                                                        tooltip: 'Kopyala',
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () {
                                                          Clipboard.setData(ClipboardData(text: lease.inviteCode!));
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Davet kodu panoya kopyalandı!'),
                                                              backgroundColor: Colors.green,
                                                              behavior: SnackBarBehavior.floating,
                                                              duration: Duration(seconds: 2),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                  ],
                                                ),
                                                if (lease.isInviteExpired) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '⚠️ Davet kodunun süresi dolmuş. Kiracı bu kodla giriş yapamaz. Lütfen yeni kod oluşturun.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11.5,
                                                      color: Colors.red.shade700,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                                if (isLandlord && lease.canRegenerateInvite) ...[
                                                  const SizedBox(height: 10),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: 36,
                                                    child: OutlinedButton.icon(
                                                      onPressed: _regeneratingLeaseId == lease.id
                                                          ? null
                                                          : () => _regenerateInviteCode(lease),
                                                      icon: _regeneratingLeaseId == lease.id
                                                          ? const SizedBox(
                                                              width: 14,
                                                              height: 14,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            )
                                                          : const Icon(Icons.refresh, size: 16),
                                                      label: Text(
                                                        _regeneratingLeaseId == lease.id
                                                            ? 'Yenileniyor...'
                                                            : 'Yeni Davet Kodu Oluştur',
                                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: vibrantBlue,
                                                        side: const BorderSide(color: vibrantBlue),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],

                                        // Item 3: Landlord Approval Actions for Pending Leases
                                        if (isPendingApproval && isLandlord) ...[
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => _rejectLease(lease),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(color: Colors.red),
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                  child: const Text('Reddet', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _approveLease(lease),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: const Text('Onayla (Aktif)', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],

                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RentPeriodListScreen(
                                                  leaseId: lease.id,
                                                  lease: lease,
                                                  isLandlord: isLandlord || _userRole == 'AGENT',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                          label: const Text('Ödeme Takibi & Dönemler'),
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
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: (lease.contractFileUrl == null ||
                                                      lease.contractFileUrl!.isEmpty)
                                                  ? OutlinedButton.icon(
                                                      onPressed: _uploadingLeaseId == lease.id
                                                          ? null
                                                          : () => _uploadContract(lease),
                                                      icon: _uploadingLeaseId == lease.id
                                                          ? const SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            )
                                                          : const Icon(Icons.upload_file, size: 18),
                                                      label: Text(
                                                        _uploadingLeaseId == lease.id
                                                            ? 'Yükleniyor...'
                                                            : 'Sözleşme Yükle',
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: vibrantBlue,
                                                        side: const BorderSide(color: vibrantBlue),
                                                        minimumSize: const Size(double.infinity, 40),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                    )
                                                  : ElevatedButton.icon(
                                                      onPressed: () => _viewContract(lease.contractFileUrl!),
                                                      icon: const Icon(Icons.description, size: 18),
                                                      label: const Text('Sözleşmeyi Görüntüle'),
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
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _onAssignTenant,
                                  icon: const Icon(Icons.swap_horiz),
                                  label: const Text('Yeni Sözleşme / Kiracı Ekle'),
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
