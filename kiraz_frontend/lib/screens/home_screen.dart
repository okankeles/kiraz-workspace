import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_data.dart';
import '../main.dart';
import '../models/financial_transaction.dart';
import '../models/mock_rent_period.dart';
import '../models/user_role.dart';
import '../theme/app_colors.dart';
import '../widgets/cherry_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialRole});

  final UserRole? initialRole;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserRole currentRole;
  int _selectedIndex = 0;
  int _paymentFilterIndex = 0; // 0: Tümü, 1: Ödenen, 2: Geciken, 3: Bekleyen

  @override
  void initState() {
    super.initState();
    currentRole = widget.initialRole ?? MockData.userRoles.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            CherryLogo(
              size: 34,
              color: isDark ? AppColors.secondaryLight : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'kiraZ',
              style: GoogleFonts.poppins(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: -1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Açık Tema' : 'Koyu Tema',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 24,
            ),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.light;
            },
          ),
          IconButton(
            icon: const Icon(Icons.switch_account, size: 26),
            onPressed: _showAccountSwitcher,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Özet'),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work),
            label: 'Mülkler',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Kiracılar'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Bakım'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menü'),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAccountSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hesap Değiştir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: MockData.userRoles.length,
                  itemBuilder: (context, index) {
                    final role = MockData.userRoles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          role.userName.isNotEmpty
                              ? role.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${role.userName} (${role.propertyName})',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        role.roleType.name.toUpperCase(),
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        setState(() => currentRole = role);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 46,
            backgroundColor: isDark ? AppColors.iceBlueDark : AppColors.iceBlue,
            child: Text(
              currentRole.userName.isNotEmpty
                  ? currentRole.userName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: isDark ? AppColors.secondaryLight : AppColors.primary,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            currentRole.userName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            currentRole.propertyName,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Hesap Ayarları'),
                trailing: Icon(Icons.chevron_right),
              ),
              Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Şifre Değiştir'),
                trailing: Icon(Icons.chevron_right),
              ),
              Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              const ListTile(
                leading: Icon(Icons.logout, color: AppColors.danger),
                title: Text(
                  'Çıkış Yap',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return _buildPropertiesTab();
      case 2:
        return _buildEmptyState(
          icon: Icons.person,
          title: 'Kiracılarınızı ekleyin!',
          subtitle: 'Kiracılarınızı mülklerinizle eşleştirin ve ödemelerini kolayca izleyin.',
          buttonText: 'Kiracı Ekle',
        );
      case 3:
        return _buildEmptyState(
          icon: Icons.build,
          title: 'Bakım talepleri burada görünecek',
          subtitle: 'Arıza ve bakım taleplerini oluşturun, sürecini adım adım takip edin.',
          buttonText: 'Talep Oluştur',
        );
      case 4:
        return _buildProfileTab();
    }
    return _buildDashboard();
  }

  Widget _buildPropertiesTab() {
    final properties = MockData.properties;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kayıtlı Mülklerim',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toplam ${properties.length} bağımsız bölüm',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textMutedLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                _showSnack('Yeni Mülk Ekleme formu açılıyor...');
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Mülk Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.primaryLight
                    : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...properties.map((prop) {
          final propName = prop['name'] as String;
          final building = prop['building'] ?? '';
          final unit = prop['unit'] ?? '';
          final address = prop['address'] ?? '';
          final tenant = prop['tenant'] ?? '';
          final tenantPhone = prop['tenantPhone'] ?? '';
          final paymentCycle = prop['paymentCycle'] ?? 'Aylık';
          final rentAmount = prop['rentAmount'] ?? 0.0;
          final deposit = prop['deposit'] ?? '-';
          final daskExpiry = prop['daskExpiry'] ?? '-';

          final isUrgentDask = daskExpiry.contains('15 gün');

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.iceBlueDark
                              : AppColors.iceBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.home_work_outlined,
                          color: isDark
                              ? AppColors.secondaryLight
                              : AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              propName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$building • $unit',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.iceBlueDark
                              : AppColors.iceBlue,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.secondaryLight.withValues(
                                    alpha: 0.3,
                                  )
                                : AppColors.iceBlueBorder,
                          ),
                        ),
                        child: Text(
                          paymentCycle,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.secondaryLight
                                : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141F36)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _propInfoTile(
                          icon: Icons.person_outline,
                          title: 'Kiracı',
                          value: tenant,
                          subValue: tenantPhone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _propInfoTile(
                          icon: Icons.payments_outlined,
                          title: 'Kira Tutarı',
                          value: '${_formatAmount(rentAmount)} TL',
                          subValue: paymentCycle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _propInfoTile(
                          icon: Icons.shield_outlined,
                          title: 'DASK Durumu',
                          value: daskExpiry,
                          isAlert: isUrgentDask,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _propInfoTile(
                          icon: Icons.savings_outlined,
                          title: 'Depozito',
                          value: deposit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _propInfoTile({
    required IconData icon,
    required String title,
    required String value,
    String? subValue,
    bool isAlert = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isAlert
            ? (isDark ? const Color(0xFF2E1A1A) : AppColors.warningBg)
            : (isDark ? const Color(0xFF162238) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert
              ? (isDark
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : const Color(0xFFFDE68A))
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isAlert ? AppColors.warning : AppColors.textMutedLight,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isAlert
                      ? AppColors.warning
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isAlert
                  ? AppColors.warning
                  : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subValue != null) ...[
            const SizedBox(height: 1),
            Text(
              subValue,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textMutedLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 176,
              height: 176,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: isDark
                          ? AppColors.iceBlueDark
                          : AppColors.iceBlue,
                      child: Icon(
                        icon,
                        size: 72,
                        color: isDark
                            ? AppColors.secondaryLight
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: isDark
                    ? AppColors.primaryLight
                    : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    bool isHero = false,
    String? badgeText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isHero) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText ?? 'Bu Ay',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.iceBlueDark : AppColors.iceBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.secondaryLight
                          : AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowTab(String text, int index) {
    final selected = _paymentFilterIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _paymentFilterIndex = index),
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          children: [
            Text(
              text,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? (isDark ? AppColors.secondaryLight : AppColors.primary)
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textMutedLight),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2.5,
              width: 28,
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? AppColors.secondaryLight : AppColors.primary)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final isAdmin = currentRole.roleType == RoleType.admin;
    final isLandlord = currentRole.roleType == RoleType.landlord;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final periodsPool = isLandlord
        ? MockData.rentPeriods
        : MockData.rentPeriods
              .where((r) => r.propertyName == currentRole.propertyName)
              .toList();
    double sumFor(PaymentStatus s) => periodsPool
        .where((r) => r.status == s)
        .fold(0.0, (sum, item) => sum + item.amount);
    final overdue = sumFor(PaymentStatus.unpaid);
    final pendingSum = sumFor(PaymentStatus.pending);
    final filteredPeriods = periodsPool.where((r) {
      switch (_paymentFilterIndex) {
        case 1:
          return r.status == PaymentStatus.paid;
        case 2:
          return r.status == PaymentStatus.unpaid;
        case 3:
          return r.status == PaymentStatus.pending;
        default:
          return true;
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İyi Akşamlar, ${currentRole.userName}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 20),
          if (isAdmin)
            _buildAdminView()
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: isLandlord
                  ? [
                      _metricTile(
                        label: 'Tahsil Edilen',
                        value: '${_formatAmount(MockData.totalIncome)} TL',
                        isHero: true,
                        badgeText: 'Toplam',
                      ),
                      _metricTile(
                        label: 'Yaklaşan',
                        value: '15.000 TL',
                        badgeText: 'Bu Ay',
                      ),
                      _metricTile(
                        label: 'Bekleyen Onay',
                        value: '${_formatAmount(pendingSum)} TL',
                        badgeText: 'Dekont',
                      ),
                      _metricTile(
                        label: 'Geciken Alacak',
                        value: '${_formatAmount(overdue)} TL',
                        badgeText: 'Geciken',
                      ),
                    ]
                  : [
                      _metricTile(
                        label: 'Ödenen Kira',
                        value: '30.000 TL',
                        isHero: true,
                        badgeText: '2026',
                      ),
                      _metricTile(
                        label: 'Sıradaki Ödeme',
                        value: '15.000 TL',
                        badgeText: 'Ekim',
                      ),
                      _metricTile(
                        label: 'Toplam Borç',
                        value: '${_formatAmount(overdue + pendingSum)} TL',
                        badgeText: 'Kalan',
                      ),
                      _metricTile(
                        label: 'Geciken Borç',
                        value: '${_formatAmount(overdue)} TL',
                        badgeText: 'Geciken',
                      ),
                    ],
            ),
            const SizedBox(height: 24),
            if (currentRole.roleType == RoleType.landlord)
              _buildLandlordView()
            else
              _buildTenantView(),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Kiracı Ödeme Akışı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _flowTab('Tümü', 0),
                        _flowTab('Ödenen', 1),
                        _flowTab('Geciken', 2),
                        _flowTab('Bekleyen', 3),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white, thickness: 3, height: 24),
                if (isLandlord)
                  _buildLandlordPropertiesRentSection()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPeriods.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.white,
                      thickness: 3,
                      height: 24,
                    ),
                    itemBuilder: (context, index) =>
                        _buildRentCard(filteredPeriods[index]),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color;
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sistem Toplam Hacmi',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textMutedLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1.250.000 TL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktif Mülk Sayısı',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textMutedLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '142',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Sistemdeki Tüm Mülkler ve Akışlar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MockData.properties.length,
          itemBuilder: (context, index) {
            final prop = MockData.properties[index];
            final propName = prop['name'] as String;
            final landlordName = prop['landlord'] ?? '-';
            final tenantName = prop['tenant'] ?? '-';
            final propPeriods = MockData.rentPeriods
                .where((r) => r.propertyName == propName)
                .toList();

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.iceBlueDark : AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    propName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    "Ev Sahibi: $landlordName  •  Kiracı: $tenantName",
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 13,
                    ),
                  ),
                  children: [
                    if (propPeriods.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Kayıtlı kira dönemi bulunmuyor.',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textMutedLight,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: propPeriods.length,
                        itemBuilder: (context, periodIndex) {
                          final period = propPeriods[periodIndex];
                          final Color statusColor;
                          final Color statusBg;
                          final String statusLabel;

                          switch (period.status) {
                            case PaymentStatus.paid:
                              statusColor = AppColors.success;
                              statusBg = isDark
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.successBg;
                              statusLabel = 'Ödendi';
                            case PaymentStatus.unpaid:
                              statusColor = AppColors.danger;
                              statusBg = isDark
                                  ? AppColors.danger.withValues(alpha: 0.15)
                                  : AppColors.dangerBg;
                              statusLabel = 'Ödenmedi';
                            case PaymentStatus.pending:
                              statusColor = AppColors.warning;
                              statusBg = isDark
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : AppColors.warningBg;
                              statusLabel = 'Bekliyor';
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      period.monthName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatAmount(period.amount)} TL',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _uploadReceipt(RentPeriod period) async {
    if (period.status != PaymentStatus.unpaid) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        period.receiptImagePath = image.path;
        period.status = PaymentStatus.pending;

        MockData.transactions.add(
          FinancialTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            amount: period.amount,
            date: DateTime.now(),
            propertyName: currentRole.propertyName,
            status: TxStatus.pending,
            hasReceiptImage: true,
            rentPeriodId: period.id,
          ),
        );
        setState(() {});
        _showSnack('Dekont başarıyla yüklendi, ev sahibi onayı bekleniyor.');
      }
    } catch (e) {
      _showSnack('Mac ortamında galeri açılamadı, demo dekont oluşturuldu.');
      period.receiptImagePath = 'demo_mock_image';
      period.status = PaymentStatus.pending;

      MockData.transactions.add(
        FinancialTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: period.amount,
          date: DateTime.now(),
          propertyName: currentRole.propertyName,
          status: TxStatus.pending,
          hasReceiptImage: true,
          rentPeriodId: period.id,
        ),
      );
      setState(() {});
    }
  }

  void _showReceiptViewerDialog(RentPeriod period) {
    if (period.receiptImagePath == null) return;

    final isDemoMock = period.receiptImagePath == 'demo_mock_image';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                title: Text(
                  '${period.propertyName} Dekontu',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              isDemoMock
                  ? Container(
                      width: double.infinity,
                      height: 300,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.iceBlue,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.receipt_long,
                            size: 80,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Demo Dekont Görseli",
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      color: Colors.black12,
                      child: Image.file(
                        File(period.receiptImagePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${period.monthName} - ${_formatAmount(period.amount)} TL',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _approvePeriod(period);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Dekontu Onayla',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _approve(FinancialTransaction tx) {
    setState(() {
      tx.status = TxStatus.approved;
      for (final p in MockData.rentPeriods) {
        if (p.id == tx.rentPeriodId) p.status = PaymentStatus.paid;
      }
      MockData.totalIncome += tx.amount;
      MockData.pendingCollection = math
          .max(0, MockData.pendingCollection - tx.amount)
          .toDouble();
    });
    _showSnack('Ödeme onaylandı, bakiye güncellendi.');
  }

  void _approvePeriod(RentPeriod period) {
    setState(() {
      period.status = PaymentStatus.paid;
      for (final tx in MockData.transactions) {
        if (tx.rentPeriodId == period.id) {
          tx.status = TxStatus.approved;
        }
      }
      MockData.totalIncome += period.amount;
      MockData.pendingCollection = math
          .max(0, MockData.pendingCollection - period.amount)
          .toDouble();
    });
    _showSnack('${period.propertyName} ${period.monthName} kirası onaylandı.');
  }

  /// Formats e.g. 15000.0 -> "15.000", 1234.5 -> "1.234,5".
  String _formatAmount(num value) {
    final isWhole = value == value.roundToDouble();
    final fixed = isWhole ? value.round().toString() : value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
  }

  Widget _buildLandlordView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingTx = MockData.transactions
        .where((tx) => tx.status == TxStatus.pending)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.iceBlueDark : AppColors.iceBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, color: AppColors.primary),
            ),
            title: const Text(
              'Şişli Daire (D:4) - DASK Poliçesi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Güneş Apt. No:112 D:4 • Bitişe 15 gün kaldı',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Yenile'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Onay Bekleyen Dekontlar',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (pendingTx.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Bekleyen onay yok',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textMutedLight,
                ),
              ),
            ),
          )
        else
          ...pendingTx.map((tx) {
            final period = MockData.rentPeriods
                .where((p) => p.id == tx.rentPeriodId)
                .firstOrNull;
            final propertyName = period?.propertyName ?? tx.propertyName;
            final propertyInfo = MockData.properties.firstWhere(
              (p) => p['name'] == propertyName,
              orElse: () => {'tenant': 'Bilinmiyor'},
            );
            final monthName = period?.monthName ?? '';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Row(
                  children: [
                    if (period != null && period.receiptImagePath != null) ...[
                      GestureDetector(
                        onTap: () => _showReceiptViewerDialog(period),
                        child: period.receiptImagePath == 'demo_mock_image'
                            ? Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.iceBlueDark
                                      : AppColors.iceBlue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(period.receiptImagePath!),
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (tx.hasReceiptImage) ...[
                      const Icon(
                        Icons.receipt_long,
                        color: AppColors.primary,
                        size: 36,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        '${_formatAmount(tx.amount)} TL - Dekont Yüklendi',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "$propertyName  •  Kiracı: ${propertyInfo['tenant']}\n$monthName",
                    style: const TextStyle(height: 1.4),
                  ),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _approve(tx),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Onayla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _contractRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTenantView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kira Sözleşmesi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _contractRow(
              Icons.calendar_today,
              'Sözleşme Bitiş',
              '12 Ağustos 2027',
            ),
            const SizedBox(height: 16),
            _contractRow(
              Icons.payments,
              'Aylık Kira',
              '${_formatAmount(15000)} TL',
            ),
            const SizedBox(height: 16),
            _contractRow(Icons.home_work, 'Mülk', currentRole.propertyName),
          ],
        ),
      ),
    );
  }

  Widget _buildLandlordPropertiesRentSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: MockData.properties.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white, thickness: 3, height: 24),
      itemBuilder: (context, propertyIndex) {
        final property = MockData.properties[propertyIndex];
        final propName = property['name'] as String;
        final tenantName = property['tenant'] as String;
        final building = property['building'] ?? '';
        final unit = property['unit'] ?? '';
        final address = property['address'] ?? '';
        final paymentCycle = property['paymentCycle'] ?? 'Aylık';

        final periods = MockData.rentPeriods.where((r) {
          if (r.propertyName != propName) return false;
          switch (_paymentFilterIndex) {
            case 1:
              return r.status == PaymentStatus.paid;
            case 2:
              return r.status == PaymentStatus.unpaid;
            case 3:
              return r.status == PaymentStatus.pending;
            default:
              return true;
          }
        }).toList();

        return Card(
          elevation: 0,
          color: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.iceBlueDark : AppColors.iceBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      propName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.iceBlueDark : AppColors.iceBlue,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.iceBlueBorder,
                      ),
                    ),
                    child: Text(
                      paymentCycle,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$building • $unit',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 $address',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textMutedLight,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kiracı: $tenantName',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                if (periods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Bu filtreye uygun kira dönemi bulunamadı.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textMutedLight,
                        fontSize: 13,
                      ),
                    ),
                  )
                else ...[
                  const Divider(color: Colors.white, thickness: 3, height: 24),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: periods.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.white,
                      thickness: 3,
                      height: 24,
                    ),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      return _buildRentCard(period, showApproveButton: true);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRentCard(RentPeriod period, {bool showApproveButton = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget status;
    switch (period.status) {
      case PaymentStatus.paid:
        status = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.successBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Ödendi',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        );
      case PaymentStatus.pending:
        final hasImage = period.receiptImagePath != null;
        final isDemoMock = period.receiptImagePath == 'demo_mock_image';
        final Widget thumbnail = hasImage
            ? GestureDetector(
                onTap: () => _showReceiptViewerDialog(period),
                child: isDemoMock
                    ? Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.iceBlueDark
                              : AppColors.iceBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(period.receiptImagePath!),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
              )
            : const SizedBox.shrink();

        if (showApproveButton && currentRole.roleType == RoleType.landlord) {
          status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage) ...[thumbnail, const SizedBox(width: 8)],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Bekliyor',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _approvePeriod(period),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Onayla',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        } else {
          status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage) ...[thumbnail, const SizedBox(width: 8)],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Onay Bekliyor',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        }
      case PaymentStatus.unpaid:
        status = currentRole.roleType != RoleType.tenant
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.danger.withValues(alpha: 0.15)
                      : AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ödenmedi',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: () => _uploadReceipt(period),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Dekont Yükle',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              );
    }
    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(side: BorderSide.none),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.monthName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatAmount(period.amount)} TL',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            status,
          ],
        ),
      ),
    );
  }
}
