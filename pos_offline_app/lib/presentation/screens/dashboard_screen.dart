import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/auth_controller.dart';
import '../controllers/pos_controller.dart';
import '../widgets/connectivity_indicator.dart';
import '../../services/auth/auth_service.dart';
import '../../services/sync/sync_service.dart';
import '../../services/dashboard/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNav = 0;

  final _navItems = const [
    _NavItem(icon: Icons.home_rounded,              label: 'Home'),
    _NavItem(icon: Icons.point_of_sale_rounded,     label: 'Kasir'),
    _NavItem(icon: Icons.inventory_2_rounded,       label: 'Produk'),
    _NavItem(icon: Icons.category_rounded,          label: 'Kategori'),
    _NavItem(icon: Icons.local_shipping_rounded,    label: 'PO'),
    _NavItem(icon: Icons.receipt_long_rounded,      label: 'Riwayat'),
    _NavItem(icon: Icons.settings_rounded,          label: 'Setelan'),
  ];

  @override
  void initState() {
    super.initState();
    Get.put(AuthController());
    Get.put(POSController());
    // Pastikan DashboardService sudah di-register
    if (!Get.isRegistered<DashboardService>()) {
      Get.put(DashboardService());
    } else {
      // Refresh data setiap kali halaman dibuka
      Get.find<DashboardService>().loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // ── Sidebar kiri ──────────────────────────────────────────
          _buildSidebar(isTablet),

          // ── Konten utama ──────────────────────────────────────────
          Expanded(
            child: _buildContent(context, size, isTablet),
          ),
        ],
      ),
    );
  }

  // ── SIDEBAR ─────────────────────────────────────────────────────────────

  Widget _buildSidebar(bool isTablet) {
    final authService = Get.find<AuthService>();
    final user        = authService.currentUser;
    final sidebarW    = isTablet ? 88.0 : 72.0;

    return Container(
      width: sidebarW,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
        ),
        boxShadow: [
          BoxShadow(
            color:      Color(0x28000000),
            blurRadius: 16,
            offset:     Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── Logo ──
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:      const Color(0xFFFF6B35).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.point_of_sale_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            const Text(
              'POS',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 28),

            // ── Divider tipis ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color:  Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 20),

            // ── Nav items ──
            ..._navItems.asMap().entries.map((e) =>
                _buildNavItem(e.key, e.value)),

            const Spacer(),

            // ── Divider tipis ──
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color:  Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 16),

            // ── Connectivity dot ──
            const ConnectivityDot(),
            const SizedBox(height: 16),

            // ── Avatar ──
            GestureDetector(
              onTap: () => _showProfileSheet(user?.name ?? '', user?.role ?? ''),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                      ),
                      shape:  BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:      const Color(0xFFFF6B35).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset:     const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (user?.name ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user != null ? user.name.split(' ').first : 'User',
                    style: TextStyle(
                      color:    Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
        if (index == 1) Get.toNamed('/pos')?.then((_) => setState(() => _selectedNav = 0));
        if (index == 2) Get.toNamed('/inventory')?.then((_) => setState(() => _selectedNav = 0));
        if (index == 3) Get.toNamed('/categories')?.then((_) => setState(() => _selectedNav = 0));
        if (index == 4) Get.toNamed('/purchases')?.then((_) => setState(() => _selectedNav = 0));
        if (index == 5) Get.toNamed('/sync-debug')?.then((_) => setState(() => _selectedNav = 0));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeInOut,
        width:    double.infinity,
        margin:   const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding:  const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        selected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Active indicator kiri
            if (selected)
              Positioned(
                left: 0,
                child: Container(
                  width:  3,
                  height: 28,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // Icon + label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  color: selected
                      ? const Color(0xFFFF6B35)
                      : Colors.white.withValues(alpha: 0.35),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize:   9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color:      selected
                        ? const Color(0xFFFF6B35)
                        : Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 0.3,
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
    final user        = authService.currentUser;
    final branch      = authService.selectedBranch;
    final now         = DateTime.now();
    final greeting    = now.hour < 12 ? 'Selamat Pagi' :
                        now.hour < 17 ? 'Selamat Siang' : 'Selamat Malam';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Banner ───────────────────────────────────────
          _buildHeroBanner(user, branch, greeting, now, isTablet),

          // ── Body content (putih) ──────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 28 : 20,
              24,
              isTablet ? 28 : 20,
              isTablet ? 28 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCards(isTablet),
                const SizedBox(height: 28),
                const Text(
                  'Menu Utama',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                    color:      Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(context, isTablet),
                const SizedBox(height: 28),
                _buildRecentSection(),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(dynamic user, dynamic branch, String greeting,
      DateTime now, bool isTablet) {
    final hPad    = isTablet ? 28.0 : 20.0;
    final vPadTop = isTablet ? 36.0 : 28.0;
    final vPadBot = isTablet ? 32.0 : 28.0;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, vPadTop, hPad, vPadBot),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Baris atas: greeting + ikon kasir ────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Greeting pill oranye
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_sunny_rounded,
                          color: Color(0xFFFF6B35), size: 12),
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
                const Spacer(),
                // Ikon kasir dekoratif
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Color(0xFFFF6B35), size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Nama user ──────────────────────────────────────
            Text(
              user != null ? user.name.split(' ').first : 'User',
              style: const TextStyle(
                color: Color(0xFF1A1D26),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            // ── Branch + role ──────────────────────────────────
            Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 13, color: Colors.grey[400]),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    branch?.name ?? user?.companyName ?? 'POS System',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _roleBadge(user?.role ?? ''),
              ],
            ),
            const SizedBox(height: 24),

            // ── Tanggal + tombol kasir ─────────────────────────
            Row(
              children: [
                // Tanggal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEE, dd MMM yyyy', 'id_ID').format(now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              
              
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(bool isTablet) {
    return Obx(() {
      final sync      = Get.find<SyncService>();
      final dashboard = Get.find<DashboardService>();
      final currency  = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      final pendingCount  = sync.pendingCount;
      final activeProducts = dashboard.activeProducts;

      final stats = [
        _StatData(
          label:   'Penjualan Hari Ini',
          value:   currency.format(dashboard.todaySales),
          icon:    Icons.trending_up_rounded,
          color:   const Color(0xFF4CAF50),
          bgColor: const Color(0xFFE8F5E9),
        ),
        _StatData(
          label:   'Transaksi',
          value:   '${dashboard.todayTransactions}',
          icon:    Icons.receipt_rounded,
          color:   const Color(0xFF2196F3),
          bgColor: const Color(0xFFE3F2FD),
        ),
        _StatData(
          label:   'Pending Sync',
          value:   '$pendingCount',
          icon:    Icons.cloud_upload_rounded,
          color:   pendingCount > 0
              ? const Color(0xFFFF9800)
              : const Color(0xFF4CAF50),
          bgColor: pendingCount > 0
              ? const Color(0xFFFFF3E0)
              : const Color(0xFFE8F5E9),
        ),
        _StatData(
          label:   'Produk Aktif',
          value:   '$activeProducts',
          icon:    Icons.inventory_2_rounded,
          color:   const Color(0xFF9C27B0),
          bgColor: const Color(0xFFF3E5F5),
        ),
      ];

      return GridView.count(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing:  14,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: isTablet ? 1.6 : 1.5,
        children: stats.map((s) => _buildStatCard(s)).toList(),
      );
    });
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:      data.color.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 0,
            offset:     const Offset(0, 6),
          ),
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Aksen warna di sisi kiri
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [data.color, data.color.withValues(alpha: 0.4)],
                  ),
                ),
              ),
            ),
            // Lingkaran dekoratif pojok kanan bawah
            Positioned(
              right: -20, bottom: -20,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.color.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 10, bottom: 10,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.color.withValues(alpha: 0.09),
                ),
              ),
            ),
            // Konten
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                children: [
                  // Icon badge
                  Container(
                    padding:    const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color:        data.bgColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:      data.color.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset:     const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(data.icon, color: data.color, size: 18),
                  ),
                  // Nilai & label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.value,
                        style: TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                          color:      const Color(0xFF1A1D26),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isTablet) {
    final actions = [
      _ActionData(
        icon:       Icons.point_of_sale_rounded,
        decorIcon:  Icons.shopping_bag_outlined,
        decorIcon2: Icons.attach_money_rounded,
        label:      'Kasir',
        subtitle:   'Mulai transaksi baru',
        color:      const Color(0xFFFF6B35),
        bgColor:    const Color(0xFFFFF0EB),
        onTap:      () => Get.toNamed('/pos'),
      ),
      _ActionData(
        icon:       Icons.inventory_2_rounded,
        decorIcon:  Icons.qr_code_rounded,
        decorIcon2: Icons.category_outlined,
        label:      'Produk',
        subtitle:   'Kelola stok barang',
        color:      const Color(0xFF2196F3),
        bgColor:    const Color(0xFFE3F2FD),
        onTap:      () => Get.toNamed('/inventory'),
      ),
      _ActionData(
        icon:       Icons.receipt_long_rounded,
        decorIcon:  Icons.bar_chart_rounded,
        decorIcon2: Icons.calendar_today_rounded,
        label:      'Riwayat',
        subtitle:   'Lihat transaksi',
        color:      const Color(0xFF4CAF50),
        bgColor:    const Color(0xFFE8F5E9),
        onTap:      () {},
      ),
      _ActionData(
        icon:       Icons.category_rounded,
        decorIcon:  Icons.label_outline_rounded,
        decorIcon2: Icons.folder_outlined,
        label:      'Kategori',
        subtitle:   'Kelola kategori produk',
        color:      const Color(0xFFFF9800),
        bgColor:    const Color(0xFFFFF3E0),
        onTap:      () => Get.toNamed('/categories'),
      ),
      _ActionData(
        icon:       Icons.local_shipping_rounded,
        decorIcon:  Icons.receipt_long_outlined,
        decorIcon2: Icons.business_rounded,
        label:      'Pembelian',
        subtitle:   'PO dari supplier',
        color:      const Color(0xFF7C3AED),
        bgColor:    const Color(0xFFEDE7F6),
        onTap:      () => Get.toNamed('/purchases'),
      ),
      _ActionData(
        icon:       Icons.business_rounded,
        decorIcon:  Icons.handshake_outlined,
        decorIcon2: Icons.contact_page_outlined,
        label:      'Supplier',
        subtitle:   'Kelola data supplier',
        color:      const Color(0xFF0097A7),
        bgColor:    const Color(0xFFE0F7FA),
        onTap:      () => Get.toNamed('/suppliers'),
      ),
      _ActionData(
        icon:       Icons.sync_rounded,
        decorIcon:  Icons.cloud_rounded,
        decorIcon2: Icons.wifi_rounded,
        label:      'Sinkron',
        subtitle:   'Upload ke server',
        color:      const Color(0xFF9C27B0),
        bgColor:    const Color(0xFFF3E5F5),
        onTap:      () => Get.toNamed('/sync-debug'),
      ),
    ];

    return GridView.count(
      crossAxisCount:   isTablet ? 3 : 2,
      crossAxisSpacing: 14,
      mainAxisSpacing:  14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: actions.map((a) => _buildActionCard(a)).toList(),
    );
  }

  Widget _buildActionCard(_ActionData data) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // Shadow utama berwarna sesuai tema card
            BoxShadow(
              color:      data.color.withValues(alpha: 0.14),
              blurRadius: 24,
              spreadRadius: 0,
              offset:     const Offset(0, 8),
            ),
            // Shadow tipis di bawah untuk kedalaman
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background gradient tipis
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        data.bgColor.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Lingkaran besar pojok kanan atas
              Positioned(
                right: -28, top: -28,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.color.withValues(alpha: 0.07),
                  ),
                ),
              ),
              // Lingkaran sedang dengan ikon semi-transparan
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.color.withValues(alpha: 0.1),
                  ),
                  child: Icon(data.decorIcon,
                      color: data.color.withValues(alpha: 0.45), size: 22),
                ),
              ),

              // Konten utama
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.end,
                  children: [
                    // Icon badge dengan shadow berwarna
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color:        data.bgColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:      data.color.withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(data.icon, color: data.color, size: 22),
                    ),
                    const Spacer(),
                    Text(
                      data.label,
                      style: const TextStyle(
                        fontSize:   45,
                        fontWeight: FontWeight.bold,
                        color:      Color(0xFF1A1D26),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: 25,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
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

  Widget _buildRecentSection() {
    return Obx(() {
      final dashboard  = Get.find<DashboardService>();
      final activities = dashboard.recentActivities;
      final currency   = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      return Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFFFF6B35).withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: 0,
              offset:     const Offset(0, 8),
            ),
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Dekorasi pojok kanan
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                right: 20, top: 20,
                child: Icon(Icons.receipt_long_outlined,
                    size: 40, color: const Color(0xFFFF6B35).withValues(alpha: 0.07)),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0EB),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.receipt_rounded,
                                  size: 15, color: Color(0xFFFF6B35)),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Transaksi Terakhir',
                              style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold,
                                color:      Color(0xFF1A1D26),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => dashboard.loadDashboardData(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: const Color(0xFFFFF0EB),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Refresh',
                              style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (activities.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 72, height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                                    ),
                                  ),
                                  Container(
                                    width: 50, height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                                    ),
                                  ),
                                  const Icon(Icons.receipt_long_outlined,
                                      size: 26, color: Color(0xFFFF6B35)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum ada transaksi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:      Color(0xFF1A1D26),
                                  fontSize:   13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mulai kasir untuk mencatat transaksi',
                                style: TextStyle(color: Colors.grey[400], fontSize: 11),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => Get.toNamed('/pos'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                                        blurRadius: 8, offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.point_of_sale_rounded,
                                          color: Colors.white, size: 15),
                                      SizedBox(width: 6),
                                      Text('Buka Kasir',
                                          style: TextStyle(color: Colors.white,
                                              fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...activities.map((activity) {
                        final color  = activity['color'] as Color;
                        final icon   = activity['icon'] as IconData;
                        final amount = activity['amount'] as String? ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color:        Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(color: Colors.grey[100]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color:        color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity['title'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize:   12,
                                        fontWeight: FontWeight.w600,
                                        color:      Color(0xFF1A1D26),
                                      ),
                                    ),
                                    Text(
                                      activity['subtitle'] as String? ?? '',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              if (amount.isNotEmpty)
                                Text(
                                  amount,
                                  style: TextStyle(
                                    fontSize:   12,
                                    fontWeight: FontWeight.w700,
                                    color:      color,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _roleBadge(String role) {
    final colors = {
      'owner':   [const Color(0xFFFF6B35), const Color(0xFFFFF0EB)],
      'manager': [const Color(0xFF2196F3), const Color(0xFFE3F2FD)],
      'cashier': [const Color(0xFF4CAF50), const Color(0xFFE8F5E9)],
    };
    final c = colors[role] ?? [Colors.grey, Colors.grey[100]!];
    final label = {'owner': 'Owner', 'manager': 'Manager', 'cashier': 'Kasir'}[role] ?? role;

    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c[1],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c[0])),
    );
  }

  void _showProfileSheet(String name, String role) {
    final authController = Get.find<AuthController>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin:  const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFFFF0EB),
              child: Text(name.isEmpty ? 'U' : name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24, color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            _roleBadge(role),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync_rounded, color: Color(0xFFFF6B35)),
              title: const Text('Status Sinkron'),
              onTap: () { Get.back(); Get.toNamed('/sync-debug'); },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: () { Get.back(); authController.handleLogout(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color, bgColor;
  const _StatData({
    required this.label, required this.value,
    required this.icon,  required this.color, required this.bgColor,
  });
}

class _ActionData {
  final IconData icon;
  final IconData decorIcon;
  final IconData decorIcon2;
  final String label, subtitle;
  final Color color, bgColor;
  final VoidCallback onTap;
  const _ActionData({
    required this.icon,
    required this.decorIcon,
    required this.decorIcon2,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

