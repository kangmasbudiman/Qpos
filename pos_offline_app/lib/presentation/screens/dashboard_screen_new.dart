import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/auth_controller.dart';
import '../controllers/pos_controller.dart';
import '../widgets/connectivity_indicator.dart';
import '../widgets/payzen_logo.dart';
import '../widgets/subscription_banner.dart';
import '../../core/localization/app_strings.dart';
import '../../services/auth/auth_service.dart';
import '../../services/language/language_service.dart';
import '../../services/sync/sync_service.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../services/database/database_helper.dart';
import '../../services/inventory/low_stock_notification_service.dart';
import '../../services/shift/shift_service.dart';
import '../widgets/branch_filter_bar.dart';

class DashboardScreenNew extends StatefulWidget {
  const DashboardScreenNew({Key? key}) : super(key: key);

  @override
  State<DashboardScreenNew> createState() => _DashboardScreenNewState();
}

class _DashboardScreenNewState extends State<DashboardScreenNew> {
  int _selectedNav = 0;
  late DashboardService _dashboardService;

  // Semua menu yang tersedia
  static const _allNavItems = [
    _NavItem(icon: Icons.home_rounded,              labelKey: 'navHome',      route: null),
    _NavItem(icon: Icons.point_of_sale_rounded,     labelKey: 'navPos',       route: '/pos'),
    _NavItem(icon: Icons.inventory_2_rounded,       labelKey: 'navProducts',  route: '/inventory'),
    _NavItem(icon: Icons.category_rounded,          labelKey: 'navCategories',route: '/categories'),
    _NavItem(icon: Icons.local_shipping_rounded,    labelKey: 'navPurchase',  route: '/purchases'),
    _NavItem(icon: Icons.fact_check_rounded,        labelKey: 'navOpname',    route: '/stock-opname'),
    _NavItem(icon: Icons.swap_horiz_rounded,        labelKey: 'navTransfer',  route: '/stock-transfer'),
    _NavItem(icon: Icons.receipt_long_rounded,      labelKey: 'navHistory',   route: '/sales-report'),
    _NavItem(icon: Icons.show_chart_rounded,        labelKey: 'navProfitLoss',route: '/profit-loss'),
    _NavItem(icon: Icons.stars_rounded,             labelKey: 'navLoyalty',   route: '/loyalty'),
    _NavItem(icon: Icons.access_time_rounded,       labelKey: 'navShift',     route: '/shift-history'),
    _NavItem(icon: Icons.settings_rounded,          labelKey: 'navSettings',  route: '/settings'),
  ];

  // Menu yang boleh diakses cashier
  static const _cashierNavItems = [
    _NavItem(icon: Icons.home_rounded,              labelKey: 'navHome',    route: null),
    _NavItem(icon: Icons.point_of_sale_rounded,     labelKey: 'navPos',     route: '/pos'),
    _NavItem(icon: Icons.receipt_long_rounded,      labelKey: 'navHistory', route: '/sales-report'),
    _NavItem(icon: Icons.stars_rounded,             labelKey: 'navLoyalty', route: '/loyalty'),
    _NavItem(icon: Icons.access_time_rounded,       labelKey: 'navShift',   route: '/shift-history'),
    _NavItem(icon: Icons.settings_rounded,          labelKey: 'navSettings',route: '/settings'),
  ];

  List<_NavItem> get _navItems {
    final user = Get.find<AuthService>().currentUser;
    if (user?.isCashier == true) return _cashierNavItems;
    return _allNavItems;
  }

  @override
  void initState() {
    super.initState();
    Get.put(AuthController());
    Get.put(POSController());
    _dashboardService = Get.find<DashboardService>();
    // Refresh data setiap kali dashboard dibuka
    _dashboardService.loadDashboardData();
    // Cek shift aktif — tanya buka shift jika belum ada
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkShift());
  }

  Future<void> _checkShift() async {
    try {
      // Fitur shift hanya untuk Business tier
      final sub = Get.find<AuthService>().subscription;
      if (!(sub?.hasFeature('shift') ?? true)) return;

      final shiftSvc = Get.find<ShiftService>();
      await shiftSvc.refresh();
      if (shiftSvc.currentShift.value == null && mounted) {
        _showOpenShiftPrompt(shiftSvc);
      }
    } catch (_) {}
  }

  void _showOpenShiftPrompt(ShiftService shiftSvc) {
    final cashCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.access_time_rounded, color: Color(0xFF4CAF50), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Buka Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Belum ada shift aktif hari ini.\nMasukkan modal kas awal:',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Modal Awal (Rp)',
                prefixIcon: const Icon(Icons.payments_rounded, color: Color(0xFF4CAF50)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Nanti', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final cash = double.tryParse(cashCtrl.text) ?? 0;
              Get.back();
              try {
                await shiftSvc.openShift(cash);
                Get.snackbar('Shift Dibuka', 'Selamat bekerja!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF4CAF50),
                    colorText: Colors.white);
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Buka Shift'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8F9FA),
      body: Row(
        children: [
          _buildSidebar(isTablet),
          Expanded(child: _buildContent(context, size, isTablet)),
        ],
      ),
    );
  }

  // ── SIDEBAR ─────────────────────────────────────────────────────────────

  Widget _buildSidebar(bool isTablet) {
    final authService = Get.find<AuthService>();
    final user = authService.currentUser;
    final sidebarW = isTablet ? 80.0 : 70.0;

    return Container(
      width: sidebarW,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E2235),
            const Color(0xFF2D3142),
            const Color(0xFF1E2235),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo Payzen
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: const PayzenLogo.icon(size: 40),
            ),
            const SizedBox(height: 4),
            const Text(
              'PAYZEN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 28),
            // Divider dengan gradient effect
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF6B35),
                      Color(0xFFFF6B35),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _navItems.asMap().entries.map((e) => 
                    _buildNavItem(e.key, e.value)).toList(),
              ),
            ),
            // Divider bawah
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFFFF6B35),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Connectivity indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: const ConnectivityDot(),
            ),
            const SizedBox(height: 16),
            // User avatar
            GestureDetector(
              onTap: () => _showProfileSheet(user?.name ?? '', user?.role ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (user?.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user != null ? user.name.split(' ').first : 'User',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final selected = _selectedNav == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedNav = index);
        if (item.route != null) {
          Get.toNamed(item.route!)?.then((_) => setState(() => _selectedNav = 0));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Active indicator - gradient pill di kiri
            if (selected)
              Positioned(
                left: 0,
                child: Container(
                  width: 5,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF6B35),
                        Color(0xFFFF8C42),
                        Color(0xFFFF6B35),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                ),
              ),
            // Icon + label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon dengan efek scale saat active
                AnimatedScale(
                  scale: selected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: selected
                        ? const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF6B35),
                                Color(0xFFFF8C42),
                                Color(0xFFFFA05F),
                              ],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFF6B35),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          )
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                    child: Builder(builder: (ctx) {
                      final iconWidget = Icon(
                        item.icon,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        size: selected ? 22 : 20,
                      );
                      if (item.route == '/inventory') {
                        try {
                          final notifSvc = Get.find<LowStockNotificationService>();
                          return notifSvc.buildBadge(child: iconWidget);
                        } catch (_) {
                          return iconWidget;
                        }
                      }
                      return iconWidget;
                    }),
                  ),
                ),
                const SizedBox(height: 5),
                // Label dengan weight yang berbeda
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFFFF6B35)
                        : Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── KONTEN ──────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, Size size, bool isTablet) {
    final authService = Get.find<AuthService>();
    final user = authService.currentUser;
    final branch = authService.selectedBranch;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? AppStrings.t('greetMorning')
        : now.hour < 15
            ? AppStrings.t('greetAfternoon')
            : now.hour < 19
                ? AppStrings.t('greetEvening')
                : AppStrings.t('greetNight');
    final isCashier = user?.isCashier == true;

    return Obx(() {
      // subscribe locale agar content rebuild saat bahasa berubah
      try { Get.find<LanguageService>().locale.value; } catch (_) {}
      return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SubscriptionBanner(),
          _buildHeroBanner(user, branch, greeting, now, isTablet),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 16,
              0,
              isTablet ? 24 : 16,
              isTablet ? 24 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branch filter (owner only)
                BranchFilterBar(onChanged: () => _dashboardService.loadDashboardData()),
                _buildStatCards(isTablet, isCashier: isCashier),
                const SizedBox(height: 20),
                if (!isCashier) ...[
                  _buildLowStockAlert(isTablet),
                  const SizedBox(height: 20),
                  _buildWeeklySalesChart(isTablet),
                  const SizedBox(height: 20),
                  _buildTopProducts(isTablet),
                  const SizedBox(height: 20),
                ],
                _buildQuickActions(context, isTablet, isCashier: isCashier, userRole: user?.role ?? ''),
                const SizedBox(height: 20),
                _buildRecentSection(isCashier: isCashier),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
    }); // end Obx
  }

  Widget _buildHeroBanner(dynamic user, dynamic branch, String greeting,
      DateTime now, bool isTablet) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (ctx, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: Builder(builder: (ctx) {
      final heroDark = Theme.of(ctx).brightness == Brightness.dark;
      return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, isTablet ? 32 : 24, isTablet ? 24 : 16, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: heroDark ? const Color(0xFF242838) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFF6B35), size: 12),
                            const SizedBox(width: 5),
                            Text(greeting,
                                style: const TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: heroDark ? const Color(0xFF242838) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12,
                                color: heroDark ? const Color(0xFF8B8FA8) : Colors.grey[500]),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('dd MMM', 'id_ID').format(now),
                              style: TextStyle(fontSize: 11,
                                  color: heroDark ? const Color(0xFF8B8FA8) : Colors.grey[600],
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user != null ? user.name.split(' ').first : 'User',
                    style: TextStyle(
                      color: heroDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded, size: 12,
                          color: heroDark ? const Color(0xFF5A5F7A) : Colors.grey[400]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          branch?.name ?? user?.companyName ?? 'POS System',
                          style: TextStyle(fontSize: 11,
                              color: heroDark ? const Color(0xFF8B8FA8) : Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Subscription tier + masa berlaku
                  const SizedBox(height: 8),
                  Obx(() {
                    final authService = Get.find<AuthService>();
                    final sub = authService.subscriptionRx.value;
                    if (sub == null) return const SizedBox.shrink();

                    // Tier badge
                    final tier = sub.tier;
                    final tierLabel = tier == 'business' ? 'Business' : 'Starter';
                    final tierColor = tier == 'business'
                        ? const Color(0xFF9C27B0)
                        : const Color(0xFF2196F3);

                    // Masa berlaku text
                    String masaLabel;
                    Color masaColor;
                    IconData masaIcon;

                    if (sub.status == 'trial') {
                      final days = sub.daysRemaining;
                      masaLabel = 'Trial: $days hr lagi';
                      masaColor = days <= 3
                          ? const Color(0xFFE53935)
                          : const Color(0xFF43A047);
                      masaIcon = Icons.hourglass_bottom_rounded;
                    } else if (sub.status == 'active') {
                      final endStr = sub.subEndsAt;
                      final days = sub.daysRemaining;
                      if (endStr != null) {
                        final endDate = DateTime.tryParse(endStr);
                        masaLabel = days <= 7
                            ? 'Aktif: $days hr lagi'
                            : 'Aktif s/d ${endDate != null ? DateFormat('dd MMM yy', 'id_ID').format(endDate) : endStr}';
                        masaColor = days <= 7
                            ? const Color(0xFFE53935)
                            : const Color(0xFF43A047);
                      } else {
                        masaLabel = 'Aktif';
                        masaColor = const Color(0xFF43A047);
                      }
                      masaIcon = Icons.verified_rounded;
                    } else if (sub.status == 'expired') {
                      masaLabel = 'Expired';
                      masaColor = const Color(0xFFE53935);
                      masaIcon = Icons.cancel_rounded;
                    } else if (sub.status == 'suspended') {
                      masaLabel = 'Suspended';
                      masaColor = const Color(0xFFFF9800);
                      masaIcon = Icons.block_rounded;
                    } else {
                      return const SizedBox.shrink();
                    }

                    return Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 11, color: tierColor),
                              const SizedBox(width: 4),
                              Text(
                                tierLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: tierColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: masaColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: masaColor.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(masaIcon, size: 11, color: masaColor),
                              const SizedBox(width: 4),
                              Text(
                                masaLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: masaColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  // Shortcut kelola cabang (owner only)
                  if (user?.isOwner == true) ...[
                    const SizedBox(height: 8),
                    Obx(() {
                      final authService = Get.find<AuthService>();
                      final viewId = authService.viewBranchId.value;
                      final activeBranch = authService.selectedBranch;
                      // Label filter data yang aktif
                      final viewLabel = viewId == null
                          ? 'Semua Cabang'
                          : (authService.branches
                                  .firstWhereOrNull((b) => b.id == viewId)
                                  ?.name ??
                              'Cabang');
                      final isViewAll = viewId == null;
                      return GestureDetector(
                        onTap: () => _showBranchSwitcher(),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Chip filter data (biru)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isViewAll
                                    ? const Color(0xFF2196F3)
                                    : const Color(0xFF1A1D26),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isViewAll
                                        ? Icons.store_rounded
                                        : Icons.bar_chart_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    viewLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 13, color: Colors.white70),
                                ],
                              ),
                            ),
                            // Chip cabang aktif (oranye) — hanya tampil jika berbeda dari filter
                            if (activeBranch != null && viewId != activeBranch.id)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFFF6B35).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.point_of_sale_rounded,
                                        size: 11, color: Color(0xFFFF6B35)),
                                    const SizedBox(width: 4),
                                    Text(
                                      activeBranch.name,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFF6B35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sync Button
            Obx(() {
              final syncService = Get.find<SyncService>();
              final isSyncing = syncService.isSyncing;

              return GestureDetector(
                onTap: isSyncing ? null : () => _syncData(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isSyncing
                        ? const LinearGradient(
                            colors: [Color(0xFF9E9E9E), Color(0xFF757575)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: isSyncing
                            ? Colors.black.withValues(alpha: 0.1)
                            : const Color(0xFFFF6B35).withValues(alpha: 0.3),
                        blurRadius: isSyncing ? 8 : 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isSyncing
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.sync_rounded, color: Colors.white, size: 28),
                ),
              );
            }),
          ],
        ),
      ),
    ); // end SafeArea
    }), // end Builder
    ); // end TweenAnimationBuilder
  }

  void _syncData() async {
    final dashboardService = Get.find<DashboardService>();

    bool dialogOpen = false;
    bool success = false;
    String errorMsg = '';

    // Show loading dialog
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.t('syncing'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t('syncFetchingData'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
    dialogOpen = true;

    try {
      await dashboardService.syncFromServer();
      success = true;
    } catch (e) {
      errorMsg = e.toString().length > 80
          ? '${e.toString().substring(0, 80)}...'
          : e.toString();
    } finally {
      // Selalu tutup dialog jika masih terbuka
      if (dialogOpen && Get.isDialogOpen == true) {
        Get.back();
      }
      dialogOpen = false;
    }

    if (success) {
      Get.snackbar(
        AppStrings.t('syncSuccess'),
        AppStrings.t('syncFetchingData'),
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        borderRadius: 12,
        icon: const Icon(Icons.cloud_done_rounded, color: Colors.white),
      );
    } else if (errorMsg.isNotEmpty) {
      Get.snackbar(
        AppStrings.t('syncFailed'),
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        borderRadius: 12,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
    }
  }

  void _showCompactNotification({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    OverlayEntry? overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFF4CAF50) : Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      overlayEntry?.remove();
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(Get.context!).insert(overlayEntry);

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry?.remove();
    });
  }

  Widget _buildStatCards(bool isTablet, {bool isCashier = false}) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Obx(() {
      final stats = isCashier
          ? [
              _StatData(
                label: AppStrings.t('todaySales'),
                value: currency.format(_dashboardService.todaySales),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF4CAF50),
                bgColor: const Color(0xFFE8F5E9),
              ),
              _StatData(
                label: AppStrings.t('transactions'),
                value: '${_dashboardService.todayTransactions}',
                icon: Icons.receipt_rounded,
                color: const Color(0xFF2196F3),
                bgColor: const Color(0xFFE3F2FD),
              ),
              _StatData(
                label: AppStrings.t('pendingSync'),
                value: '${_dashboardService.pendingSync}',
                icon: Icons.cloud_upload_rounded,
                color: _dashboardService.pendingSync > 0
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF4CAF50),
                bgColor: _dashboardService.pendingSync > 0
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE8F5E9),
              ),
            ]
          : [
              _StatData(
                label: AppStrings.t('todaySales'),
                value: currency.format(_dashboardService.todaySales),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF4CAF50),
                bgColor: const Color(0xFFE8F5E9),
              ),
              _StatData(
                label: AppStrings.t('transactions'),
                value: '${_dashboardService.todayTransactions}',
                icon: Icons.receipt_rounded,
                color: const Color(0xFF2196F3),
                bgColor: const Color(0xFFE3F2FD),
              ),
              _StatData(
                label: AppStrings.t('pendingSync'),
                value: '${_dashboardService.pendingSync}',
                icon: Icons.cloud_upload_rounded,
                color: _dashboardService.pendingSync > 0
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF4CAF50),
                bgColor: _dashboardService.pendingSync > 0
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE8F5E9),
              ),
              _StatData(
                label: AppStrings.t('activeProducts'),
                value: '${_dashboardService.activeProducts}',
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF9C27B0),
                bgColor: const Color(0xFFF3E5F5),
              ),
            ];

      final crossAxis = isCashier ? 3 : (isTablet ? 4 : 2);
      return GridView.count(
        crossAxisCount: crossAxis,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.8,
        children: List.generate(stats.length, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + i * 80),
            curve: Curves.easeOut,
            builder: (ctx, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - v)),
                child: child,
              ),
            ),
            child: _buildStatCard(stats[i]),
          );
        }),
      );
    });
  }

  // ── Low Stock Alert Widget ────────────────────────────────────────────────

  Widget _buildLowStockAlert(bool isTablet) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getLowStockProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        final outOfStock = products.where((p) => (p['local_stock'] as int? ?? 0) == 0).toList();
        final lowStock   = products.where((p) => (p['local_stock'] as int? ?? 0) > 0).toList();
        final alertDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () => _showStockAlertPopup(context, outOfStock, lowStock),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: alertDark
                    ? [const Color(0xFF2A1F0A), const Color(0xFF1E1800)]
                    : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_rounded, color: Color(0xFFFF9800), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('stockWarning'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          Text(
                            _buildAlertSummary(outOfStock.length, lowStock.length),
                            style: TextStyle(
                                fontSize: 11,
                                color: alertDark ? const Color(0xFF8B8FA8) : Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppStrings.t('viewDetail'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Preview chips ───────────────────────────────
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length > 6 ? 6 : products.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final stock = p['local_stock'] as int? ?? 0;
                      final isOut = stock == 0;
                      return _buildStockChip(p, isOut);
                    },
                  ),
                ),

                // ── Tap hint ────────────────────────────────────
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 12,
                        color: alertDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.t('tapToSeeDetails'),
                      style: TextStyle(fontSize: 10,
                          color: alertDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildAlertSummary(int outCount, int lowCount) {
    if (outCount > 0 && lowCount > 0) {
      return AppStrings.tArgs('productsOutLow', ['$outCount', '$lowCount']);
    } else if (outCount > 0) {
      return AppStrings.tArgs('productsOut', ['$outCount']);
    } else {
      return AppStrings.tArgs('productsLow', ['$lowCount']);
    }
  }

  Widget _buildStockChip(Map<String, dynamic> p, bool isOut) {
    final stock = p['local_stock'] as int? ?? 0;
    final min   = p['min_stock'] as int? ?? 0;
    final unit  = p['unit'] as String? ?? '';
    final color = isOut ? const Color(0xFFF44336) : const Color(0xFFFF9800);

    return Builder(builder: (ctx) {
      final chipDark = Theme.of(ctx).brightness == Brightness.dark;
      final bg = isOut
          ? (chipDark ? const Color(0xFF2A1010) : const Color(0xFFFFEBEE))
          : (chipDark ? const Color(0xFF1A1D26) : Colors.white);

    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isOut ? Icons.remove_shopping_cart_rounded : Icons.warning_amber_rounded,
                size: 10,
                color: color,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  isOut ? AppStrings.t('outOfStockBadge') : AppStrings.t('lowStockBadge'),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            p['name'] as String,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: chipDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            isOut
                ? AppStrings.tArgs('outOfStockMin', ['$min', unit])
                : AppStrings.tArgs('stockCurrent', ['$stock', '$min', unit]),
            style: TextStyle(fontSize: 9, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    }); // end Builder chip
  }

  void _showStockAlertPopup(
    BuildContext context,
    List<Map<String, dynamic>> outOfStock,
    List<Map<String, dynamic>> lowStock,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Builder(builder: (shCtx) {
          final shDark = Theme.of(shCtx).brightness == Brightness.dark;
          return Container(
          decoration: BoxDecoration(
            color: shDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: shDark ? const Color(0xFF2A2D3E) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: shDark
                            ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded,
                          color: Color(0xFFFF9800), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('stockWarningTitle'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: shDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                            ),
                          ),
                          Text(
                            _buildAlertSummary(outOfStock.length, lowStock.length),
                            style: TextStyle(
                                fontSize: 11,
                                color: shDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: shDark ? const Color(0xFF242838) : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close_rounded, size: 18,
                            color: shDark ? const Color(0xFF8B8FA8) : const Color(0xFF666666)),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: shDark ? const Color(0xFF2A2D3E) : null),

              // List
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    // ── Habis section ──────────────────────────
                    if (outOfStock.isNotEmpty) ...[
                      _sectionHeader(
                        icon: Icons.remove_shopping_cart_rounded,
                        label: AppStrings.t('outOfStock'),
                        count: outOfStock.length,
                        color: const Color(0xFFF44336),
                        bg: shDark
                            ? const Color(0xFFF44336).withValues(alpha: 0.15)
                            : const Color(0xFFFFEBEE),
                      ),
                      const SizedBox(height: 8),
                      ...outOfStock.map((p) => _popupProductRow(p, isOut: true)),
                      const SizedBox(height: 16),
                    ],

                    // ── Rendah section ─────────────────────────
                    if (lowStock.isNotEmpty) ...[
                      _sectionHeader(
                        icon: Icons.warning_amber_rounded,
                        label: AppStrings.t('lowStock'),
                        count: lowStock.length,
                        color: const Color(0xFFFF9800),
                        bg: shDark
                            ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                            : const Color(0xFFFFF3E0),
                      ),
                      const SizedBox(height: 8),
                      ...lowStock.map((p) => _popupProductRow(p, isOut: false)),
                      const SizedBox(height: 16),
                    ],

                    // ── Action buttons ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Get.back();
                              Get.toNamed('/stock-opname');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                color: shDark
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                                    : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.fact_check_rounded,
                                      size: 15, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 6),
                                  Text(AppStrings.t('stockOpnameBtn'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4CAF50))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Get.back();
                              Get.toNamed('/inventory');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.inventory_2_rounded,
                                      size: 15, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(AppStrings.t('manageStockBtn'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        }), // end Builder shDark
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required Color bg,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _popupProductRow(Map<String, dynamic> p, {required bool isOut}) {
    final stock = p['local_stock'] as int? ?? 0;
    final min   = p['min_stock'] as int? ?? 0;
    final unit  = p['unit'] as String? ?? '';
    final color = isOut ? const Color(0xFFF44336) : const Color(0xFFFF9800);
    final double pct = (min > 0) ? (stock / min).clamp(0.0, 1.0) : 0.0;

    return Builder(builder: (ctx) {
      final rowDark = Theme.of(ctx).brightness == Brightness.dark;
      final bg = isOut
          ? (rowDark ? const Color(0xFFF44336).withValues(alpha: 0.15) : const Color(0xFFFFEBEE))
          : (rowDark ? const Color(0xFFFF9800).withValues(alpha: 0.15) : const Color(0xFFFFF3E0));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rowDark ? const Color(0xFF242838) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: rowDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(
              isOut ? Icons.remove_shopping_cart_rounded : Icons.warning_amber_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] as String,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: rowDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOut
                      ? AppStrings.tArgs('outOfStockMin', ['$min', unit])
                      : AppStrings.tArgs('stockCurrent', ['$stock', '$min', unit]),
                  style: TextStyle(fontSize: 10,
                      color: rowDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Text(
              isOut ? AppStrings.t('outOfStockBadge') : AppStrings.t('lowStockBadge'),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
    }); // end Builder rowDark
  }

  Future<List<Map<String, dynamic>>> _getLowStockProducts() async {
    final db = DatabaseHelper();
    final results = await db.rawQuery('''
      SELECT id, name, local_stock, min_stock, unit
      FROM products
      WHERE is_active = 1 AND (local_stock = 0 OR local_stock <= min_stock)
      ORDER BY local_stock ASC
    ''');
    return results;
  }

  // ── Weekly Sales Chart Widget ─────────────────────────────────────────────

  Widget _buildWeeklySalesChart(bool isTablet) {
    return Builder(builder: (ctx) {
      final chartDark = Theme.of(ctx).brightness == Brightness.dark;
      return Obx(() {
        Get.find<LanguageService>().locale.value; // subscribe for language rebuild
        final raw       = _dashboardService.weeklySales;
        final totalWeek = raw.fold(0.0, (s, d) => s + ((d['total'] as num?)?.toDouble() ?? 0.0));
        final maxVal    = raw.fold(0.0, (m, d) {
          final v = (d['total'] as num?)?.toDouble() ?? 0.0;
          return v > m ? v : m;
        });
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: chartDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: chartDark ? 0.3 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Color(0xFFFF6B35), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.t('last7DaysSales'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: chartDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                      ),
                    ),
                  ),
                  Text(
                    _currency.format(totalWeek),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (raw.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  )),
                )
              else
                SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: raw.map((d) {
                      final total   = (d['total'] as num?)?.toDouble() ?? 0.0;
                      final label   = d['label'] as String? ?? '';
                      final isToday = d['isToday'] as bool? ?? false;
                      // Reserve: value label 16px + bar-bottom-spacer 6px + day label 24px = 46px
                      // Max bar height = 160 - 46 = 114px
                      const maxBarH = 100.0;
                      final ratio   = maxVal > 0 ? total / maxVal : 0.0;
                      final barH    = total > 0 ? (ratio * maxBarH).clamp(4.0, maxBarH) : 0.0;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Nilai di atas bar (hanya jika ada)
                              SizedBox(
                                height: 16,
                                child: total > 0
                                    ? Text(
                                        _shortCurrency(total),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: isToday
                                              ? const Color(0xFFFF6B35)
                                              : const Color(0xFF42A5F5),
                                        ),
                                        textAlign: TextAlign.center,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              // Bar
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                height: barH,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isToday
                                        ? [const Color(0xFFFF6B35), const Color(0xFFEA580C)]
                                        : [const Color(0xFF64B5F6), const Color(0xFF1565C0)],
                                  ),
                                ),
                              ),
                              // Label bawah — fixed height 30px
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 24,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1.2,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isToday
                                        ? const Color(0xFFFF6B35)
                                        : (chartDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _chartLegend(const Color(0xFF42A5F5), AppStrings.t('yesterday'), chartDark),
                  const SizedBox(width: 12),
                  _chartLegend(const Color(0xFFFF6B35), AppStrings.t('today'), chartDark),
                ],
              ),
            ],
          ),
        );
      }); // end Obx
    }); // end Builder chartDark
  }

  Widget _chartLegend(Color color, String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          fontSize: 10,
          color: isDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500,
        )),
      ],
    );
  }

  String _shortCurrency(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  double _gridInterval(List<Map<String, dynamic>> data) {
    final max = data.fold(0.0, (m, d) {
      final v = d['total'] as double;
      return v > m ? v : m;
    });
    if (max <= 0) return 1;
    if (max <= 50000) return 10000;
    if (max <= 200000) return 50000;
    if (max <= 1000000) return 200000;
    return (max / 4).roundToDouble();
  }

  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // ── Top Products Widget (Business tier only) ─────────────────────────────

  Widget _buildTopProducts(bool isTablet) {
    // Analytics hanya Business tier
    final sub = Get.find<AuthService>().subscription;
    if (!(sub?.hasFeature('analytics') ?? true)) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTopProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return Container();
        }

        final topDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: topDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: topDark ? 0.3 : 0.04),
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
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.t('bestSelling'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: topDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // List produk terlaris
              ...products.take(5).map((product) {
                final rank = products.indexOf(product) + 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFFFD700).withValues(alpha: topDark ? 0.15 : 0.1)
                        : rank == 2
                            ? const Color(0xFFC0C0C0).withValues(alpha: topDark ? 0.15 : 0.1)
                            : rank == 3
                                ? const Color(0xFFCD7F32).withValues(alpha: topDark ? 0.15 : 0.1)
                                : (topDark ? const Color(0xFF242838) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: rank <= 3
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500),
                                  ],
                                )
                              : null,
                          color: rank > 3
                              ? (topDark ? const Color(0xFF2E3147) : Colors.grey.shade200)
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: rank <= 3
                                  ? Colors.white
                                  : (topDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Product info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['product_name'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: topDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Terjual: ${product['total_sold']} x',
                              style: TextStyle(
                                fontSize: 11,
                                color: topDark ? const Color(0xFF8B8FA8) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Revenue
                      Text(
                        _currency.format((product['total_revenue'] as num?)?.toDouble() ?? 0.0),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getTopProducts() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month, 1);
    
    final results = await db.rawQuery('''
      SELECT 
        si.product_name,
        SUM(si.quantity) as total_sold,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      WHERE s.status = 'completed'
        AND datetime(s.created_at) >= datetime(?)
      GROUP BY si.product_id, si.product_name
      ORDER BY total_sold DESC
      LIMIT 10
    ''', [monthAgo.toIso8601String()]);
    
    return results;
  }

  Widget _buildStatCard(_StatData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 150;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBase = isDark ? const Color(0xFF1A1D26) : Colors.white;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1D26), data.color.withValues(alpha: 0.12)]
                  : [Colors.white, data.bgColor.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(isNarrow ? 12 : 14),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : data.color.withValues(alpha: 0.08),
                blurRadius: isNarrow ? 8 : 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isNarrow ? 12 : 14),
            child: Stack(
              children: [
                // Background pattern
                Positioned(
                  right: isNarrow ? -8 : -12,
                  top: isNarrow ? -8 : -12,
                  child: Icon(
                    data.icon,
                    size: isNarrow ? 50 : 60,
                    color: data.color.withValues(alpha: 0.04),
                  ),
                ),
                // Bottom accent bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [data.color, data.color.withValues(alpha: 0.3)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isNarrow ? 10 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon illustration
                      Container(
                        width: isNarrow ? 36 : 42,
                        height: isNarrow ? 36 : 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [data.color, data.color.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
                          boxShadow: [
                            BoxShadow(
                              color: data.color.withValues(alpha: 0.25),
                              blurRadius: isNarrow ? 4 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Decorative circles
                            Positioned(
                              right: isNarrow ? 1 : 2,
                              top: isNarrow ? 1 : 2,
                              child: Container(
                                width: isNarrow ? 10 : 14,
                                height: isNarrow ? 10 : 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            Icon(data.icon, color: Colors.white, size: isNarrow ? 16 : 20),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Value with animated number change
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          data.value,
                          key: ValueKey(data.value),
                          style: TextStyle(
                            fontSize: isNarrow ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      SizedBox(height: isNarrow ? 1 : 2),
                      // Label
                      Text(
                        data.label,
                        style: TextStyle(
                          fontSize: isNarrow ? 8 : 9,
                          color: isDark ? const Color(0xFF8B8FA8) : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isTablet, {bool isCashier = false, String userRole = ''}) {
    final isOwner = userRole == 'owner' || userRole == 'super_admin';
    final isManager = userRole == 'manager';
    final allActions = isCashier
        ? [
            _ActionData(
              icon: Icons.point_of_sale_rounded,
              label: AppStrings.t('navPos'),
              subtitle: AppStrings.t('startTransaction'),
              color: const Color(0xFFFF6B35),
              bgColor: const Color(0xFFFFF0EB),
              onTap: () => Get.toNamed('/pos'),
            ),
            _ActionData(
              icon: Icons.receipt_long_rounded,
              label: AppStrings.t('navHistory'),
              subtitle: AppStrings.t('myTransactions'),
              color: const Color(0xFF4CAF50),
              bgColor: const Color(0xFFE8F5E9),
              onTap: () => Get.toNamed('/sales-report'),
            ),
            _ActionData(
              icon: Icons.settings_rounded,
              label: AppStrings.t('navSettings'),
              subtitle: AppStrings.t('profilePrefs'),
              color: const Color(0xFF607D8B),
              bgColor: const Color(0xFFECEFF1),
              onTap: () => Get.toNamed('/settings'),
            ),
          ]
        : [
            _ActionData(
              icon: Icons.point_of_sale_rounded,
              label: AppStrings.t('navPos'),
              subtitle: AppStrings.t('startTransaction'),
              color: const Color(0xFFFF6B35),
              bgColor: const Color(0xFFFFF0EB),
              onTap: () => Get.toNamed('/pos'),
            ),
            _ActionData(
              icon: Icons.receipt_long_rounded,
              label: AppStrings.t('navHistory'),
              subtitle: AppStrings.t('salesReport'),
              color: const Color(0xFF4CAF50),
              bgColor: const Color(0xFFE8F5E9),
              onTap: () => Get.toNamed('/sales-report'),
            ),
            _ActionData(
              icon: Icons.inventory_2_rounded,
              label: AppStrings.t('navProducts'),
              subtitle: AppStrings.t('manageStock'),
              color: const Color(0xFF2196F3),
              bgColor: const Color(0xFFE3F2FD),
              onTap: () => Get.toNamed('/inventory'),
            ),
            _ActionData(
              icon: Icons.category_rounded,
              label: AppStrings.t('navCategories'),
              subtitle: AppStrings.t('manageCategories'),
              color: const Color(0xFFFF9800),
              bgColor: const Color(0xFFFFF3E0),
              onTap: () => Get.toNamed('/categories'),
            ),
            _ActionData(
              icon: Icons.local_shipping_rounded,
              label: AppStrings.t('navPurchase'),
              subtitle: AppStrings.t('supplierPO'),
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFEDE7F6),
              onTap: () => Get.toNamed('/purchases'),
            ),
            _ActionData(
              icon: Icons.business_rounded,
              label: 'Supplier',
              subtitle: AppStrings.t('manageSuppliers'),
              color: const Color(0xFF0097A7),
              bgColor: const Color(0xFFE0F7FA),
              onTap: () => Get.toNamed('/suppliers'),
            ),
            _ActionData(
              icon: Icons.sync_rounded,
              label: AppStrings.t('syncing').replaceAll('...', ''),
              subtitle: AppStrings.t('uploadToServer'),
              color: const Color(0xFF9C27B0),
              bgColor: const Color(0xFFF3E5F5),
              onTap: () => Get.toNamed('/sync-debug'),
            ),
            _ActionData(
              icon: Icons.assessment_rounded,
              label: AppStrings.t('navHistory'),
              subtitle: AppStrings.t('salesReport'),
              color: const Color(0xFF4CAF50),
              bgColor: const Color(0xFFE8F5E9),
              onTap: () => Get.toNamed('/sales-report'),
            ),
            _ActionData(
              icon: Icons.show_chart_rounded,
              label: AppStrings.t('navProfitLoss'),
              subtitle: AppStrings.t('profitAnalysis'),
              color: const Color(0xFF059669),
              bgColor: const Color(0xFFD1FAE5),
              onTap: () => Get.toNamed('/profit-loss'),
            ),
            _ActionData(
              icon: Icons.qr_code_scanner_rounded,
              label: AppStrings.t('navInventoryReport'),
              subtitle: AppStrings.t('inventoryReport'),
              color: const Color(0xFF2196F3),
              bgColor: const Color(0xFFE3F2FD),
              onTap: () => Get.toNamed('/inventory-report'),
            ),
            // Backup — owner & manager
            if (isOwner || isManager)
              _ActionData(
                icon: Icons.save_rounded,
                label: 'Backup DB',
                subtitle: 'Download backup database',
                color: const Color(0xFF2196F3),
                bgColor: const Color(0xFFE3F2FD),
                onTap: () => Get.toNamed('/settings'),
              ),
            // Restore — owner only
            if (isOwner)
              _ActionData(
                icon: Icons.restore_rounded,
                label: 'Restore DB',
                subtitle: 'Restore dari file backup',
                color: Colors.red,
                bgColor: const Color(0xFFFFEBEE),
                onTap: () => Get.toNamed('/settings'),
              ),
          ];
    final actions = allActions;

    return GridView.count(
      crossAxisCount: isTablet ? 3 : 2,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: actions.map((a) => _buildActionCard(a)).toList(),
    );
  }

  Widget _buildActionCard(_ActionData data) {
    return GestureDetector(
      onTap: data.onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 150;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1D26), data.color.withValues(alpha: 0.12)]
                    : [Colors.white, data.bgColor.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(isNarrow ? 12 : 14),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : data.color.withValues(alpha: 0.08),
                  blurRadius: isNarrow ? 8 : 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isNarrow ? 12 : 14),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    right: isNarrow ? -8 : -12,
                    top: isNarrow ? -8 : -12,
                    child: Icon(
                      data.icon,
                      size: isNarrow ? 50 : 60,
                      color: data.color.withValues(alpha: 0.04),
                    ),
                  ),
                  // Bottom accent bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [data.color, data.color.withValues(alpha: 0.3)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isNarrow ? 10 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon illustration
                        Container(
                          width: isNarrow ? 36 : 42,
                          height: isNarrow ? 36 : 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [data.color, data.color.withValues(alpha: 0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
                            boxShadow: [
                              BoxShadow(
                                color: data.color.withValues(alpha: 0.25),
                                blurRadius: isNarrow ? 4 : 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative circles
                              Positioned(
                                right: isNarrow ? 1 : 2,
                                top: isNarrow ? 1 : 2,
                                child: Container(
                                  width: isNarrow ? 10 : 14,
                                  height: isNarrow ? 10 : 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                              Icon(data.icon, color: Colors.white, size: isNarrow ? 16 : 20),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Label
                        Text(
                          data.label,
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                          ),
                        ),
                        SizedBox(height: isNarrow ? 1 : 2),
                        // Subtitle
                        Text(
                          data.subtitle,
                          style: TextStyle(
                            fontSize: isNarrow ? 8 : 9,
                            color: isDark ? const Color(0xFF8B8FA8) : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSection({bool isCashier = false}) {
    return Builder(builder: (ctx) {
      final recentDark = Theme.of(ctx).brightness == Brightness.dark;
      return Obx(() {
        final activities = _dashboardService.recentActivities;
        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.t('recentActivity'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: recentDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                ),
              ),
              Row(
                children: [
                  // Refresh button
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: _dashboardService.isSyncing
                          ? Colors.grey
                          : const Color(0xFFFF6B35),
                    ),
                    onPressed: _dashboardService.isSyncing
                        ? null
                        : () => _dashboardService.forceRefresh(),
                    tooltip: 'Refresh',
                  ),
                  TextButton(
                    onPressed: () => Get.toNamed('/sales-report'),
                    child: const Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          if (activities.isEmpty && _dashboardService.isLoading)
            Container(
              padding: const EdgeInsets.all(40),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: recentDark ? const Color(0xFF1A1D26) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: recentDark ? const Color(0xFF2A2D3E) : Colors.grey.shade100),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: recentDark ? const Color(0xFF3A3F5A) : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.t('noActivity'),
                      style: TextStyle(
                        color: recentDark ? const Color(0xFF8B8FA8) : Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: recentDark ? const Color(0xFF1A1D26) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: recentDark ? 0.25 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: activities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final activity = entry.value;
                  final isLast = index == activities.length - 1;
                  return Column(
                    children: [
                      _buildRecentItem(
                        icon: activity['icon'] as IconData,
                        title: activity['title'] as String,
                        subtitle: activity['subtitle'] as String,
                        amount: activity['amount'] as String,
                        color: activity['color'] as Color,
                        isDark: recentDark,
                      ),
                      if (!isLast)
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: recentDark ? const Color(0xFF2A2D3E) : Colors.grey.shade100,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      );
      }); // end Obx
    }); // end Builder recentDark
  }

  Widget _buildRecentItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color color,
    bool isDark = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  right: 4, top: 4,
                  child: Icon(icon, size: 28, color: color.withValues(alpha: 0.15)),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF8B8FA8) : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: amount.startsWith('+')
                  ? const Color(0xFF4CAF50).withValues(alpha: isDark ? 0.2 : 0.1)
                  : color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: amount.startsWith('+') ? const Color(0xFF4CAF50) : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBranchSwitcher() {
    final authService = Get.find<AuthService>();
    final branches = authService.branches;
    if (branches.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bsCtx) => Builder(builder: (innerCtx) {
        final bsDark = Theme.of(innerCtx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: bsDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: bsDark ? const Color(0xFF2A2D3E) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded,
                          color: Color(0xFFFF6B35), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola Cabang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: bsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                          ),
                        ),
                        Text(
                          'Filter data & cabang operasional',
                          style: TextStyle(
                            fontSize: 11,
                            color: bsDark ? const Color(0xFF8B8FA8) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: bsDark ? const Color(0xFF2A2D3E) : Colors.grey.shade200),
              Flexible(
                child: Obx(() {
                  final activeBranch = authService.selectedBranch;
                  final viewId = authService.viewBranchId.value;
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      // ── Section 1: Filter tampilan data ──────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bar_chart_rounded,
                                  color: Color(0xFF2196F3), size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filter Tampilan Data',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: bsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(statistik & laporan)',
                              style: TextStyle(
                                fontSize: 10,
                                color: bsDark ? const Color(0xFF8B8FA8) : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chip "Semua Cabang"
                      ListTile(
                        onTap: () {
                          authService.setViewBranch(null);
                          _dashboardService.loadDashboardData();
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: viewId == null
                                ? const Color(0xFF2196F3)
                                : (bsDark ? const Color(0xFF242838) : const Color(0xFFF4F5F7)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.store_rounded,
                            size: 18,
                            color: viewId == null
                                ? Colors.white
                                : (bsDark ? const Color(0xFF8B8FA8) : Colors.grey[500]),
                          ),
                        ),
                        title: Text(
                          'Semua Cabang',
                          style: TextStyle(
                            fontWeight: viewId == null ? FontWeight.w700 : FontWeight.w500,
                            color: viewId == null
                                ? const Color(0xFF2196F3)
                                : (bsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26)),
                          ),
                        ),
                        subtitle: Text(
                          'Tampilkan data dari seluruh cabang',
                          style: TextStyle(
                            fontSize: 11,
                            color: bsDark ? const Color(0xFF8B8FA8) : null,
                          ),
                        ),
                        trailing: viewId == null
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF2196F3), size: 20)
                            : Icon(Icons.chevron_right_rounded,
                                color: bsDark ? const Color(0xFF8B8FA8) : Colors.grey, size: 20),
                      ),
                      // Chip per cabang untuk filter
                      ...branches.map((b) {
                        final isViewActive = viewId == b.id;
                        return ListTile(
                          onTap: () {
                            authService.setViewBranch(b.id);
                            _dashboardService.loadDashboardData();
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isViewActive
                                  ? const Color(0xFF2196F3)
                                  : (bsDark ? const Color(0xFF242838) : const Color(0xFFF4F5F7)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 18,
                              color: isViewActive
                                  ? Colors.white
                                  : (bsDark ? const Color(0xFF8B8FA8) : Colors.grey[500]),
                            ),
                          ),
                          title: Text(
                            b.name,
                            style: TextStyle(
                              fontWeight: isViewActive ? FontWeight.w700 : FontWeight.w500,
                              color: isViewActive
                                  ? const Color(0xFF2196F3)
                                  : (bsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26)),
                            ),
                          ),
                          subtitle: b.city != null
                              ? Text(b.city!, style: TextStyle(
                                  fontSize: 11,
                                  color: bsDark ? const Color(0xFF8B8FA8) : null,
                                ))
                              : null,
                          trailing: isViewActive
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF2196F3), size: 20)
                              : Icon(Icons.chevron_right_rounded,
                                  color: bsDark ? const Color(0xFF8B8FA8) : Colors.grey, size: 20),
                        );
                      }),

                      // ── Section 2: Cabang operasional ─────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.point_of_sale_rounded,
                                  color: Color(0xFFFF6B35), size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cabang Operasional Aktif',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: bsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(kasir & stok)',
                              style: TextStyle(
                                fontSize: 10,
                                color: bsDark ? const Color(0xFF8B8FA8) : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...branches.map((b) {
                        final isActive = activeBranch?.id == b.id;
                        return ListTile(
                          onTap: isActive
                              ? null
                              : () async {
                                  Get.back();
                                  await authService.selectBranch(b);
                                  _dashboardService.loadDashboardData();
                                  Get.snackbar(
                                    'Cabang Diubah',
                                    'Sekarang aktif di: ${b.name}',
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: const Color(0xFF4CAF50),
                                    colorText: Colors.white,
                                    margin: const EdgeInsets.all(12),
                                    duration: const Duration(seconds: 2),
                                    borderRadius: 12,
                                    icon: const Icon(Icons.storefront_rounded,
                                        color: Colors.white),
                                  );
                                },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFFFF6B35)
                                  : (bsDark ? const Color(0xFF242838) : const Color(0xFFF4F5F7)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.storefront_rounded,
                              size: 18,
                              color: isActive
                                  ? Colors.white
                                  : (bsDark ? const Color(0xFF8B8FA8) : Colors.grey[500]),
                            ),
                          ),
                          title: Text(
                            b.name,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive
                                  ? const Color(0xFFFF6B35)
                                  : (bsDark ? const Color(0xFFE8E9EF) : const Color(0xFF1A1D26)),
                            ),
                          ),
                          subtitle: b.city != null
                              ? Text(b.city!, style: TextStyle(
                                  fontSize: 11,
                                  color: bsDark ? const Color(0xFF8B8FA8) : null,
                                ))
                              : null,
                          trailing: isActive
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFFFF6B35), size: 20)
                              : Icon(Icons.chevron_right_rounded,
                                  color: bsDark ? const Color(0xFF8B8FA8) : Colors.grey, size: 20),
                        );
                      }),
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      }), // end Builder bsDark
    );
  }

  void _showProfileSheet(String name, String role) {
    final authService = Get.find<AuthService>();
    final user = authService.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Avatar besar
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (user?.name ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Nama
            Text(
              user?.name ?? '-',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26)),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              user?.email ?? '-',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (user?.role ?? 'user').toUpperCase(),
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFF6B35),
                  letterSpacing: 1,
                ),
              ),
            ),

            // Branch info
            if (authService.selectedBranch != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    authService.selectedBranch!.name,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Tombol Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Get.back();
                  final confirm = await Get.dialog<bool>(
                    AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Keluar Aplikasi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      content: const Text('Yakin ingin logout dari akun ini?'),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Get.back(result: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await authService.logout();
                    Get.offAllNamed('/login');
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String labelKey;
  final String? route;
  const _NavItem({required this.icon, required this.labelKey, this.route});
  String get label => AppStrings.t(labelKey);
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String lottie;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.lottie = 'default',
  });
}

class _ActionData {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;
  const _ActionData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    this.onTap,
  });
}
