import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/property.dart';
import '../../services/api_client.dart';
import '../../services/property_service.dart';
import '../../utils/error_handler.dart';

class EditPropertyScreen extends StatefulWidget {
  final Property property;

  const EditPropertyScreen({super.key, required this.property});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  late final TextEditingController _titleController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _daskController;
  late final TextEditingController _depositController;

  DateTime? _selectedDaskDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.property.name);
    _addressController = TextEditingController(text: widget.property.address);
    _cityController = TextEditingController(text: widget.property.city ?? '');
    _selectedDaskDate = widget.property.daskEndDate;
    _daskController = TextEditingController(
      text: widget.property.daskEndDate != null
          ? "${widget.property.daskEndDate!.year.toString().padLeft(4, '0')}-${widget.property.daskEndDate!.month.toString().padLeft(2, '0')}-${widget.property.daskEndDate!.day.toString().padLeft(2, '0')}"
          : '',
    );
    _depositController = TextEditingController(
      text: widget.property.depositAmount != null
          ? widget.property.depositAmount!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _daskController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _selectDaskDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDaskDate ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDaskDate = picked;
        _daskController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final daskDateStr = _selectedDaskDate != null
          ? "${_selectedDaskDate!.year.toString().padLeft(4, '0')}-${_selectedDaskDate!.month.toString().padLeft(2, '0')}-${_selectedDaskDate!.day.toString().padLeft(2, '0')}"
          : (_daskController.text.trim().isNotEmpty ? _daskController.text.trim() : null);

      final depositText = _depositController.text.trim();
      final depositAmount = depositText.isNotEmpty ? double.tryParse(depositText) : null;

      final updated = await PropertyService().updateProperty(
        widget.property.id,
        _titleController.text.trim(),
        _addressController.text.trim(),
        _cityController.text.trim(),
        daskEndDate: daskDateStr,
        depositAmount: depositAmount,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mülk bilgileri başarıyla güncellendi.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage;
      if (e is ApiException) {
        if (e.statusCode == 403) {
          errorMessage = 'Bu mülkü düzenleme yetkiniz yok. Yalnızca mülk sahibi düzenleyebilir.';
        } else if (e.statusCode == 404) {
          errorMessage = 'Mülk bulunamadı veya başka bir ev sahibine ait.';
        } else if (e.statusCode == 400) {
          errorMessage = e.message.isNotEmpty ? e.message : 'Mülk başlığı zorunludur.';
        } else {
          errorMessage = e.message;
        }
      } else {
        errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mülkü Düzenle',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mülk Detaylarını Güncelle',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mülk başlığı, adresi, şehir ve sigorta bilgilerini güncelleyebilirsiniz.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : subtleBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Başlık
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Mülk Başlığı *',
                          hintText: 'Örn: Kadıköy 2+1 Daire',
                          prefixIcon: const Icon(Icons.home_outlined, color: vibrantBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen mülk başlığını giriniz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Şehir
                      TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: 'Şehir',
                          hintText: 'Örn: İstanbul',
                          prefixIcon: const Icon(Icons.location_city_outlined, color: vibrantBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Adres
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Adres',
                          hintText: 'Mahalle, Cadde, Sokak, No, Daire...',
                          prefixIcon: const Icon(Icons.location_on_outlined, color: vibrantBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // DASK Bitiş Tarihi
                      TextFormField(
                        controller: _daskController,
                        readOnly: true,
                        onTap: _selectDaskDate,
                        decoration: InputDecoration(
                          labelText: 'DASK Bitiş Tarihi',
                          hintText: 'YYYY-AA-GG',
                          prefixIcon: const Icon(Icons.security_outlined, color: vibrantBlue),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_outlined, color: vibrantBlue),
                            onPressed: _selectDaskDate,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Depozito Tutarı
                      TextFormField(
                        controller: _depositController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Depozito Tutarı (TL)',
                          hintText: 'Örn: 25000',
                          prefixIcon: const Icon(Icons.shield_outlined, color: vibrantBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Kaydet Butonu
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Değişiklikleri Kaydet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
