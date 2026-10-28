import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/lease_service.dart';

class AssignTenantScreen extends StatefulWidget {
  final int propertyId;

  const AssignTenantScreen({super.key, required this.propertyId});

  @override
  State<AssignTenantScreen> createState() => _AssignTenantScreenState();
}

class _AssignTenantScreenState extends State<AssignTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color subtleBorder = Color(0xFFE5E0D8);

  final TextEditingController _tenantNameController = TextEditingController();
  final TextEditingController _tenantEmailController = TextEditingController();
  final TextEditingController _rentAmountController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to today's date in YYYY-MM-DD format
    final now = DateTime.now();
    _startDateController.text =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _rentAmountController.dispose();
    _depositController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    try {
      if (_startDateController.text.isNotEmpty) {
        initial = DateTime.parse(_startDateController.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        _startDateController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tenantName = _tenantNameController.text.trim();
    final email = _tenantEmailController.text.trim();
    final rentAmount = double.tryParse(_rentAmountController.text.trim());
    final startDate = _startDateController.text.trim();

    if (rentAmount == null || rentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir kira bedeli giriniz'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final depositText = _depositController.text.trim();
    final depositAmount = depositText.isNotEmpty ? double.tryParse(depositText) : null;

    setState(() => _isLoading = true);

    try {
      final lease = await LeaseService().createLease(
        widget.propertyId,
        tenantName,
        email,
        rentAmount,
        startDate,
        depositAmount: depositAmount,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sözleşme Oluşturuldu'),
          content: SelectableText(
            'Sözleşme oluşturuldu! Kiracınıza şu davet kodunu iletin: ${lease.inviteCode ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );

      if (!mounted) return;
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
    required IconData prefixIcon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: vibrantBlue),
      suffixIcon: suffixIcon,
      filled: true,
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
          'Kiracı Ata',
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
                  'Kira Sözleşmesi Bilgileri',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mülke atanacak kiracının e-postasını, kira bedelini ve başlangıç tarihini giriniz.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Tenant Name
                TextFormField(
                  controller: _tenantNameController,
                  keyboardType: TextInputType.name,
                  decoration: _inputDecoration(
                    label: 'Kiracı Adı Soyadı',
                    hintText: 'Örn: Ahmet Yılmaz',
                    prefixIcon: Icons.person_outline,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen kiracının adını ve soyadını giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tenant Email
                TextFormField(
                  controller: _tenantEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    label: 'Kiracı E-posta',
                    hintText: 'ornek@email.com',
                    prefixIcon: Icons.email_outlined,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen kiracının e-posta adresini giriniz';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Geçerli bir e-posta adresi giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Rent Amount
                TextFormField(
                  controller: _rentAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(
                    label: 'Kira Bedeli (TL)',
                    hintText: 'Örn: 15000',
                    prefixIcon: Icons.payments_outlined,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen kira bedelini giriniz';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Geçerli bir tutar giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Deposit Amount
                TextFormField(
                  controller: _depositController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(
                    label: 'Depozito Tutarı (TL)',
                    hintText: 'Örn: 25000',
                    prefixIcon: Icons.shield_outlined,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),

                // Start Date
                TextFormField(
                  controller: _startDateController,
                  decoration: _inputDecoration(
                    label: 'Başlangıç Tarihi',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icons.calendar_today_outlined,
                    isDark: isDark,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range, color: vibrantBlue),
                      onPressed: _pickDate,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen başlangıç tarihini giriniz';
                    }
                    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                    if (!dateRegex.hasMatch(value.trim())) {
                      return 'Tarih formatı YYYY-MM-DD olmalıdır';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Save Button
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
