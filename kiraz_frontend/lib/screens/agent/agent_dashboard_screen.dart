import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../models/dashboard_stats.dart';
import '../../models/notification_model.dart';
import '../../models/property.dart';
import '../../models/property_delegation.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/delegation_service.dart';
import '../../services/notification_service.dart';
import '../../services/property_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/cherry_logo.dart';
import '../auth/login_screen.dart';
import '../landlord/assign_tenant_screen.dart';
import '../landlord/property_detail_screen.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  static const Color ivoryBg = Color(0xFFFBF8F1);
  static const Color darkNavy = Color(0xFF161F33);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color vibrantBlue = Color(0xFF1E50CE);
  static const Color cardBorder = Color(0xFFE5E0D8);
  static const Color darkCardBorder = Color(0xFF334155);

  final DashboardService _dashboardService = DashboardService();
  final DelegationService _delegationService = DelegationService();
  final PropertyService _propertyService = PropertyService();
  final NotificationService _notificationService = NotificationService();

  int? _userId;
  String _userName = 'Emlak Danışmanı';
  String _userEmail = '';
  DashboardStats? _stats;
  List<PropertyDelegation> _activeDelegations = [];
  List<Property> _agentProperties = [];
  List<AppNotification> _notifications = [];
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAgentData();
  }

  Future<void> _loadAgentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('fullName') ?? 'Emlak Danışmanı';
      _userEmail = prefs.getString('email') ?? '';
      _userId = prefs.getInt('userId');

      if (_userId != null) {
        final results = await Future.wait([
          _dashboardService.getAgentStats(_userId!).catchError((_) => DashboardStats(
                totalPaid: 0,
                upcoming: 0,
                pendingApproval: 0,
                overdue: 0,
              )),
          _delegationService.getActiveDelegationsForAgent(_userId!).catchError((_) => <PropertyDelegation>[]),
          _propertyService.getPropertiesForAgent(_userId!).catchError((_) => <Property>[]),
          _notificationService.getUnreadNotifications(_userId!).catchError((_) => <AppNotification>[]),
        ]);

        if (!mounted) return;
        setState(() {
          _stats = results[0] as DashboardStats;
          _activeDelegations = results[1] as List<PropertyDelegation>;
          _agentProperties = results[2] as List<Property>;
          _notifications = results[3] as List<AppNotification>;
          _unreadNotificationsCount = _notifications.length;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showNotificationsSheet(bool isDark) {
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                            color: vibrantBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: vibrantBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Bildirimler',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Text(
                          'Okunmamış bildirim bulunmuyor.',
                          style: GoogleFonts.inter(color: textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final notif = _notifications[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.title,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif.message,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cardBg = isDark ? darkCardBg : Colors.white;
    final borderColor = isDark ? darkCardBorder : cardBorder;
    final textPrimary = isDark ? Colors.white : darkNavy;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkNavy : ivoryBg;
    final cardBg = isDark ? darkCardBg : Colors.white;
    final textPrimary = isDark ? Colors.white : darkNavy;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? darkCardBorder : cardBorder;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const CherryLogo(size: 28, color: vibrantBlue),
            const SizedBox(width: 10),
            Text(
              'kiraZ',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: vibrantBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AGENT / B2B',
                style: GoogleFonts.inter(
                  color: vibrantBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Aydınlık Mod' : 'Karanlık Mod',
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: textPrimary,
            ),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () => _showNotificationsSheet(isDark),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, color: textPrimary),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadNotificationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
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
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAgentData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadAgentData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agent Profile Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                              : [const Color(0xFF1E50CE), const Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: vibrantBlue.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.real_estate_agent_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Hoş Geldiniz,',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'ID: ${_userId ?? '-'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _userName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Yetkili Portföy ve Sözleşme Yöneticisi',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Stats Row
                    Row(
                      children: [
                        _buildKpiCard(
                          title: 'Atanan Mülkler',
                          value: '${_activeDelegations.isNotEmpty ? _activeDelegations.length : _agentProperties.length}',
                          icon: Icons.apartment_rounded,
                          color: const Color(0xFF2563EB),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 14),
                        _buildKpiCard(
                          title: 'Dolu Mülkler',
                          value: '${_agentProperties.where((p) => p.isOccupied).length}',
                          icon: Icons.key_rounded,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildKpiCard(
                          title: 'Bekleyen Onaylar',
                          value: '${_stats?.pendingApproval.toStringAsFixed(0) ?? '0'} TL',
                          icon: Icons.hourglass_top_rounded,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 14),
                        _buildKpiCard(
                          title: 'Gecikmedeki Borç',
                          value: '${(_stats?.overdue ?? 0).toStringAsFixed(0)} TL',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFEF4444),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Section: Atanan Mülklerim (Delegated Properties)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atanan Portföyüm',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'Yalnızca vekalet verilen mülkleriniz listelenir',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: vibrantBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_activeDelegations.isNotEmpty ? _activeDelegations.length : _agentProperties.length} Mülk',
                            style: GoogleFonts.inter(
                              color: vibrantBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (_activeDelegations.isEmpty && _agentProperties.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.home_work_outlined,
                              size: 54,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Henüz Size Atanmış Bir Mülk Yok',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ev sahipleri mülk detayından e-posta adresinizi ($_userEmail) veya ID numaranızı ($_userId) girerek size yetki verebilir.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activeDelegations.isNotEmpty
                            ? _activeDelegations.length
                            : _agentProperties.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          if (_activeDelegations.isNotEmpty) {
                            final delegation = _activeDelegations[index];
                            final prop = Property(
                              id: delegation.propertyId,
                              name: delegation.propertyTitle,
                              address: delegation.propertyAddress ?? '',
                            );
                            return _buildDelegatedPropertyCard(
                              delegation: delegation,
                              property: prop,
                              isDark: isDark,
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                            );
                          } else {
                            final prop = _agentProperties[index];
                            return _buildSimpleAgentPropertyCard(
                              property: prop,
                              isDark: isDark,
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDelegatedPropertyCard({
    required PropertyDelegation delegation,
    required Property property,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vibrantBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: vibrantBlue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delegation.propertyTitle.isNotEmpty
                          ? delegation.propertyTitle
                          : 'Mülk #${delegation.propertyId}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            delegation.propertyAddress ?? 'Adres belirtilmemiş',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Yetkili',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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

          // Landlord & Delegation info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vekalet Veren (Ev Sahibi)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      delegation.grantedByName ?? 'Mülk Sahibi',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yetki Başlangıcı',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      delegation.startDate ?? '-',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons: Assign Tenant / Create Lease & View Property
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignTenantScreen(propertyId: delegation.propertyId),
                      ),
                    );
                    if (res == true) {
                      _loadAgentData();
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Kiracı / Sözleşme Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailScreen(property: property),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Detay'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: vibrantBlue,
                  side: const BorderSide(color: vibrantBlue),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAgentPropertyCard({
    required Property property,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.home_work_rounded, color: vibrantBlue, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      property.address,
                      style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignTenantScreen(propertyId: property.id),
                      ),
                    );
                    if (res == true) {
                      _loadAgentData();
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Kiracı Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vibrantBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailScreen(property: property),
                    ),
                  );
                },
                child: const Text('Detay'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
