import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/property_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _daskController = TextEditingController();

  DateTime? _selectedDaskDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _daskController.dispose();
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

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı oturumu bulunamadı. Lütfen tekrar giriş yapınız.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final daskDateStr = _selectedDaskDate != null
          ? "${_selectedDaskDate!.year.toString().padLeft(4, '0')}-${_selectedDaskDate!.month.toString().padLeft(2, '0')}-${_selectedDaskDate!.day.toString().padLeft(2, '0')}"
          : (_daskController.text.trim().isNotEmpty ? _daskController.text.trim() : null);

      await PropertyService().createProperty(
        _titleController.text.trim(),
        _addressController.text.trim(),
        _cityController.text.trim(),
        userId,
        daskEndDate: daskDateStr,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hintText,
    dynamic prefixIcon,
    required bool isDark,
    bool alignLabelWithHint = false,
  }) {
    final Widget? effectivePrefix = prefixIcon is Widget
        ? prefixIcon
        : (prefixIcon is IconData ? Icon(prefixIcon, color: vibrantBlue) : null);

    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: effectivePrefix,
      filled: true,
      alignLabelWithHint: alignLabelWithHint,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: isDark
            ? BorderSide.none
            : const BorderSide(color: subtleBorder, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: isDark
            ? BorderSide.none
            : const BorderSide(color: subtleBorder, width: 1.2),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: vibrantBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
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
        title: Text(
          'Yeni Mülk Ekle',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: textColor,
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
                  'Mülk Bilgileri',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Portföyünüze eklemek istediğiniz gayrimenkulün bilgilerini giriniz.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    label: 'Başlık',
                    hintText: 'Örn: Kadıköy Daire 4',
                    prefixIcon: Icons.home_work_outlined,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen bir mülk başlığı giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    label: 'Adres',
                    hintText: 'Örn: Caferağa Mah. Moda Cad. No:12 D:4',
                    prefixIcon: const Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 14.0),
                          child: Icon(Icons.location_on, color: vibrantBlue),
                        ),
                      ],
                    ),
                    isDark: isDark,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen mülk adresini giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    label: 'Şehir',
                    hintText: 'Örn: İstanbul',
                    prefixIcon: Icons.location_city_outlined,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen şehir giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _daskController,
                  readOnly: true,
                  onTap: _selectDaskDate,
                  decoration: _inputDecoration(
                    label: 'DASK Bitiş Tarihi',
                    hintText: 'Tarih seçiniz (YYYY-AA-GG)',
                    prefixIcon: Icons.calendar_month_outlined,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Kaydet',
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
