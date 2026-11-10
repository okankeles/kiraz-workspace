import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/property.dart';
import '../../models/property_delegation.dart';
import '../../services/delegation_service.dart';
import '../../services/property_service.dart';
import '../../utils/error_handler.dart';

class DelegationsScreen extends StatefulWidget {
  const DelegationsScreen({super.key});

  @override
  State<DelegationsScreen> createState() => _DelegationsScreenState();
}

class _DelegationsScreenState extends State<DelegationsScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color subtleBorder = Color(0xFFE5E0D8);
  static const Color darkCardBorder = Color(0xFF334155);

  final DelegationService _delegationService = DelegationService();
  final PropertyService _propertyService = PropertyService();

  List<PropertyDelegation> _delegations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDelegations();
  }

  Future<void> _loadDelegations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final landlordId = prefs.getInt('userId');

      final items = await _delegationService.getLandlordDelegations(landlordId: landlordId);

      if (!mounted) return;
      setState(() {
        _delegations = items;
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

  // --- YETKİYİ İPTAL ET AKSİYONU ---
  Future<void> _confirmRevokeDelegation(PropertyDelegation delegation) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final agentDisplay = delegation.agentName?.trim().isNotEmpty == true
        ? delegation.agentName!
        : (delegation.agentEmail ?? 'Emlak Danışmanı');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Yetkiyi İptal Et',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : darkNavy,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${delegation.propertyTitle} mülkünüz için $agentDisplay yetkilendirmesini iptal etmek istediğinize emin misiniz?',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İptal edildiğinde danışman bu mülk üzerinde yeni sözleşme veya işlem yapamayacaktır.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Vazgeç',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Evet, İptal Et'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _delegationService.deleteLandlordDelegation(delegation.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${delegation.propertyTitle} üzerindeki emlakçı yetkisi başarıyla iptal edildi.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

        _loadDelegations();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Yetki iptal edilemedi: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- YENİ EMLAKÇI ATA BOTTOM SHEET ---
  void _openAddDelegationSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final notesController = TextEditingController();

    int? selectedPropertyId;
    List<Property> properties = [];
    bool isLoadingProperties = true;
    bool isSubmitting = false;
    String? propertyError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            // Mülkleri bir kez yükle
            if (isLoadingProperties && properties.isEmpty && propertyError == null) {
              _propertyService.getProperties().then((props) {
                if (!modalCtx.mounted) return;
                setModalState(() {
                  properties = props;
                  isLoadingProperties = false;
                  if (props.isNotEmpty) {
                    selectedPropertyId = props.first.id;
                  }
                });
              }).catchError((err) {
                if (!modalCtx.mounted) return;
                setModalState(() {
                  isLoadingProperties = false;
                  propertyError = err.toString();
                });
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
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

                    // Başlık & Kapat
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
                                  color: vibrantBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: vibrantBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Yeni Emlakçı Ata',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: textSecondary),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Form
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Mülk Seçimi',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),

                              if (isLoadingProperties)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? darkCardBorder : subtleBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: vibrantBlue),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Mülkleriniz yükleniyor...',
                                        style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                )
                              else if (properties.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Yetkilendirme yapılacak kayıtlı mülkünüz bulunamadı. Lütfen önce mülk ekleyin.',
                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.amber.shade800),
                                  ),
                                )
                              else
                                DropdownButtonFormField<int>(
                                  initialValue: selectedPropertyId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    prefixIcon: const Icon(Icons.home_work_outlined, color: vibrantBlue),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: isDark ? darkCardBorder : subtleBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: isDark ? darkCardBorder : subtleBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: vibrantBlue, width: 1.5),
                                    ),
                                  ),
                                  dropdownColor: cardBg,
                                  items: properties.map((prop) {
                                    return DropdownMenuItem<int>(
                                      value: prop.id,
                                      child: Text(
                                        '${prop.name} ${prop.address.isNotEmpty ? '• ${prop.address}' : ''}',
                                        style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setModalState(() => selectedPropertyId = val);
                                  },
                                  validator: (val) {
                                    if (val == null) return 'Lütfen bir mülk seçiniz';
                                    return null;
                                  },
                                ),

                              const SizedBox(height: 18),

                              Text(
                                'Emlakçı E-posta Adresi',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.inter(fontSize: 14, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'emlakci@ornek.com',
                                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.email_outlined, color: vibrantBlue),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? darkCardBorder : subtleBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? darkCardBorder : subtleBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: vibrantBlue, width: 1.5),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Emlakçı e-posta adresi gereklidir';
                                  }
                                  if (!val.contains('@') || !val.contains('.')) {
                                    return 'Geçerli bir e-posta adresi giriniz';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Açıklama / Notlar (Opsiyonel)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: notesController,
                                maxLines: 2,
                                style: GoogleFonts.inter(fontSize: 13, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Örn: 1 yıllık tam kiralama ve sözleşme yetkisi...',
                                  hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? darkCardBorder : subtleBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? darkCardBorder : subtleBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: vibrantBlue, width: 1.5),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              ElevatedButton(
                                onPressed: isSubmitting || properties.isEmpty
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setModalState(() => isSubmitting = true);

                                        try {
                                          final delegation = await _delegationService.createLandlordDelegation(
                                            propertyId: selectedPropertyId!,
                                            agentEmail: emailController.text.trim(),
                                            notes: notesController.text.trim(),
                                          );

                                          if (sheetCtx.mounted) {
                                            Navigator.pop(sheetCtx);
                                          }

                                          if (!mounted) return;

                                          // Referans kodu varsa kullanıcıya göster
                                          if (delegation.referenceCode != null &&
                                              delegation.referenceCode!.isNotEmpty) {
                                            _showReferenceCodeDialog(delegation);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Emlakçı yetkilendirmesi başarıyla oluşturuldu!'),
                                                backgroundColor: Colors.green,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }

                                          _loadDelegations();
                                        } catch (e) {
                                          setModalState(() => isSubmitting = false);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Hata: $e'),
                                              backgroundColor: Colors.red.shade700,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: vibrantBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        'Yetkilendir ve Davet Et',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- REFERANS KODU DİYALOGU ---
  void _showReferenceCodeDialog(PropertyDelegation delegation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = delegation.referenceCode ?? '';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Emlakçı Başarıyla Davet Edildi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? Colors.white : darkNavy,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${delegation.propertyTitle} mülkünüz için emlakçı temsil kodu üretildi. Bu kodu emlakçınız ile paylaşabilirsiniz:',
              style: GoogleFonts.inter(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: vibrantBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: vibrantBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: vibrantBlue),
                    tooltip: 'Kodu Kopyala',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referans kodu panoya kopyalandı!'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: vibrantBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final textPrimary = isDark ? Colors.white : darkNavy;

    final activeDelegations = _delegations.where((d) => d.isActive).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emlakçı Yetkilendirmeleri',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
            Text(
              'Mülkleriniz için yetkili emlak danışmanları',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          if (activeDelegations.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: vibrantBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vibrantBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, color: vibrantBlue, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${activeDelegations.length} Aktif',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: vibrantBlue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: vibrantBlue))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadDelegations,
                  color: vibrantBlue,
                  child: _delegations.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: _delegations.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final delegation = _delegations[index];
                            return _buildDelegationCard(delegation, isDark);
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDelegationSheet,
        backgroundColor: vibrantBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: Text(
          'Yeni Emlakçı Ata',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  // --- LİSTE KARTI ---
  Widget _buildDelegationCard(PropertyDelegation delegation, bool isDark) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? darkCardBg : Colors.white;
    final cardBorder = isDark ? darkCardBorder : subtleBorder;

    final agentName = delegation.agentName?.trim().isNotEmpty == true
        ? delegation.agentName!
        : 'Emlak Danışmanı';
    final agentEmail = delegation.agentEmail?.trim().isNotEmpty == true
        ? delegation.agentEmail!
        : 'E-posta belirtilmemiş';

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol İkon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: vibrantBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.real_estate_agent_rounded,
                  color: vibrantBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delegation.propertyTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Emlakçı Adı
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            agentName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Emlakçı E-posta
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 13, color: textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            agentEmail,
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
              ),

              // Sağ: "Yetkiyi İptal Et" (Kırmızı Çöp Kutusu İkonu)
              IconButton(
                onPressed: () => _confirmRevokeDelegation(delegation),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                tooltip: 'Yetkiyi İptal Et',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Alt Rozetler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: delegation.isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      delegation.isActive ? Icons.check_circle_rounded : Icons.info_outline,
                      size: 13,
                      color: delegation.isActive ? const Color(0xFF10B981) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      delegation.statusDisplay,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: delegation.isActive ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (delegation.referenceCode != null && delegation.referenceCode!.isNotEmpty)
                Text(
                  'Kod: ${delegation.referenceCode}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: vibrantBlue,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BOŞ DURUM (EMPTY STATE) ---
  Widget _buildEmptyState(bool isDark) {
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: vibrantBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_ind_outlined,
                size: 64,
                color: vibrantBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz yetkilendirilmiş emlakçı bulunmamaktadır',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mülklerinizin kiralama ve yönetim süreçlerini profesyonel emlak danışmanlarına devretmek için hemen yeni emlakçı atayabilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAddDelegationSheet,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Yeni Emlakçı Ata'),
              style: ElevatedButton.styleFrom(
                backgroundColor: vibrantBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
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
              onPressed: _loadDelegations,
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
